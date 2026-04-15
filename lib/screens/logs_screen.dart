import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/logging_service.dart';
import '../theme/app_colors.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final LoggingService _loggingService = LoggingService.instance;

  List<LogEntry> _logs = [];
  bool _isLoading = true;

  LogLevel? _filterLevel;
  LogCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _loggingService.getLogs(
        level: _filterLevel,
        category: _filterCategory,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar todos os logs?'),
        content: const Text(
            'Esta ação é irreversível. Todos os registros serão removidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger600),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _loggingService.clearLogs();
      _loadLogs();
    }
  }

  // ---------- UI helpers ----------

  IconData _levelIcon(LogLevel level) => switch (level) {
        LogLevel.info => Icons.info_outline,
        LogLevel.warning => Icons.warning_amber_rounded,
        LogLevel.error => Icons.error_outline,
      };

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.info => AppColors.primary500,
        LogLevel.warning => AppColors.warning600,
        LogLevel.error => AppColors.danger600,
      };

  String _levelLabel(LogLevel level) => switch (level) {
        LogLevel.info => 'Info',
        LogLevel.warning => 'Aviso',
        LogLevel.error => 'Erro',
      };

  String _categoryLabel(LogCategory cat) => switch (cat) {
        LogCategory.installation => 'Instalação',
        LogCategory.execution => 'Execução',
        LogCategory.error => 'Erro',
      };

  Color _categoryChipColor(LogCategory cat) => switch (cat) {
        LogCategory.installation => AppColors.primary100,
        LogCategory.execution => AppColors.success100,
        LogCategory.error => AppColors.danger100,
      };

  Color _categoryTextColor(LogCategory cat) => switch (cat) {
        LogCategory.installation => AppColors.primary700,
        LogCategory.execution => AppColors.success700,
        LogCategory.error => AppColors.danger700,
      };

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:'
        '${d.second.toString().padLeft(2, '0')}';
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.article_outlined,
                        size: 32, color: cs.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logs e Telemetria',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Registros de instalação, execução e erros do sistema',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _loadLogs,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Atualizar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _logs.isEmpty ? null : _clearLogs,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Limpar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Filters
              _buildFilters(cs),

              const SizedBox(height: 16),

              // Content
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_logs.isEmpty)
                _buildEmptyState(theme, cs)
              else
                ..._logs.map((entry) => _buildLogCard(entry, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Level filter
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gray300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<LogLevel?>(
              value: _filterLevel,
              hint: const Text('Todos os níveis'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todos os níveis')),
                ...LogLevel.values.map(
                  (l) => DropdownMenuItem(
                    value: l,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_levelIcon(l), size: 16, color: _levelColor(l)),
                        const SizedBox(width: 6),
                        Text(_levelLabel(l)),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _filterLevel = v);
                _loadLogs();
              },
            ),
          ),
        ),

        // Category filter
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gray300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<LogCategory?>(
              value: _filterCategory,
              hint: const Text('Todas as categorias'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todas as categorias')),
                ...LogCategory.values.map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(_categoryLabel(c)),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _filterCategory = v);
                _loadLogs();
              },
            ),
          ),
        ),

        // Summary chips
        if (!_isLoading) ...[
          _buildCountChip(
              '${_logs.length} registros', Icons.list, AppColors.gray600),
        ],
      ],
    );
  }

  Widget _buildCountChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: AppColors.gray100,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.article_outlined, size: 64, color: AppColors.gray300),
          const SizedBox(height: 16),
          Text(
            'Nenhum log registrado',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Logs de instalação, execução e erros aparecerão aqui',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(LogEntry entry, ThemeData theme) {
    final color = _levelColor(entry.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.gray200),
      ),
      elevation: 0,
      child: ExpansionTile(
        leading: Icon(_levelIcon(entry.level), color: color, size: 22),
        title: Text(
          entry.message,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              _formatDate(entry.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.gray400,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _categoryChipColor(entry.category),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _categoryLabel(entry.category),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _categoryTextColor(entry.category),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _levelLabel(entry.level),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        children: [
          if (entry.details != null && entry.details!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                entry.details!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.gray700,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
