import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import '../models/scan_config_api.dart';
import '../models/scan_config.dart';
import '../models/scan_result.dart';
import '../models/user.dart';
import '../models/external_scan_results.dart';
import '../models/scan_job.dart';
import '../models/scan_run_response.dart';
import '../constants/data_patterns.dart';

enum ScanPhase {
  creatingConfig,
  uploadingFiles,
  scanningLocally,
  sendingResults,
  completed,
  failed,
}

typedef PhaseCallback = void Function(ScanPhase phase, String message);
typedef ProgressCallback = void Function(int current, int total);

class ScanFlowService {
  final ApiService _apiService;
  final Uuid _uuid = const Uuid();

  ScanFlowService(this._apiService);

  /// Executa o fluxo completo de scan em 3 fases
  ///
  /// FASE 1: Cria configuração na API
  /// FASE 2: Executa scan local + upload de arquivos (opcional)
  /// FASE 3: Envia resultados processados para API
  Future<String> executeFullScanFlow({
    required ScanConfig localConfig,
    required User currentUser,
    required List<ScanResult> localResults,
    required int totalFiles,
    required int processedFiles,
    required int executionTimeMs,
    PhaseCallback? onPhaseChange,
    ProgressCallback? onProgress,
    List<File>? filesToUpload,
  }) async {
    final scanId = _uuid.v4();
    stdout.writeln('🚀 Iniciando fluxo de scan com API - scanId: $scanId');

    final rawScanName = localConfig.scanName.isNotEmpty
        ? localConfig.scanName
        : 'Scan ${DateTime.now()}';
    final decoratedScanName = _decorateScanName(rawScanName);

    try {
      // FASE 1: Criar configuração de scan na API
      stdout.writeln('📋 FASE 1: Criando configuração na API...');
      onPhaseChange?.call(
        ScanPhase.creatingConfig,
        'Criando configuração de scan na API...',
      );

      final apiConfig = _buildScanConfigApi(localConfig, decoratedScanName);
      stdout.writeln('📤 Enviando configuração: ${apiConfig.name}');
      final configResponse = await _apiService.createScanConfig(apiConfig);
      stdout.writeln('✅ Configuração criada com ID: ${configResponse.id}');

      // FASE 2A: Upload de arquivos com metadados estruturados (se houver)
      ScanRunResponse? runResponse;
      if (filesToUpload != null && filesToUpload.isNotEmpty) {
        onPhaseChange?.call(
          ScanPhase.uploadingFiles,
          'Enviando ${filesToUpload.length} arquivo(s) para DigitalOcean...',
        );

        // Criar metadados estruturados baseado nos resultados locais
        runResponse = await _apiService.runScan(
          configId: configResponse.id,
          scanName: decoratedScanName,
          files: filesToUpload,
        );

        onPhaseChange?.call(
          ScanPhase.uploadingFiles,
          'Upload concluído: ${runResponse.stats.uploadedSuccessfully}/${runResponse.stats.totalFiles} arquivos',
        );
      }

      // FASE 2B: Scan local já foi executado antes (recebemos os resultados)
      onPhaseChange?.call(
        ScanPhase.scanningLocally,
        'Scan local concluído: $processedFiles arquivos processados',
      );

      // FASE 3: Monitorar processamento no servidor (se houve upload)
      if (runResponse != null) {
        final jobId = runResponse.jobId;
        {
          onPhaseChange?.call(
            ScanPhase.sendingResults,
            '⏳ Aguardando processamento da análise avançada...',
          );

          // Aguardar processamento por até 2 minutos
          final jobResult = await _waitForJobCompletion(jobId);
          if (jobResult != null) {
            onPhaseChange?.call(
              ScanPhase.sendingResults,
              '✅ Análise avançada concluída: ${jobResult.foundItems.length} achados',
            );
          } else {
            onPhaseChange?.call(
              ScanPhase.sendingResults,
              '⚠️ Timeout na análise avançada - mantendo resultados locais',
            );
          }
        }
      }

      // FASE 4: Enviar resultados processados localmente (como backup/complemento)
      stdout
          .writeln('📊 FASE 4: Enviando resultados processados localmente...');
      onPhaseChange?.call(
        ScanPhase.sendingResults,
        'Enviando resultados locais para a API...',
      );

      onPhaseChange?.call(
        ScanPhase.sendingResults,
        'Empacotando e serializando resultados (pode levar um tempo)...',
      );

      final payload = await _buildExternalResultsPayload(
        scanId: scanId,
        scanName: decoratedScanName,
        config: localConfig,
        user: currentUser,
        scanResults: localResults,
        totalFiles: totalFiles,
        processedFiles: processedFiles,
        executionTimeMs: executionTimeMs,
      );

      final resultsResponse =
          await _apiService.sendExternalScanResults(payload);
      stdout.writeln('✅ Resultados enviados: ${resultsResponse.message}');

      if (resultsResponse.jobId != null) {
        stdout.writeln(
            '📊 Job ID retornado pelo backend: ${resultsResponse.jobId}');
      }
      if (resultsResponse.scanId != null) {
        stdout.writeln(
            '📊 Scan ID retornado pelo backend: ${resultsResponse.scanId}');
      }

      if (resultsResponse.success) {
        stdout.writeln('🎉 Scan concluído com sucesso! ScanId: $scanId');
        onPhaseChange?.call(
          ScanPhase.completed,
          'Scan concluído e enviado com sucesso!',
        );
      }

      return resultsResponse.scanId ?? scanId;
    } catch (e) {
      stderr.writeln('❌ ERRO no fluxo de scan: $e');
      onPhaseChange?.call(
        ScanPhase.failed,
        'Erro durante o scan: $e',
      );
      rethrow;
    }
  }

