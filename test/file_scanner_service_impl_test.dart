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
}
