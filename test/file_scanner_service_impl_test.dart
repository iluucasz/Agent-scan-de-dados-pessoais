import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seusdados/constants/data_patterns.dart';
import 'package:seusdados/models/scan_config.dart';
import 'package:seusdados/services/file_scanner_service_impl.dart';

void main() {
  group('FileScannerServiceImpl structured validation', () {
    test('keeps only valid CPF and CNPJ matches', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'scanner_structured_validation_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final file =
          File('${tempDirectory.path}${Platform.pathSeparator}dados.txt');
      await file.writeAsString('''
CPF valido: 529.982.247-25
CPF invalido: 529.982.247-24
CPF repetido: 111.111.111-11
CNPJ valido: 04.252.011/0001-10
CNPJ invalido: 04.252.011/0001-11
''');

      final scanner = FileScannerServiceImpl();
      final result = await scanner.scan(
        config: ScanConfig(
          id: 'test-scan',
          path: tempDirectory.path,
          selectedPatterns: [
            DataPatterns.cpf.name,
            DataPatterns.cnpj.name,
          ],
          includeSubfolders: false,
          createdAt: DateTime.now(),
        ),
        onProgress: (_, __) {},
        onStatus: (_) {},
      );

      expect(result.totalDataFound, 2);
      expect(result.foundData.map((item) => item.dataType), ['cpf', 'cnpj']);
      expect(result.foundData.every((item) => item.confidence >= 0.9), isTrue);
      expect(
        result.foundData.map((item) => item.value),
        ['529.982.247-25', '04.252.011/0001-10'],
      );
    });
  });

  group('FileScannerServiceImpl context refinement', () {
    test('ambiguous pattern with positive context is kept', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'scanner_context_positive_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final file =
          File('${tempDirectory.path}${Platform.pathSeparator}dados.txt');
      await file.writeAsString('CEP: 01310-100\n');

      final scanner = FileScannerServiceImpl();
      final result = await scanner.scan(
        config: ScanConfig(
          id: 'test-ctx',
          path: tempDirectory.path,
          selectedPatterns: [DataPatterns.cep.name],
          includeSubfolders: false,
          createdAt: DateTime.now(),
        ),
        onProgress: (_, __) {},
        onStatus: (_) {},
      );

      expect(result.totalDataFound, 1);
      expect(result.foundData.first.dataType, 'cep');
    });

    test('ambiguous pattern without context is discarded', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'scanner_context_none_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final file =
          File('${tempDirectory.path}${Platform.pathSeparator}dados.txt');
      // Sem label de contexto — apenas números no formato de CEP.
      await file.writeAsString('01310100\n');

      final scanner = FileScannerServiceImpl();
      final result = await scanner.scan(
        config: ScanConfig(
          id: 'test-ctx-no',
          path: tempDirectory.path,
          selectedPatterns: [DataPatterns.cep.name],
          includeSubfolders: false,
          createdAt: DateTime.now(),
        ),
        onProgress: (_, __) {},
        onStatus: (_) {},
      );

      expect(result.totalDataFound, 0);
    });

    test('non-ambiguous pattern works without context labels', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'scanner_context_non_ambig_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final file =
          File('${tempDirectory.path}${Platform.pathSeparator}dados.txt');
      // CPF válido sem label — still kept because CPF is structurally
      // validated and not ambiguous.
      await file.writeAsString('52998224725\n');

      final scanner = FileScannerServiceImpl();
      final result = await scanner.scan(
        config: ScanConfig(
          id: 'test-ctx-cpf',
          path: tempDirectory.path,
          selectedPatterns: [DataPatterns.cpf.name],
          includeSubfolders: false,
          createdAt: DateTime.now(),
        ),
        onProgress: (_, __) {},
        onStatus: (_) {},
      );

      expect(result.totalDataFound, 1);
      expect(result.foundData.first.dataType, 'cpf');
    });

    test('negative context discards match even for non-ambiguous', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'scanner_context_neg_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final file =
          File('${tempDirectory.path}${Platform.pathSeparator}dados.txt');
      // "protocolo" é contexto negativo para CPF.
      await file.writeAsString('Protocolo de atendimento: 529.982.247-25\n');

      final scanner = FileScannerServiceImpl();
      final result = await scanner.scan(
        config: ScanConfig(
          id: 'test-ctx-neg',
          path: tempDirectory.path,
          selectedPatterns: [DataPatterns.cpf.name],
          includeSubfolders: false,
          createdAt: DateTime.now(),
        ),
        onProgress: (_, __) {},
        onStatus: (_) {},
      );

      expect(result.totalDataFound, 0);
    });

    test('positive context boosts confidence', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'scanner_context_boost_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final file =
          File('${tempDirectory.path}${Platform.pathSeparator}dados.txt');
      await file.writeAsString('user@example.com\nEmail corporativo: admin@empresa.com.br\n');

      final scanner = FileScannerServiceImpl();
      final result = await scanner.scan(
        config: ScanConfig(
          id: 'test-ctx-boost',
          path: tempDirectory.path,
          selectedPatterns: [DataPatterns.email.name],
          includeSubfolders: false,
          createdAt: DateTime.now(),
        ),
        onProgress: (_, __) {},
        onStatus: (_) {},
      );

      expect(result.totalDataFound, 2);

      final withoutLabel =
          result.foundData.firstWhere((d) => d.value == 'user@example.com');
      final withLabel = result.foundData
          .firstWhere((d) => d.value == 'admin@empresa.com.br');

      // O match com label "Email" deve ter confiança maior.
      expect(withLabel.confidence, greaterThan(withoutLabel.confidence));
    });
  });
}
