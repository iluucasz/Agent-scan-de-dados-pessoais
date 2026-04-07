import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/scan_config.dart';
import '../models/scan_result.dart';
import '../models/personal_data.dart';
import '../constants/data_patterns.dart';
import '../validators/structured_data_validators.dart';

class _PreparedPattern {
  final DataPattern pattern;
  final RegExp regex;

  _PreparedPattern(this.pattern) : regex = RegExp(pattern.regex);
}

/// Serviço de escaneamento de arquivos
/// Varre diretórios locais procurando por padrões de dados pessoais
class FileScannerServiceImpl {
  bool _isCancelled = false;

  /// Cancela o scan em andamento
  void cancel() {
    _isCancelled = true;
  }

  /// Executa o escaneamento de arquivos
  Future<ScanResult> scan({
    required ScanConfig config,
    required Function(int current, int total) onProgress,
    required Function(String message) onStatus,
    Function(String fileName, String directory, List<PersonalData> foundData)?
        onFileProgress,
  }) async {
    _isCancelled = false;
    final startTime = DateTime.now();

    onStatus('Iniciando escaneamento...');

    // Validar configuração
    final directory = Directory(config.path);
    if (!await directory.exists()) {
      throw Exception('Diretório não encontrado: ${config.path}');
    }

    // Preparar padrões (com regex pré-compilado)
    final patterns = _preparePatterns(config.selectedPatterns);
    if (patterns.isEmpty) {
      throw Exception('Nenhum padrão selecionado');
    }

    // Coletar arquivos
    onStatus('Coletando lista de arquivos...');
    final files = await _collectFiles(
      directory: directory,
      includeSubfolders: config.includeSubfolders,
      maxFileSize: config.maxFileSize,
    );

    if (files.isEmpty) {
      return ScanResult(
        foundData: [],
        totalFilesScanned: 0,
        totalDataFound: 0,
        scanDate: DateTime.now(),
        scanDuration: DateTime.now().difference(startTime),
        scannedPath: config.path,
      );
    }

    // Escanear arquivos
    onStatus('Escaneando ${files.length} arquivos...');

    final foundData = <PersonalData>[];
    int scannedFiles = 0;

    for (var i = 0; i < files.length; i++) {
      if (_isCancelled) {
        throw Exception('Scan cancelado pelo usuário');
      }

      final file = files[i];
      final fileName = path.basename(file.path);
      final directory = path.dirname(file.path);

      // Atualizar status com arquivo atual
      onStatus('Escaneando: $fileName');

      try {
        final fileData = await _scanFile(file, patterns);
        foundData.addAll(fileData);
        scannedFiles++;

        // Sempre notificar progresso do arquivo
        if (onFileProgress != null) {
          onFileProgress(fileName, directory, fileData);
        }
      } catch (e) {
        // Ignorar erros de arquivos individuais
        if (onFileProgress != null) {
          onFileProgress(fileName, directory, []);
        }
        onStatus('⚠️ Erro ao processar: $fileName');
      }

      // Progresso deve refletir arquivos concluídos (não apenas iniciados).
      onProgress(i + 1, files.length);

      // Evita bloquear o event loop/UI em scans muito grandes.
      if (i % 5 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    onStatus('Escaneamento concluído!');

    return ScanResult(
      foundData: foundData,
      totalFilesScanned: scannedFiles,
      totalDataFound: foundData.length,
      scanDate: DateTime.now(),
      scanDuration: DateTime.now().difference(startTime),
      scannedPath: config.path,
    );
  }

  /// Prepara os padrões de regex para busca
  List<_PreparedPattern> _preparePatterns(List<String> selectedPatternNames) {
    final patterns = <_PreparedPattern>[];

    for (final patternName in selectedPatternNames) {
      final pattern = DataPatterns.allPatterns.firstWhere(
        (p) => p.name == patternName,
        orElse: () => throw Exception('Padrão não encontrado: $patternName'),
      );

      // Pré-compila o regex uma vez.
      patterns.add(_PreparedPattern(pattern));
    }

    return patterns;
  }

  /// Coleta lista de arquivos para escanear
  Future<List<File>> _collectFiles({
    required Directory directory,
    required bool includeSubfolders,
    int? maxFileSize,
  }) async {
    final files = <File>[];

    await for (final entity in directory.list(
      recursive: includeSubfolders,
      followLinks: false,
    )) {
      if (entity is File) {
        // Verificar extensão
        final ext = path.extension(entity.path).toLowerCase();

        // Verificar tamanho
        if (maxFileSize != null) {
          final stat = await entity.stat();
          if (stat.size > maxFileSize) {
            continue;
          }
        }

        // Apenas arquivos de texto por enquanto
        if (_isScannableFile(ext)) {
          files.add(entity);
        }
      }
    }

    return files;
  }

  /// Verifica se é um tipo de arquivo que conseguimos escanear.
  ///
  /// - Texto: lê direto
  /// - Office Open XML: extrai de XML dentro do zip (.docx/.xlsx)
  /// - PDF: tenta extrair texto via parser
  bool _isScannableFile(String extension) {
    const extensions = [
      // texto
      '.txt',
      '.log',
      '.csv',
      '.json',
      '.xml',
      '.html',
      '.htm',
      '.md',
      '.ini',
      '.conf',
      '.cfg',
      '.yaml',
      '.yml',

      // Office / PDF
      '.docx',
      '.xlsx',
      '.pdf',
    ];

    return extensions.contains(extension.toLowerCase());
  }

  /// Escaneia um arquivo específico
  Future<List<PersonalData>> _scanFile(
    File file,
    List<_PreparedPattern> patterns,
  ) async {
    final foundData = <PersonalData>[];

    try {
      final fileType = path.extension(file.path).toLowerCase();

      // Ler conteúdo do arquivo (best-effort para tipos não-texto)
      final content = await _readFileContent(file);
      if (content.trim().isEmpty) return foundData;

      final lines = content.split('\n');

      // Buscar padrões em cada linha
      for (var lineNum = 0; lineNum < lines.length; lineNum++) {
        final line = lines[lineNum].replaceAll('\r', '');

        for (final entry in patterns) {
          final pattern = entry.pattern;
          final matches = entry.regex.allMatches(line);

          for (final match in matches) {
            final value = match.group(0) ?? '';
            final structuredValidation = StructuredDataValidators.validate(
              pattern.structuredValidator,
              value,
            );
            if (structuredValidation != null && !structuredValidation.isValid) {
              continue;
            }

            final startPos = (match.start - 30).clamp(0, line.length);
            final endPos = (match.end + 30).clamp(0, line.length);
            final context = line.substring(startPos, endPos);
            final evidence =
                '${context.substring(0, match.start - startPos)}[$value]${context.substring(match.start - startPos + value.length)}';
            foundData.add(PersonalData(
              dataType: pattern.id,
              displayName: pattern.name,
              description: pattern.description,
              value: value,
              filePath: file.path,
              lineNumber: lineNum + 1,
              confidence: _calculateConfidence(
                pattern,
                value,
                structuredValidation: structuredValidation,
              ),
              context: context,
              position: match.start,
              category: _mapCategoryToApi(pattern.category),
              subcategory: _mapSubcategoryToApi(pattern.category),
              criticality: _mapCriticality(pattern),
              evidence: evidence,
              fileType: fileType,
              parserType: _parserTypeForExtension(fileType),
            ));
          }
        }

        // Yield ocasional para manter UI responsiva em arquivos grandes.
        if (lineNum % 500 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } catch (e) {
      // Ignorar erros de leitura (arquivos binários, sem permissão, etc)
    }

    return foundData;
  }

  String _parserTypeForExtension(String fileType) {
    switch (fileType) {
      case '.docx':
        return 'docx';
      case '.xlsx':
        return 'xlsx';
      case '.pdf':
        return 'pdf';
      default:
        return 'text';
    }
  }

  Future<String> _readFileContent(File file) async {
    final ext = path.extension(file.path).toLowerCase();

    switch (ext) {
      case '.docx':
        return _extractTextFromDocx(file);
      case '.xlsx':
        return _extractTextFromXlsx(file);
      case '.pdf':
        return _extractTextFromPdf(file);
      default:
        return _readTextFileBestEffort(file);
    }
  }

  Future<String> _readTextFileBestEffort(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  Future<String> _extractTextFromDocx(File file) async {
    final bytes = await file.readAsBytes();
    // DOCX é um ZIP com XMLs em word/*.xml
    return _extractTextFromZipXml(
      bytes: bytes,
      includePrefixes: const ['word/'],
      includeFileName: (name) => name.endsWith('.xml'),
    );
  }

  Future<String> _extractTextFromXlsx(File file) async {
    final bytes = await file.readAsBytes();
    // XLSX é um ZIP com XMLs em xl/*.xml
    return _extractTextFromZipXml(
      bytes: bytes,
      includePrefixes: const ['xl/'],
      includeFileName: (name) => name.endsWith('.xml'),
    );
  }

  Future<String> _extractTextFromPdf(File file) async {
    final bytes = await file.readAsBytes();
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text;
    } catch (_) {
      // Se falhar, não derruba o scan.
      return '';
    }
  }

  String _extractTextFromZipXml({
    required Uint8List bytes,
    required List<String> includePrefixes,
    required bool Function(String name) includeFileName,
  }) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final buffer = StringBuffer();

      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name;

        if (!includePrefixes.any((prefix) => name.startsWith(prefix))) {
          continue;
        }
        if (!includeFileName(name)) continue;

        final contentBytes = file.content;
        final xml = _decodeXmlText(contentBytes);
        if (xml.trim().isEmpty) continue;

        buffer.writeln(_officeXmlToText(xml));
      }

      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  String _decodeXmlText(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _officeXmlToText(String xml) {
    // Preserva quebras de parágrafo comuns em DOCX.
    var text = xml
        .replaceAll(RegExp(r'</w:p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<w:p[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<w:tab\s*/>', caseSensitive: false), '\t')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Remove tags e normaliza espaços.
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _decodeXmlEntities(text);
    text = text.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    return text;
  }

  String _decodeXmlEntities(String input) {
    var text = input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      if (code == null) return m.group(0) ?? '';
      return String.fromCharCode(code);
    });

    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '', radix: 16);
      if (code == null) return m.group(0) ?? '';
      return String.fromCharCode(code);
    });

