import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/scan_config.dart';
import '../models/scan_result.dart';
import '../models/user.dart';
import '../constants/data_patterns.dart';
import '../services/file_scanner_service_impl.dart';
import '../services/database_service.dart';
import '../services/scan_flow_service.dart';

enum ScanStatus { idle, configuring, running, completed, failed }

enum ScanPhaseStatus {
  idle,
  creatingConfig,
  uploadingFiles,
  scanningLocally,
  sendingResults,
  completedWithApi,
  completedLocalOnly,
  failed,
}

class ScanProvider with ChangeNotifier {
  ScanConfig? _currentConfig;
  ScanResult? _lastResult;
  ScanStatus _status = ScanStatus.idle;
  String? _errorMessage;
  int _filesScanned = 0;
  int _totalFiles = 0;
  String _statusMessage = '';
  List<String> _availablePatterns = [];
  final List<ScanResult> _scanHistory = [];
  FileScannerServiceImpl? _scanner;
  ScanPhaseStatus _currentPhase = ScanPhaseStatus.idle;
  String _phaseMessage = '';
  bool _apiIntegrationEnabled = false;

  // Informações detalhadas do scan
  String _currentFileName = '';
  String _currentDirectory = '';
  List<String> _recentFindings = [];
  int _totalDataFound = 0;

  // Sistema de logs em tempo real
  final List<String> _logMessages = [];

  // Tempo de execução (para exibir na UI e manter consistente com o log)
  DateTime? _scanStartTime;
  int? _executionTimeMs;

  // Throttle geral de UI para evitar travamentos com muitos eventos.
  Timer? _throttledNotifyTimer;
  static const Duration _throttledNotifyInterval = Duration(milliseconds: 100);

  ScanConfig? get currentConfig => _currentConfig;
  ScanResult? get lastResult => _lastResult;
  ScanStatus get status => _status;
  String? get errorMessage => _errorMessage;
  int get filesScanned => _filesScanned;
  int get totalFiles => _totalFiles;
  String get statusMessage => _statusMessage;
  List<String> get availablePatterns => _availablePatterns;
  List<ScanResult> get scanHistory => List.unmodifiable(_scanHistory);
  bool get isScanning => _status == ScanStatus.running;
  ScanPhaseStatus get currentPhase => _currentPhase;
  String get phaseMessage => _phaseMessage;
  bool get apiIntegrationEnabled => _apiIntegrationEnabled;
  String get currentFileName => _currentFileName;
  String get currentDirectory => _currentDirectory;
  List<String> get recentFindings => List.unmodifiable(_recentFindings);
  int get totalDataFound => _totalDataFound;
  List<String> get logMessages => List.unmodifiable(_logMessages);
  int get executionTimeMs {
    if (_executionTimeMs != null) return _executionTimeMs!;
    if (_scanStartTime == null) return 0;
    return DateTime.now().difference(_scanStartTime!).inMilliseconds;
  }

  // Inicializar provider com padrões disponíveis
  void initialize() {
    _availablePatterns = DataPatterns.allPatterns
        .where((p) => p.enabled)
        .map((p) => p.name)
        .toList();
    _loadHistoryFromDatabase();
    notifyListeners();
  }

  void _setPhaseMessage(String message) {
    if (_phaseMessage == message) return;
    _phaseMessage = message;
    _throttledNotifyListeners();
  }

  @override
  void dispose() {
    _throttledNotifyTimer?.cancel();
    super.dispose();
  }

