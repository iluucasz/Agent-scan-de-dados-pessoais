import 'dart:io';
import '../models/personal_data.dart';
import '../models/scan_result.dart';
import '../constants/data_patterns.dart';

class FileScannerService {
  final List<PersonalData> _foundData = [];
  int _filesScanned = 0;
  bool _isScanning = false;
  bool _shouldStop = false;

  bool get isScanning => _isScanning;
  int get filesScanned => _filesScanned;
  List<PersonalData> get foundData => _foundData;

  Future<ScanResult> scanDirectory(
    String directoryPath, {
    required List<String> selectedPatterns,
    bool includeSubfolders = true,
    int? maxFileSize,
    Function(String)? onFileScanned,
    Function(int)? onProgress,
  }) async {
    _foundData.clear();
    _filesScanned = 0;
    _isScanning = true;
    _shouldStop = false;

    final startTime = DateTime.now();
    final directory = Directory(directoryPath);

    // Obter padrões regex selecionados
    final patterns = _getSelectedPatterns(selectedPatterns);

    try {
      await _scanDirectoryRecursive(
        directory,
        patterns,
        includeSubfolders,
        maxFileSize,
        onFileScanned,
        onProgress,
      );
    } catch (e) {
      stderr.writeln('Erro ao escanear diretório: $e');
    }

    _isScanning = false;
    final endTime = DateTime.now();

    return ScanResult(
      foundData: _foundData,
      totalFilesScanned: _filesScanned,
      totalDataFound: _foundData.length,
      scanDate: startTime,
      scanDuration: endTime.difference(startTime),
      scannedPath: directoryPath,
    );
  }

  Map<String, RegExp> _getSelectedPatterns(List<String> selectedNames) {
    final patterns = <String, RegExp>{};

    for (final pattern in DataPatterns.allPatterns) {
      if (selectedNames.contains(pattern.name)) {
        try {
          patterns[pattern.name] = RegExp(pattern.regex);
        } catch (e) {
          stderr.writeln('Erro ao compilar regex para ${pattern.name}: $e');
        }
      }
    }

    return patterns;
  }

  Future<void> _scanDirectoryRecursive(
    Directory directory,
    Map<String, RegExp> patterns,
    bool includeSubfolders,
    int? maxFileSize,
    Function(String)? onFileScanned,
    Function(int)? onProgress,
  ) async {
    if (_shouldStop) return;

    try {
      final entities = directory.listSync();

      for (var entity in entities) {
        if (_shouldStop) break;

        if (entity is File) {
          await _scanFile(
            entity,
            patterns,
            maxFileSize,
            onFileScanned,
          );
          _filesScanned++;
          onProgress?.call(_filesScanned);
        } else if (entity is Directory && includeSubfolders) {
          if (!_shouldSkipDirectory(entity.path)) {
            await _scanDirectoryRecursive(
              entity,
              patterns,
              includeSubfolders,
              maxFileSize,
              onFileScanned,
              onProgress,
            );
          }
        }
      }
    } catch (e) {
      // Ignorar erros de permissão
    }
  }

  bool _shouldSkipDirectory(String path) {
    final skipPatterns = [
      'node_modules',
      '.git',
      '.dart_tool',
      'build',
      'AppData',
      'Windows',
      'Program Files',
      'ProgramData',
      '\$Recycle.Bin',
      'System Volume Information',
    ];

    return skipPatterns.any((pattern) => path.contains(pattern));
  }

  Future<void> _scanFile(
    File file,
    Map<String, RegExp> patterns,
    int? maxFileSize,
    Function(String)? onFileScanned,
  ) async {
    if (_shouldStop) return;

    onFileScanned?.call(file.path);

    // Verificar extensão
    final extension = file.path.split('.').last.toLowerCase();

    // Apenas arquivos de texto/dados
    final textExtensions = [
      'txt',
      'csv',
      'json',
      'xml',
      'log',
      'md',
      'html',
      'js',
      'ts',
      'dart',
      'py',
      'java',
      'cpp',
      'c',
      'h'
    ];
    if (!textExtensions.contains(extension)) return;

    try {
      // Verificar tamanho do arquivo
      final stat = await file.stat();
      if (maxFileSize != null && stat.size > maxFileSize * 1024 * 1024) {
        return; // Arquivo muito grande
      }

      // Ler conteúdo
      final content = await file.readAsString();

      // Procurar padrões
      final foundPatterns = _findPatternsInContent(content, patterns);

      if (foundPatterns.isNotEmpty) {
        _foundData.add(PersonalData(
          dataType: foundPatterns.first,
          value:
              'Encontrado em ${file.path.split(Platform.pathSeparator).last}',
          filePath: file.path,
          lineNumber: 0,
          confidence: 0.8,
        ));
      }
    } catch (e) {
      // Ignorar arquivos que não podem ser lidos como texto
    }
  }

  List<String> _findPatternsInContent(
      String content, Map<String, RegExp> patterns) {
    final found = <String>[];

    for (final entry in patterns.entries) {
      if (entry.value.hasMatch(content)) {
        found.add(entry.key);
      }
    }

    return found;
  }

  void stopScan() {
    _shouldStop = true;
    _isScanning = false;
  }
}
