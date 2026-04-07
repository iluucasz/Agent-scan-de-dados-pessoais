import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../theme/app_colors.dart';
import '../providers/scan_provider.dart';

class ScanProgressScreen extends StatefulWidget {
  const ScanProgressScreen({super.key});

  @override
  State<ScanProgressScreen> createState() => _ScanProgressScreenState();
}

class _ScanProgressScreenState extends State<ScanProgressScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animação de rotação contínua para a borda
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Animação de pulsação para o centro
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Animação de escala para entrada
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _scaleController.forward();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Escaneando...'),
          automaticallyImplyLeading: false,
        ),
        body: Consumer<ScanProvider>(
          builder: (context, scanProvider, child) {
            final isComplete = scanProvider.status == ScanStatus.completed;
            final isFailed = scanProvider.status == ScanStatus.failed;

            if (isComplete || isFailed) {
              // Redirecionar automaticamente para resultados
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (isComplete) {
                  Navigator.pushReplacementNamed(context, '/scan-results');
                } else {
                  Navigator.pop(context);
                }
              });
            }

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary50,
                    Colors.white,
                    AppColors.info50,
                  ],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = MediaQuery.of(context).size;
                    final isSmallScreen = size.height < 700;
                    final circleSize = isSmallScreen ? 200.0 : 280.0;

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Área principal do progresso (reduzida)
                            SizedBox(
                              height: isSmallScreen ? 250 : 320,
                              child: Center(
                                child: ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: _buildCircularProgress(
                                      context, scanProvider, circleSize),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Status compacto
                            _buildPhaseIndicator(scanProvider),
                            const SizedBox(height: 16),
                            _buildStatsCard(scanProvider),
                            const SizedBox(height: 20),

                            // Painel de logs em tempo real
                            SizedBox(
                              height: isSmallScreen ? 200 : 300,
                              child: _buildLogPanel(scanProvider),
                            ),

                            const SizedBox(height: 20),

                            // Botão cancelar moderno
                            _buildModernCancelButton(context, scanProvider),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Widget principal circular com animações
  Widget _buildCircularProgress(
      BuildContext context, ScanProvider scanProvider, double size) {
    final progress = scanProvider.totalFiles > 0
        ? scanProvider.filesScanned / scanProvider.totalFiles
        : 0.0;

    final innerSize = size * 0.93;
    final progressSize = size * 0.86;
    final containerSize = size * 0.79;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo de fundo
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary50.withValues(alpha: 0.3),
                  AppColors.primary50.withValues(alpha: 0.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary200.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Borda animada rotativa
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.primary600,
                        AppColors.primary400,
                        AppColors.info500,
                        AppColors.primary600,
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Círculo interno
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gray300.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Progresso circular
          SizedBox(
            width: progressSize,
            height: progressSize,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: size * 0.029,
              backgroundColor: AppColors.gray100,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary600),
            ),
          ),

          // Conteúdo central com pulsação
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getScanPhaseIcon(scanProvider.currentPhase),
                      size: size * 0.14,
                      color: AppColors.primary600,
                    ),
                    SizedBox(height: size * 0.03),
                    Text(
                      'Scan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary700,
                        fontSize: size * 0.086,
                      ),
                    ),
                    SizedBox(height: size * 0.02),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary600,
                        fontSize: size * 0.064,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Indicador de fase atual
  Widget _buildPhaseIndicator(ScanProvider scanProvider) {
    final detailMessage = (scanProvider.phaseMessage.isNotEmpty)
        ? scanProvider.phaseMessage
        : scanProvider.statusMessage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary600.withValues(alpha: 0.1),
            AppColors.info500.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.primary200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary600,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary600.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _getPhaseText(scanProvider.currentPhase),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary700,
                    ),
              ),
            ],
          ),
          if (detailMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detailMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.gray700,
                    height: 1.2,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  // Card com estatísticas
  Widget _buildStatsCard(ScanProvider scanProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray300.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            Icons.description,
            'Arquivos',
            scanProvider.totalFiles > 0
                ? '${scanProvider.filesScanned}/${scanProvider.totalFiles}'
                : '${scanProvider.filesScanned}',
            AppColors.primary600,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.gray200,
          ),
          _buildStatItem(
            Icons.speed,
            'Tempo',
            _formatExecutionTime(scanProvider.executionTimeMs),
            AppColors.info600,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.gray200,
          ),
          _buildStatItem(
            Icons.search,
            'Achados',
            '${scanProvider.totalDataFound}',
            AppColors.success600,
          ),
        ],
      ),
    );
  }

  // Item de estatística
  Widget _buildStatItem(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.gray600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Botão cancelar moderno
  Widget _buildModernCancelButton(
      BuildContext context, ScanProvider scanProvider) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.danger500, AppColors.danger600],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger500.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            scanProvider.cancelScan();
            Navigator.pop(context);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.stop_circle_outlined,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Cancelar Scan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Métodos auxiliares
  IconData _getScanPhaseIcon(ScanPhaseStatus phase) {
    switch (phase) {
      case ScanPhaseStatus.creatingConfig:
        return Icons.settings;
      case ScanPhaseStatus.uploadingFiles:
        return Icons.cloud_upload;
      case ScanPhaseStatus.scanningLocally:
        return Icons.search;
      case ScanPhaseStatus.sendingResults:
        return Icons.send;
      default:
        return Icons.radar;
    }
  }

  String _getPhaseText(ScanPhaseStatus phase) {
    switch (phase) {
      case ScanPhaseStatus.idle:
        return 'Preparando escaneamento...';
      case ScanPhaseStatus.creatingConfig:
        return 'Configurando parâmetros...';
      case ScanPhaseStatus.uploadingFiles:
        return 'Enviando para análise...';
      case ScanPhaseStatus.scanningLocally:
        return 'Analisando arquivos...';
      case ScanPhaseStatus.sendingResults:
        return 'Processando resultados...';
      case ScanPhaseStatus.completedWithApi:
        return 'Análise completa finalizada!';
      case ScanPhaseStatus.completedLocalOnly:
        return 'Análise local concluída';
      case ScanPhaseStatus.failed:
        return 'Erro durante processo';
    }
  }

  String _formatExecutionTime(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000.0;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    return '${minutes}m ${remainingSeconds}s';
  }

  Color _logMessageColor(String message) {
    if (message.contains('❌')) return AppColors.danger600;
    if (message.contains('⚠️')) return AppColors.warning600;
    if (message.contains('✅') || message.contains('🎉')) {
      return AppColors.success700;
    }
    if (message.contains('🔍')) return AppColors.primary700;
    if (message.contains('📁') || message.contains('📂')) {
      return AppColors.info700;
    }
    if (message.contains('💾')) return AppColors.primary700;
    if (message.contains('📄')) return AppColors.gray700;
    return AppColors.gray800;
  }

  Widget _buildLogPanel(ScanProvider scanProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: AppColors.gray200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do log
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal,
                  color: AppColors.primary700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Log de Execução',
                  style: TextStyle(
                    color: AppColors.primary700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${scanProvider.logMessages.length} entradas',
                  style: const TextStyle(
                    color: AppColors.gray600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Lista de logs scrollable
          Expanded(
            child: scanProvider.logMessages.isEmpty
                ? const Center(
                    child: Text(
                      'Aguardando início do scan...',
                      style: TextStyle(
                        color: AppColors.gray500,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: scanProvider.logMessages.length,
                    reverse: true, // Mostrar logs mais recentes no topo
                    itemBuilder: (context, index) {
                      final reversedIndex =
                          scanProvider.logMessages.length - 1 - index;
                      final message = scanProvider.logMessages[reversedIndex];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          message,
                          style: TextStyle(
                            color: _logMessageColor(message),
                            fontSize: 13,
                            fontFamily: 'monospace',
                            height: 1.2,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
