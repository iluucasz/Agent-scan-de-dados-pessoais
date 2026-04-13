import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_badge.dart';
import '../theme/app_colors.dart';
import '../providers/scan_provider.dart';
import '../models/scan_result.dart';
import '../services/database_service.dart';

// ─────────────────────────── Filtro Enum ────────────────────────────
enum _FindingsFilter { all, withFindings, clean }

// ─────────────────────────── Tela Principal ─────────────────────────
class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  // ── Paginação ──
  static const int _pageSize = 15;
  int _currentPage = 0;
  int _totalCount = 0;
  List<ScanResult> _pageItems = [];
  bool _loading = true;

  // ── Filtros ──
  _FindingsFilter _findingsFilter = _FindingsFilter.all;
  String? _pathFilter;
  List<String> _availablePaths = [];

  // ── Ordenação ──
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-carrega ao voltar/atualizar o provider (ex: scan agendado terminou).
    final provider = context.watch<ScanProvider>();
    // Usar o hashCode da lista como gatilho simples de mudança.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPage();
    });
  }

  Future<void> _loadPage() async {
    final db = DatabaseService.instance;

    bool? hasFindings;
    if (_findingsFilter == _FindingsFilter.withFindings) hasFindings = true;
    if (_findingsFilter == _FindingsFilter.clean) hasFindings = false;

    final count = await db.getScanCount(
      pathFilter: _pathFilter,
      hasFindings: hasFindings,
    );
    final items = await db.getScanResultsPaged(
      offset: _currentPage * _pageSize,
      limit: _pageSize,
      pathFilter: _pathFilter,
      hasFindings: hasFindings,
      orderBy: _newestFirst ? 'scan_date DESC' : 'scan_date ASC',
    );
    final paths = await db.getDistinctPaths();

    if (!mounted) return;
    setState(() {
      _totalCount = count;
      _pageItems = items;
      _availablePaths = paths;
      _loading = false;
    });
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 999);

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() {
      _currentPage = page;
      _loading = true;
    });
    _loadPage();
  }

  void _applyFilter({_FindingsFilter? findings, String? path, bool? order}) {
    setState(() {
      if (findings != null) _findingsFilter = findings;
      if (path != null) _pathFilter = path.isEmpty ? null : path;
      if (order != null) _newestFirst = order;
      _currentPage = 0;
      _loading = true;
    });
    _loadPage();
  }

  // ════════════════════════════ BUILD ════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // ── Header + filtros ──
        _buildHeader(theme, cs),

        // ── Conteúdo ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _totalCount == 0
                  ? _buildEmptyState(theme)
                  : _buildHistoryList(theme, cs),
        ),

        // ── Paginação ──
        if (!_loading && _totalCount > 0) _buildPagination(theme, cs),
      ],
    );
  }

  // ─────────────────────── Header / Filtros ─────────────────────
  Widget _buildHeader(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + botão limpar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.history, size: 28, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histórico de Varreduras',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalCount resultado${_totalCount != 1 ? 's' : ''} encontrado${_totalCount != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_totalCount > 0)
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Limpar'),
                  onPressed: () => _showClearHistoryDialog(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger600,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Barra de filtros
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Findings filter chips
              _filterChip(
                label: 'Todos',
                selected: _findingsFilter == _FindingsFilter.all,
                onTap: () =>
                    _applyFilter(findings: _FindingsFilter.all),
                icon: Icons.list,
              ),
              _filterChip(
                label: 'Com achados',
                selected: _findingsFilter == _FindingsFilter.withFindings,
                onTap: () =>
                    _applyFilter(findings: _FindingsFilter.withFindings),
                icon: Icons.warning_amber,
                accentColor: AppColors.danger500,
              ),
              _filterChip(
                label: 'Limpos',
                selected: _findingsFilter == _FindingsFilter.clean,
                onTap: () =>
                    _applyFilter(findings: _FindingsFilter.clean),
                icon: Icons.check_circle_outline,
                accentColor: AppColors.success600,
              ),

              // Separador visual
              Container(
                width: 1,
                height: 24,
                color: AppColors.gray200,
              ),

              // Path dropdown
              if (_availablePaths.length > 1)
                _buildPathDropdown(theme),

              // Ordenação
              _filterChip(
                label: _newestFirst ? 'Mais recentes' : 'Mais antigos',
                selected: true,
                onTap: () => _applyFilter(order: !_newestFirst),
                icon: _newestFirst
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.primary500;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : AppColors.gray50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : AppColors.gray200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? color : AppColors.gray500),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : AppColors.gray600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gray200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _pathFilter,
          hint: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_outlined, size: 14, color: AppColors.gray500),
              SizedBox(width: 6),
              Text('Diretório', style: TextStyle(fontSize: 12, color: AppColors.gray500)),
            ],
          ),
          isDense: true,
          style: const TextStyle(fontSize: 12, color: AppColors.gray700),
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.gray400),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Todos os diretórios', style: TextStyle(fontSize: 12)),
            ),
            ..._availablePaths.map((p) {
              // Mostra só o último segmento do path para manter compacto.
              final shortPath = p.split(RegExp(r'[/\\]')).last;
              return DropdownMenuItem(
                value: p,
                child: Tooltip(
                  message: p,
                  child: Text(
                    shortPath,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
          ],
          onChanged: (v) => _applyFilter(path: v ?? ''),
        ),
      ),
    );
  }

  // ─────────────────────── Empty state ──────────────────────────
  Widget _buildEmptyState(ThemeData theme) {
    final isFiltered = _findingsFilter != _FindingsFilter.all || _pathFilter != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off : Icons.history,
            size: 72,
            color: AppColors.gray300,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'Nenhum resultado com esses filtros'
                : 'Nenhuma varredura no histórico',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.gray600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Altere os filtros acima ou limpe a seleção'
                : 'Execute uma varredura para começar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.gray400,
            ),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/scan-config'),
              icon: const Icon(Icons.search),
              label: const Text('Iniciar Varredura'),
            ),
          ],
          if (isFiltered) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _findingsFilter = _FindingsFilter.all;
                  _pathFilter = null;
                  _currentPage = 0;
                  _loading = true;
                });
                _loadPage();
              },
              child: const Text('Limpar filtros'),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────── Lista ────────────────────────────────
  Widget _buildHistoryList(ThemeData theme, ColorScheme cs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      itemCount: _pageItems.length,
      itemBuilder: (context, index) {
        final result = _pageItems[index];
        return _HistoryCard(
          result: result,
          onTap: () => _viewScanDetails(result),
          onDelete: () => _deleteSingle(result),
        );
      },
    );
  }

  // ─────────────────────── Paginação ────────────────────────────
  Widget _buildPagination(ThemeData theme, ColorScheme cs) {
    final start = _currentPage * _pageSize + 1;
    final end = (start + _pageItems.length - 1).clamp(start, _totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.gray200)),
      ),
      child: Row(
        children: [
          Text(
            'Exibindo $start–$end de $_totalCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.gray500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.first_page, size: 20),
            onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
            tooltip: 'Primeira página',
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed:
                _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
            tooltip: 'Anterior',
            splashRadius: 18,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_currentPage + 1} / $_totalPages',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _currentPage < _totalPages - 1
                ? () => _goToPage(_currentPage + 1)
                : null,
            tooltip: 'Próxima',
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 20),
            onPressed: _currentPage < _totalPages - 1
                ? () => _goToPage(_totalPages - 1)
                : null,
            tooltip: 'Última página',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Ações ────────────────────────────────
  void _viewScanDetails(ScanResult result) {
    final scanProvider = context.read<ScanProvider>();
    scanProvider.setCurrentResult(result);
    Navigator.pushNamed(context, '/scan-results');
  }

  Future<void> _deleteSingle(ScanResult result) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover varredura'),
        content: const Text('Remover esta varredura do histórico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger600),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await context.read<ScanProvider>().removeFromHistory(result);
    _loadPage();
  }

  void _showClearHistoryDialog() {
    final scanProvider = context.read<ScanProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar Histórico'),
        content: const Text(
          'Tem certeza que deseja remover todas as varreduras do histórico? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await scanProvider.clearHistory();
              if (mounted) {
                Navigator.pop(ctx);
                _loadPage();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Histórico limpo com sucesso'),
                    backgroundColor: AppColors.success600,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger600),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════ Card do Histórico ═══════════════════════
class _HistoryCard extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.result,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasFindings = result.foundData.isNotEmpty;
    final summary = result.getDataTypeSummary();
    final accentColor = hasFindings ? AppColors.danger500 : AppColors.success600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.25),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row ──
                Row(
                  children: [
                    // Status icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasFindings ? Icons.warning_amber : Icons.check_circle,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date + path
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateTime(result.scanDate),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.scannedPath,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.gray500,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: AppColors.gray400),
                      onPressed: onDelete,
                      splashRadius: 16,
                      tooltip: 'Remover',
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.gray300),
                  ],
                ),

                const Divider(height: 24),

                // ── Stats row ──
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.folder_open,
                      label: '${result.totalFilesScanned} arquivos',
                      color: AppColors.info600,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.warning_amber,
                      label: '${result.totalDataFound} dados',
                      color: hasFindings ? AppColors.danger600 : AppColors.gray400,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.timer,
                      label: _formatDuration(result.scanDuration),
                      color: AppColors.primary600,
                    ),
                  ],
                ),

                // ── Data-type badges ──
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
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  static String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes < 2) return 'Agora mesmo';
        return '${diff.inMinutes} min atrás';
      }
      return 'Hoje às $time';
    } else if (diff.inDays == 1) {
      return 'Ontem às $time';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} dias atrás às $time';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $time';
  }

  static BadgeVariant _getBadgeVariantForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('cpf') || t.contains('rg') || t.contains('cnh')) {
      return BadgeVariant.id;
    } else if (t.contains('nome') || t.contains('nascimento')) {
      return BadgeVariant.personal;
    } else if (t.contains('email') || t.contains('telefone') || t.contains('celular')) {
      return BadgeVariant.contact;
    } else if (t.contains('cartão') || t.contains('conta') || t.contains('pix')) {
      return BadgeVariant.financial;
    } else if (t.contains('senha') || t.contains('token')) {
      return BadgeVariant.sensitive;
    } else if (t.contains('saúde') || t.contains('sus') || t.contains('médico')) {
      return BadgeVariant.health;
    } else if (t.contains('biométrico') || t.contains('digital') || t.contains('facial')) {
      return BadgeVariant.biometric;
    } else if (t.contains('gps') || t.contains('coordenada') || t.contains('endereço')) {
      return BadgeVariant.location;
    }
    return BadgeVariant.neutral;
  }
}

// ═══════════════════════ Stat Chip ══════════════════════════════
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
}
