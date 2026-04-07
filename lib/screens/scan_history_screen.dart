import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_badge.dart';
import '../theme/app_colors.dart';
import '../providers/scan_provider.dart';
import '../models/scan_result.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<ScanProvider>();
    final history = scanProvider.scanHistory;

    return Column(
      children: [
        // Action Bar
        if (history.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Limpar Histórico'),
                  onPressed: () =>
                      _showClearHistoryDialog(context, scanProvider),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger600,
                  ),
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: history.isEmpty
              ? _buildEmptyState(context)
              : _buildHistoryList(context, history),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 80,
            color: AppColors.gray400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma varredura no histórico',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.gray600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Execute uma varredura para começar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.gray500,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/scan-config');
            },
            icon: const Icon(Icons.search),
            label: const Text('Iniciar Varredura'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<ScanResult> history) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        // Mais recente primeiro
        final result = history[history.length - 1 - index];
        final hasFindings = result.foundData.isNotEmpty;
        final summary = result.getDataTypeSummary();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CustomCard(
            color: hasFindings ? AppColors.danger50 : AppColors.success50,
            onTap: () => _viewScanDetails(context, result),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasFindings
                            ? AppColors.danger600
                            : AppColors.success600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasFindings ? Icons.warning : Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateTime(result.scanDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.scannedPath,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.gray600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.gray400,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.folder_open,
                      label: '${result.totalFilesScanned} arquivos',
                      color: AppColors.info600,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.warning,
                      label: '${result.totalDataFound} dados',
                      color:
                          hasFindings ? AppColors.danger600 : AppColors.gray400,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.timer,
                      label: '${result.scanDuration.inSeconds}s',
                      color: AppColors.primary600,
                    ),
                  ],
                ),
                if (hasFindings && summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: summary.entries.take(5).map((entry) {
                      return CustomBadge(
                        text: '${entry.key}: ${entry.value}',
                        variant: _getBadgeVariantForType(entry.key),
                        small: true,
                      );
                    }).toList(),
                  ),
                  if (summary.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '+${summary.length - 5} outros tipos',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.gray500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  BadgeVariant _getBadgeVariantForType(String type) {
    final typeLower = type.toLowerCase();

    if (typeLower.contains('cpf') ||
        typeLower.contains('rg') ||
        typeLower.contains('cnh')) {
      return BadgeVariant.id;
    } else if (typeLower.contains('nome') || typeLower.contains('nascimento')) {
      return BadgeVariant.personal;
    } else if (typeLower.contains('email') ||
        typeLower.contains('telefone') ||
        typeLower.contains('celular')) {
      return BadgeVariant.contact;
    } else if (typeLower.contains('cartão') ||
        typeLower.contains('conta') ||
        typeLower.contains('pix')) {
      return BadgeVariant.financial;
    } else if (typeLower.contains('senha') || typeLower.contains('token')) {
      return BadgeVariant.sensitive;
    } else if (typeLower.contains('saúde') ||
        typeLower.contains('sus') ||
        typeLower.contains('médico')) {
      return BadgeVariant.health;
    } else if (typeLower.contains('biométrico') ||
        typeLower.contains('digital') ||
        typeLower.contains('facial')) {
      return BadgeVariant.biometric;
    } else if (typeLower.contains('gps') ||
        typeLower.contains('coordenada') ||
        typeLower.contains('endereço')) {
      return BadgeVariant.location;
    }

    return BadgeVariant.neutral;
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora mesmo';
        }
        return '${difference.inMinutes} minutos atrás';
      }
      return '${difference.inHours} horas atrás';
    } else if (difference.inDays == 1) {
      return 'Ontem às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _viewScanDetails(BuildContext context, ScanResult result) {
    // Define o resultado como atual no provider
    final scanProvider = context.read<ScanProvider>();
    scanProvider.setCurrentResult(result);

    Navigator.pushNamed(context, '/scan-results');
  }

  void _showClearHistoryDialog(
      BuildContext context, ScanProvider scanProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Histórico'),
        content: const Text(
          'Tem certeza que deseja remover todas as varreduras do histórico? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              scanProvider.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Histórico limpo com sucesso'),
                  backgroundColor: AppColors.success600,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger600,
            ),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }
}