  void _throttledNotifyListeners() {
    if (_throttledNotifyTimer?.isActive ?? false) return;
    _throttledNotifyTimer = Timer(_throttledNotifyInterval, () {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  // Carregar histórico do banco de dados
  Future<void> _loadHistoryFromDatabase() async {
    try {
      final results = await DatabaseService.instance.getAllScanResults();
      _scanHistory.clear();
      _scanHistory.addAll(results);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
    }
  }

  // Criar nova configuração de scan
  void createConfig({
    String scanName = '',
    required String path,
    required List<String> selectedPatterns,
    bool includeSubfolders = true,
    int? maxFileSize,
  }) {
    _currentConfig = ScanConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scanName: scanName,
      path: path,
      selectedPatterns: selectedPatterns,
      includeSubfolders: includeSubfolders,
      maxFileSize: maxFileSize,
      createdAt: DateTime.now(),
      status: 'pending',
    );
    _status = ScanStatus.configuring;
    notifyListeners();
  }

  // Habilitar/desabilitar integração com API
  void setApiIntegration(bool enabled) {
    _apiIntegrationEnabled = enabled;
    notifyListeners();
  }

  // Iniciar scan apenas local (sem API)
  Future<void> startScan() async {
    if (_currentConfig == null) {
      _errorMessage = 'Nenhuma configuração de scan definida';
      _status = ScanStatus.failed;
      notifyListeners();
      return;
    }

    _status = ScanStatus.running;
    _currentPhase = ScanPhaseStatus.scanningLocally;
    _scanStartTime = DateTime.now();
    _executionTimeMs = null;
    _errorMessage = null;
    _filesScanned = 0;
    _totalFiles = 0;
    _statusMessage = '';
    _currentFileName = '';
    _currentDirectory = '';
    _recentFindings.clear();
    _totalDataFound = 0;
    _phaseMessage = '';
    _clearLogs();
    _addLogMessage('🔍 Iniciando scan local...');
    _addLogMessage('📁 Caminho: ${_currentConfig!.path}');
    notifyListeners();

    try {
      _scanner = FileScannerServiceImpl();

      final result = await _scanner!.scan(
        config: _currentConfig!,
        onProgress: (current, total) {
          _filesScanned = current;
          _totalFiles = total;

          // Quando chegar em 100%, ainda pode ter etapa de finalização.
          if (_status == ScanStatus.running && total > 0 && current >= total) {
            _currentPhase = ScanPhaseStatus.sendingResults;
            _setPhaseMessage(
              'Finalizando e preparando resultados (pode levar um tempo)...',
            );
          }
          _throttledNotifyListeners();
        },
        onStatus: (message) {
          _statusMessage = message;
          _updateCurrentFileInfo(message);
          if (message.contains('Escaneando:')) {
            _addLogMessage('📄 $message');
          } else {
            _addLogMessage(message);
          }

          if (_status == ScanStatus.running &&
              message.toLowerCase().contains('conclu')) {
            _currentPhase = ScanPhaseStatus.sendingResults;
            _setPhaseMessage(
              'Processando e organizando os resultados (pode levar um tempo)...',
            );
          }
          _throttledNotifyListeners();
        },
        onFileProgress: (fileName, directory, foundData) {
          _currentFileName = fileName;
          _currentDirectory = directory;
          if (foundData.isNotEmpty) {
            _addRecentFindings(foundData);
          }
          // Atualiza sem travar a UI com muitos arquivos.
          _throttledNotifyListeners();
        },
      );

      _currentPhase = ScanPhaseStatus.sendingResults;
      _setPhaseMessage('Salvando e organizando resultados...');

      _lastResult = result;
      _scanHistory.add(result);

      _executionTimeMs =
          DateTime.now().difference(_scanStartTime!).inMilliseconds;

      _addLogMessage(
          '✅ Scan local concluído: ${result.totalFilesScanned} arquivos, ${result.totalDataFound} itens encontrados');

      // Salvar no banco de dados
      try {
        await DatabaseService.instance.saveScanResult(result);
        _addLogMessage('💾 Resultado salvo no banco local');
      } catch (dbError) {
        debugPrint('Erro ao salvar no banco: $dbError');
        _addLogMessage('⚠️ Erro ao salvar no banco local');
      }

      _status = ScanStatus.completed;
      _currentPhase = ScanPhaseStatus.completedLocalOnly;
      _phaseMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erro durante o scan: ${e.toString()}';
      _status = ScanStatus.failed;
      _currentPhase = ScanPhaseStatus.failed;
      _phaseMessage = '';
      _executionTimeMs = _scanStartTime == null
          ? null
          : DateTime.now().difference(_scanStartTime!).inMilliseconds;
      notifyListeners();
    }
  }

  // Iniciar scan com integração completa da API (3 fases)
  Future<void> startScanWithApiIntegration({
    required User currentUser,
    required ScanFlowService scanFlowService,
  }) async {
    if (_currentConfig == null) {
      _errorMessage = 'Nenhuma configuração de scan definida';
      _status = ScanStatus.failed;
      notifyListeners();
      return;
    }

    _status = ScanStatus.running;
    _currentPhase = ScanPhaseStatus.scanningLocally;
    _scanStartTime = DateTime.now();
    _executionTimeMs = null;
    _errorMessage = null;
    _filesScanned = 0;
    _totalFiles = 0;
    _statusMessage = '';
    _phaseMessage = '';
    _currentFileName = '';
    _currentDirectory = '';
    _recentFindings.clear();
    _totalDataFound = 0;
    notifyListeners();

    _clearLogs();
    _addLogMessage('🔍 Iniciando scan com integração API...');
    _addLogMessage('👤 Usuário: ${currentUser.name} (${currentUser.email})');
    _addLogMessage('📁 Caminho: ${_currentConfig!.path}');

    try {
      // PASSO 1: Executar scan local primeiro
      _addLogMessage('📂 PASSO 1: Executando scan local...');
      _scanner = FileScannerServiceImpl();
      final startTime = DateTime.now();

      final result = await _scanner!.scan(
        config: _currentConfig!,
        onProgress: (current, total) {
          _filesScanned = current;
          _totalFiles = total;

          if (_status == ScanStatus.running && total > 0 && current >= total) {
            _currentPhase = ScanPhaseStatus.sendingResults;
            _setPhaseMessage(
              'Finalizando análise local e preparando envio (pode levar um tempo)...',
            );
          }
          _throttledNotifyListeners();
        },
        onStatus: (message) {
          _statusMessage = message;
          _updateCurrentFileInfo(message);
          if (message.contains('Escaneando:')) {
            _addLogMessage('📄 $message');
          } else if (message.isNotEmpty) {
            _addLogMessage(message);
          }
          _throttledNotifyListeners();
        },
        onFileProgress: (fileName, directory, foundData) {
          _currentFileName = fileName;
          _currentDirectory = directory;
          if (foundData.isNotEmpty) {
            _addRecentFindings(foundData);
            _addLogMessage(
                '✅ $fileName - ${foundData.length} itens encontrados');
          } else {
            _addLogMessage('📄 $fileName - limpo');
          }
          // Evita rebuild em excesso com muitos arquivos.
          _throttledNotifyListeners();
        },
      );

      final executionTime = DateTime.now().difference(startTime).inMilliseconds;
      _executionTimeMs = executionTime;
      _addLogMessage(
          '✅ Scan local concluído: ${result.totalFilesScanned} arquivos, ${result.totalDataFound} itens encontrados');
      _addLogMessage('⏱️  Tempo de execução: ${executionTime}ms');

      _lastResult = result;
      _scanHistory.add(result);

      // Salvar no banco de dados local
      try {
        await DatabaseService.instance.saveScanResult(result);
        _addLogMessage('💾 Resultado salvo no banco local');
      } catch (dbError) {
        debugPrint('Erro ao salvar no banco: $dbError');
        _addLogMessage('⚠️ Erro ao salvar no banco local');
      }

      // PASSO 2: Enviar para API (3 fases)
      _addLogMessage('🌐 PASSO 2: Enviando dados para API...');

      // Coletar arquivos únicos que tiveram achados para upload ao backend
      final uniqueFilePaths = result.foundData.map((d) => d.filePath).toSet();
      final filesToUpload = uniqueFilePaths
          .map((p) => File(p))
          .where((f) => f.existsSync())
          .toList();
      _addLogMessage(
          '📤 ${filesToUpload.length} arquivo(s) com achados para upload');

      await scanFlowService.executeFullScanFlow(
        localConfig: _currentConfig!,
        currentUser: currentUser,
        localResults: [result],
        totalFiles: result.totalFilesScanned,
        processedFiles: result.totalFilesScanned,
        executionTimeMs: executionTime,
        filesToUpload: filesToUpload,
        onPhaseChange: (phase, message) {
          _phaseMessage = message;

          switch (phase) {
            case ScanPhase.creatingConfig:
              _currentPhase = ScanPhaseStatus.creatingConfig;
              break;
            case ScanPhase.uploadingFiles:
              _currentPhase = ScanPhaseStatus.uploadingFiles;
              break;
            case ScanPhase.scanningLocally:
              _currentPhase = ScanPhaseStatus.scanningLocally;
              break;
            case ScanPhase.sendingResults:
              _currentPhase = ScanPhaseStatus.sendingResults;
              break;
            case ScanPhase.completed:
              _currentPhase = ScanPhaseStatus.completedWithApi;
              break;
            case ScanPhase.failed:
              _currentPhase = ScanPhaseStatus.failed;
              break;
          }

          notifyListeners();
        },
        onProgress: (current, total) {
          // Progress do upload de arquivos
          debugPrint('Progresso API: $current/$total');
          _throttledNotifyListeners();
        },
      );

      _addLogMessage('🎉 Fluxo completo concluído com sucesso!');
      _status = ScanStatus.completed;
      _currentPhase = ScanPhaseStatus.completedWithApi;
      _phaseMessage = 'Scan concluído com integração da API!';

      // Salvar dados atualizados no banco local
      if (_lastResult != null) {
        try {
          await DatabaseService.instance.saveScanResult(_lastResult!);
          _addLogMessage('💾 Resultado final salvo no banco local');
        } catch (dbError) {
          debugPrint('Aviso: Erro ao salvar resultado final: $dbError');
          _addLogMessage('⚠️ Aviso: Erro ao salvar resultado final');
        }
      }
    } catch (e, stackTrace) {
      _addLogMessage('❌ Erro durante integração com API: $e');
      debugPrint('Stack trace: $stackTrace');
      _setError('Erro durante integração: $e');
      _currentPhase = ScanPhaseStatus.failed;
      _status = ScanStatus.failed;

      _executionTimeMs = _scanStartTime == null
          ? null
          : DateTime.now().difference(_scanStartTime!).inMilliseconds;

      // Em caso de erro na API, manter resultado local
      if (_lastResult != null) {
        _currentPhase = ScanPhaseStatus.completedLocalOnly;
        _phaseMessage =
            'Scan local concluído. Erro na integração com API: ${e.toString()}';
        debugPrint('⚠️ Mantendo resultado local devido ao erro na API');
      }
    } finally {
      _scanner = null;
      _apiIntegrationEnabled = false;
      notifyListeners();
    }
  }

  // Atualizar informações do arquivo atual
  void _updateCurrentFileInfo(String message) {
    // Extrair nome do arquivo da mensagem de status
    if (message.contains('Escaneando:')) {
      final parts = message.split('Escaneando: ');
      if (parts.length > 1) {
        var filePath = parts[1].trim();

        // Remove sufixos do tipo " - processado" / " - X achados" caso existam.
        if (filePath.contains(' - ')) {
          filePath = filePath.split(' - ').first;
        }

        _currentFileName = filePath.split('\\').last.split('/').last;
        final lastIndex = filePath.lastIndexOf(_currentFileName);
        _currentDirectory =
            lastIndex > 0 ? filePath.substring(0, lastIndex) : '';
      }
    }
  }

  // Adicionar achados recentes
  void _addRecentFindings(List<dynamic> foundData) {
    for (final data in foundData) {
      final finding = '${data.dataType}: ${data.value}';
      _recentFindings.insert(0, finding);
      _totalDataFound++;
    }
    // Manter apenas os últimos 10 achados
    if (_recentFindings.length > 10) {
      _recentFindings = _recentFindings.take(10).toList();
    }
  }

  // Adicionar mensagem ao log
  void _addLogMessage(String message) {
    final timestamp = DateTime.now();
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    _logMessages.add('[$timeStr] $message');

    // Manter apenas os últimos 50 logs
    if (_logMessages.length > 50) {
      _logMessages.removeAt(0);
    }
    _throttledNotifyListeners();
  }

  // Limpar logs
  void _clearLogs() {
    _logMessages.clear();
  }

  // Método auxiliar para definir erro
  void _setError(String message) {
    _errorMessage = message;
    _status = ScanStatus.failed;
    notifyListeners();
  }

  // Cancelar scan em andamento
  void cancelScan() {
    if (_status == ScanStatus.running && _scanner != null) {
      _scanner!.cancel();
      _status = ScanStatus.idle;
      _errorMessage = 'Scan cancelado pelo usuário';
      notifyListeners();
    }
  }

  // Limpar resultados
  void clearResults() {
    _lastResult = null;
    _currentConfig = null;
    _status = ScanStatus.idle;
    _filesScanned = 0;
    _totalFiles = 0;
    _statusMessage = '';
    _errorMessage = null;
    notifyListeners();
  }

  // Limpar erro
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Definir resultado atual (para visualizar do histórico)
  void setCurrentResult(ScanResult result) {
    _lastResult = result;
    notifyListeners();
  }

  // Limpar histórico
  Future<void> clearHistory() async {
    try {
      await DatabaseService.instance.clearAllHistory();
      _scanHistory.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao limpar histórico: $e');
    }
  }

  // Remover item específico do histórico
  Future<void> removeFromHistory(ScanResult result) async {
    try {
      // Encontrar ID do resultado no histórico
      final index = _scanHistory.indexOf(result);
      if (index >= 0) {
        // Remover do banco (assumindo que índice = id - 1)
        await DatabaseService.instance.deleteScanResult(index + 1);

        _scanHistory.remove(result);
        if (_lastResult == result) {
          _lastResult = _scanHistory.isNotEmpty ? _scanHistory.last : null;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao remover do histórico: $e');
    }
  }

  // Obter estatísticas
  Future<Map<String, int>> getStatistics() async {
    try {
      return await DatabaseService.instance.getStatistics();
    } catch (e) {
      debugPrint('Erro ao obter estatísticas: $e');
      return {'totalScans': 0, 'totalDataFound': 0, 'totalFilesScanned': 0};
    }
  }

  // (_optimizedNotifyListeners removido) – substituído por throttle global.
}