    return text;
  }

  String _mapCategoryToApi(PatternCategory category) {
    // O backend/plataforma do projeto base usa categorias como 'personal_data' e 'sensitive_data'.
    switch (category) {
      case PatternCategory.sensitive:
        return 'sensitive_data';
      case PatternCategory.health:
      case PatternCategory.biometric:
        return 'health_data';
      default:
        return 'personal_data';
    }
  }

  String _mapSubcategoryToApi(PatternCategory category) {
    // No base aparecem subcategorias como 'identification', 'location', etc.
    switch (category) {
      case PatternCategory.location:
        return 'location';
      case PatternCategory.financial:
        return 'financial';
      case PatternCategory.health:
        return 'health';
      case PatternCategory.biometric:
        return 'biometric';
      case PatternCategory.contact:
        return 'contact';
      case PatternCategory.id:
      case PatternCategory.personal:
      case PatternCategory.sensitive:
        return 'identification';
    }
  }

  String _mapCriticality(DataPattern pattern) {
    // Aproximação compatível com o catálogo do projeto base.
    // Quando não houver regra explícita, cai em 'medium'.
    const highIds = {
      'cpf',
      'rg',
      'cnpj',
      'cnh',
      'passaporte',
      'pis_pasep',
      'senha_texto',
      'token_acesso',
      'chave_api',
      'cartao_credito',
      'pix',
    };

    const lowIds = {
      'sexo',
      'naturalidade',
      'nacionalidade',
      'estado_civil',
      'parentesco',
    };

    if (highIds.contains(pattern.id)) return 'high';
    if (lowIds.contains(pattern.id)) return 'low';

    // Por categoria, um fallback razoável.
    if (pattern.category == PatternCategory.sensitive) return 'high';
    if (pattern.category == PatternCategory.financial) return 'high';
    if (pattern.category == PatternCategory.contact) return 'medium';
    if (pattern.category == PatternCategory.personal) return 'medium';
    if (pattern.category == PatternCategory.id) return 'medium';

    return 'medium';
  }

  /// Calcula confiança da detecção
  double _calculateConfidence(
    DataPattern pattern,
    String value, {
    StructuredValidationResult? structuredValidation,
  }) {
    if (structuredValidation?.confidenceOverride != null) {
      return structuredValidation!.confidenceOverride!;
    }

    // Confiança base
    double confidence = 0.7;

    // Ajustar baseado no padrão
    if (pattern.category == PatternCategory.id) {
      confidence = 0.85; // IDs tendem a ser mais confiáveis
    } else if (pattern.category == PatternCategory.contact) {
      confidence = 0.75;
    }

    // Ajustar baseado no tamanho do valor
    if (value.length > 20) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }
}