  /// Constrói configuração de scan para API a partir da config local
  ScanConfigApi _buildScanConfigApi(ScanConfig localConfig, String decoratedName) {
    return ScanConfigApi(
      name: decoratedName,
      description: 'Scan executado via app Flutter - ${localConfig.path}',
      sourceType: 'directory',
      connectionConfig: ConnectionConfig(
        baseDirectory: localConfig.path,
        recursive: localConfig.includeSubfolders,
      ),
      scanPattern: ScanPattern(
        contentPatterns: localConfig.selectedPatterns,
        fileTypes: ['*.*'],
        maxDepth: 5,
        maxFileSize: localConfig.maxFileSize ?? 52428800, // 50MB
      ),
    );
  }

  /// Constrói payload de resultados externos para enviar à API  // Método para aguardar conclusão do job no servidor
  Future<ScanJob?> _waitForJobCompletion(int jobId) async {
    const maxAttempts = 24; // 2 minutos (5s * 24)
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        await Future.delayed(const Duration(seconds: 5));
        final job = await _apiService.getScanJob(jobId);

        if (job.status == 'completed') {
          stdout.writeln(
              '✅ Job $jobId concluído com ${job.foundItems.length} achados');
          return job;
        } else if (job.status == 'failed') {
          stderr.writeln('❌ Job $jobId falhou: ${job.error}');
          return job;
        }

        attempts++;
        stdout.writeln(
            '⏳ Aguardando job $jobId... tentativa $attempts/$maxAttempts');
      } catch (e) {
        stderr.writeln('❌ Erro ao verificar job $jobId: $e');
        attempts++;
      }
    }

    stderr.writeln('⚠️ Timeout ao aguardar job $jobId');
    return null;
  }

  Future<ExternalScanResultsPayload> _buildExternalResultsPayload({
    required String scanId,
    required String scanName,
    required ScanConfig config,
    required User user,
    required List<ScanResult> scanResults,
    required int totalFiles,
    required int processedFiles,
    required int executionTimeMs,
  }) async {
    final decoratedScanName = _decorateScanName(scanName);

    // Converte ScanResult (com lista de PersonalData) para ScanResultItem individual
    final List<ScanResultItem> resultItems = [];

    for (final scanResult in scanResults) {
      for (final personalData in scanResult.foundData) {
        final normalizedType = _normalizePatternId(personalData.dataType);
        final pattern = _tryFindPattern(normalizedType, personalData.dataType);

        resultItems.add(
          ScanResultItem(
            id: _uuid.v4(),
            file: personalData.filePath,
            fileName: _stripExtension(personalData.fileName),
            line: personalData.lineNumber,
            column: personalData.position ?? 0,
            position: personalData.position,
            type: normalizedType,
            displayName: personalData.displayName ?? pattern?.name,
            description: personalData.description ?? pattern?.description,
            category: personalData.category ??
                (pattern != null ? _mapCategoryToApi(pattern.category) : null),
            subcategory: personalData.subcategory ??
                (pattern != null
                    ? _mapSubcategoryToApi(pattern.category)
                    : null),
            criticality: personalData.criticality ??
                (pattern != null ? _mapCriticality(pattern) : null),
            value: personalData.value,
            context: personalData.context ?? '',
            evidence: personalData.evidence,
            fileType: personalData.fileType,
            parserType: personalData.parserType,
            confidence: personalData.confidence,
            timestamp: scanResult.scanDate,
            userInfo: {
              'name': user.name,
              'email': user.email,
              'department': user.department ?? 'Não informado',
            },
          ),
        );

        // Em volumes grandes, evita travar a UI durante a montagem do payload.
        if (resultItems.length % 1000 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    }

    return ExternalScanResultsPayload(
      scanId: scanId,
      scanName: decoratedScanName,
      timestamp: DateTime.now(),
      config: ScanConfigInfo(
        directory: config.path,
        maxDepth: 5,
        // Mantém em bytes para ficar alinhado com o projeto base (e com a fase de upload).
        maxFileSize: config.maxFileSize ?? 52428800,
        fileTypes: '*.*',
        selectedPatterns: config.selectedPatterns,
      ),
      user: ScanUserInfo(
        name: user.name,
        email: user.email,
        department: user.department,
        organizationId: user.organizationId,
      ),
      // Compatibilidade com o payload do core/base.
      directory: config.path,
      userInfo: {
        'name': user.name,
        'email': user.email,
        'department': user.department ?? 'Não informado',
        'organizationId': user.organizationId,
      },
      systemInfo: SystemInfo(
        os: Platform.operatingSystem,
        hostname: Platform.localHostname,
        version: '1.0.0', // TODO: Obter versão do app
      ),
      stats: ScanStatsInfo(
        totalFiles: totalFiles,
        processedFiles: processedFiles,
        totalFindings: resultItems.length,
        uniqueDataTypes: resultItems.map((r) => r.type).toSet().length,
        executionTime: executionTimeMs,
        errors: 0,
      ),
      results: resultItems,
    );
  }

  String _stripExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  String _normalizePatternId(String raw) {
    // Se já vier no formato do catálogo (ex: 'cpf', 'titulo_eleitor'), mantém.
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final looksLikeId = RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed);
    if (looksLikeId) return trimmed;

    // Tenta converter nomes (ex: 'CPF', 'Data de Nascimento') para o id do catálogo.
    final byName = DataPatterns.allPatterns
        .where((p) => p.name.toLowerCase() == trimmed.toLowerCase())
        .toList();
    if (byName.isNotEmpty) return byName.first.id;

    // Fallback: slug simples.
    return trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  DataPattern? _tryFindPattern(String typeId, String original) {
    try {
      return DataPatterns.allPatterns.firstWhere((p) => p.id == typeId);
    } catch (_) {
      try {
        return DataPatterns.allPatterns.firstWhere(
          (p) => p.name.toLowerCase() == original.toLowerCase(),
        );
      } catch (_) {
        return null;
      }
    }
  }

  String _mapCategoryToApi(PatternCategory category) {
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

    if (pattern.category == PatternCategory.sensitive) return 'high';
    if (pattern.category == PatternCategory.financial) return 'high';
    return 'medium';
  }

  /// Envia apenas resultados externos (sem criar config ou fazer upload)
  /// Útil para reenviar resultados de scans antigos
  Future<void> sendExternalResults({
    required String scanName,
    required ScanConfig config,
    required User currentUser,
    required List<ScanResult> scanResults,
    required int totalFiles,
    required int processedFiles,
    required int executionTimeMs,
  }) async {
    final scanId = _uuid.v4();

    final payload = await _buildExternalResultsPayload(
      scanId: scanId,
      scanName: _decorateScanName(scanName),
      config: config,
      user: currentUser,
      scanResults: scanResults,
      totalFiles: totalFiles,
      processedFiles: processedFiles,
      executionTimeMs: executionTimeMs,
    );

    await _apiService.sendExternalScanResults(payload);
  }

  String _decorateScanName(String scanName) {
    final trimmed = scanName.trim();
    if (trimmed.isEmpty) return trimmed;

    // Evita prefixar duas vezes.
    final alreadyDecorated =
        RegExp(r'^\{scan#[A-F0-9]{6}\}\s').hasMatch(trimmed);
    if (alreadyDecorated) return trimmed;

    final tag = _generateScanTag();
    return '{scan#$tag} $trimmed';
  }

  String _generateScanTag() {
    final random = Random.secure();
    final bytes = List<int>.generate(3, (_) => random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
  }
}
