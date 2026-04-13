import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../constants/data_patterns.dart';
import '../models/scan_schedule.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_colors.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final schedules = provider.schedules;
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
                    child: Icon(Icons.schedule, size: 32, color: cs.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agendamento de Scans',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure escaneamentos automáticos com periodicidade definida',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Agendamento'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              if (schedules.isEmpty) _buildEmptyState(theme, cs),

              // Lista de agendamentos
              ...schedules
                  .map((s) => _buildScheduleCard(context, s, theme, cs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule, size: 64, color: AppColors.gray300),
          const SizedBox(height: 16),
          Text(
            'Nenhum agendamento configurado',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie um agendamento para executar scans automaticamente.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
      BuildContext context, ScanSchedule s, ThemeData theme, ColorScheme cs) {
    final provider = context.read<ScheduleProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: s.enabled
                ? cs.primary.withValues(alpha: 0.3)
                : AppColors.gray200,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + toggle + actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: s.enabled ? AppColors.success50 : AppColors.gray100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    s.enabled ? Icons.play_circle : Icons.pause_circle,
                    color: s.enabled ? AppColors.success600 : AppColors.gray400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.path,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.gray500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: s.enabled,
                  onChanged: (_) => provider.toggleEnabled(s.id),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showEditor(context, existing: s),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: AppColors.danger500),
                  onPressed: () => _confirmDelete(context, s),
                  tooltip: 'Excluir',
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Info chips
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _chip(Icons.repeat, s.frequencyLabel, cs),
                _chip(
                  Icons.access_time,
                  '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}',
                  cs,
                ),
                _chip(
                    Icons.pattern, '${s.selectedPatterns.length} padrões', cs),
                if (s.includeSubfolders)
                  _chip(Icons.folder_open, 'Subpastas', cs),
                _chip(Icons.storage, '${s.maxFileSizeMb} MB max', cs),
              ],
            ),

            if (s.lastRunAt != null || s.nextRunAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (s.lastRunAt != null)
                    Text(
                      'Último: ${_formatDateTime(s.lastRunAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  if (s.lastRunAt != null && s.nextRunAt != null)
                    const SizedBox(width: 24),
                  if (s.nextRunAt != null && s.enabled)
                    Text(
                      'Próximo: ${_formatDateTime(s.nextRunAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: cs.primary)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDelete(BuildContext context, ScanSchedule s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir agendamento'),
        content: Text('Deseja excluir "${s.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger500),
            onPressed: () {
              context.read<ScheduleProvider>().removeSchedule(s.id);
              Navigator.pop(ctx);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showEditor(BuildContext context, {ScanSchedule? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _ScheduleEditorDialog(existing: existing),
    );
  }
}

// ─── Editor Dialog ──────────────────────────────────────────────────────────

class _ScheduleEditorDialog extends StatefulWidget {
  final ScanSchedule? existing;
  const _ScheduleEditorDialog({this.existing});

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  final _nameCtrl = TextEditingController();
  String? _path;
  final Set<String> _selectedPatterns = {};
  bool _includeSubfolders = true;
  int _maxFileSizeMb = 100;
  ScheduleFrequency _frequency = ScheduleFrequency.daily;
  int _customMinutes = 60;
  int _hour = 8;
  int _minute = 0;
  final Set<int> _weekdays = {1, 2, 3, 4, 5};
  int _dayOfMonth = 1;
  bool _patternsExpanded = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final allPatterns =
        DataPatterns.allPatterns.where((p) => p.enabled).map((p) => p.name);

    if (_isEditing) {
      final s = widget.existing!;
      _nameCtrl.text = s.name;
      _path = s.path;
      _selectedPatterns.addAll(s.selectedPatterns);
      _includeSubfolders = s.includeSubfolders;
      _maxFileSizeMb = s.maxFileSizeMb;
      _frequency = s.frequency;
      _customMinutes = s.customIntervalMinutes;
      _hour = s.hour;
      _minute = s.minute;
      _weekdays
        ..clear()
        ..addAll(s.weekdays);
      _dayOfMonth = s.dayOfMonth;
    } else {
      _selectedPatterns.addAll(allPatterns);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final totalPatterns =
        DataPatterns.allPatterns.where((p) => p.enabled).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header com gradiente ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary,
                    AppColors.primary700,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit_calendar : Icons.alarm_add,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing
                              ? 'Editar Agendamento'
                              : 'Novo Agendamento',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Defina quando e como o scan será executado',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),

            // ── Corpo scrollável ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ━━ Seção: Identificação ━━━━━━━━━━━━━━━━━━━━━
                    _sectionHeader(
                        Icons.badge_outlined, 'Identificação', theme),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: Scan diário de documentos',
                        labelText: 'Nome do agendamento',
                        filled: true,
                        fillColor: AppColors.gray50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.gray200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.gray200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: cs.primary, width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Diretório
                    InkWell(
                      onTap: _pickDirectory,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_outlined,
                                color: _path != null
                                    ? cs.primary
                                    : AppColors.gray400,
                                size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Diretório',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.gray500,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _path ?? 'Clique para selecionar...',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _path != null
                                          ? null
                                          : AppColors.gray400,
                                      fontWeight: _path != null
                                          ? FontWeight.w500
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.gray400, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ━━ Seção: Periodicidade ━━━━━━━━━━━━━━━━━━━━
                    _sectionHeader(Icons.repeat, 'Periodicidade', theme),
                    const SizedBox(height: 12),
                    // Frequency cards
                    Row(
                      children: ScheduleFrequency.values.map((f) {
                        final selected = _frequency == f;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right:
                                  f != ScheduleFrequency.custom ? 8.0 : 0.0,
                            ),
                            child: _FrequencyCard(
                              icon: _frequencyIcon(f),
                              label: _frequencyName(f),
                              selected: selected,
                              onTap: () =>
                                  setState(() => _frequency = f),
                              cs: cs,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    if (_frequency != ScheduleFrequency.custom) ...[
                      // Horário visual
                      _buildTimePicker(theme, cs),
                      const SizedBox(height: 16),
                    ],

                    // Opções condicionais
                    if (_frequency == ScheduleFrequency.weekly) ...[
                      Text('Dias da semana',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _buildWeekdaySelector(cs),
                      const SizedBox(height: 16),
                    ],

                    if (_frequency == ScheduleFrequency.monthly) ...[
                      _buildNumberField(
                        'Dia do mês (1–28)',
                        _dayOfMonth,
                        1,
                        28,
                        (v) => setState(() => _dayOfMonth = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_frequency == ScheduleFrequency.custom) ...[
                      _buildCustomIntervalSelector(theme, cs),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 8),

                    // ━━ Seção: Opções de Scan ━━━━━━━━━━━━━━━━━━━
                    _sectionHeader(Icons.tune, 'Opções de Scan', theme),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Column(
                        children: [
                          // Subpastas
                          SwitchListTile(
                            title: const Text('Incluir subpastas'),
                            subtitle: Text(
                              'Escanear todos os diretórios internos',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.gray400,
                              ),
                            ),
                            value: _includeSubfolders,
                            onChanged: (v) =>
                                setState(() => _includeSubfolders = v),
                            secondary:
                                const Icon(Icons.account_tree_outlined),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12)),
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          // Tamanho máximo
                          ListTile(
                            leading:
                                const Icon(Icons.straighten_outlined),
                            title: const Text('Tamanho máximo por arquivo'),
                            subtitle: Text(
                              '$_maxFileSizeMb MB',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: SizedBox(
                              width: 120,
                              child: DropdownButtonFormField<int>(
                                value: _maxFileSizeMb,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                items: [10, 50, 100, 200]
                                    .map((v) => DropdownMenuItem(
                                          value: v,
                                          child: Text('$v MB'),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _maxFileSizeMb = v!),
                              ),
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ━━ Seção: Padrões (colapsável) ━━━━━━━━━━━━━
                    InkWell(
                      onTap: () => setState(
                          () => _patternsExpanded = !_patternsExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Icon(Icons.fingerprint,
                              size: 18, color: AppColors.gray600),
                          const SizedBox(width: 8),
                          Text(
                            'Padrões de Dados',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.gray700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedPatterns.length == totalPatterns
                                  ? AppColors.success50
                                  : cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_selectedPatterns.length}/$totalPatterns',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    _selectedPatterns.length == totalPatterns
                                        ? AppColors.success700
                                        : cs.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _patternsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AppColors.gray400,
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildPatternsSection(cs, theme),
                      crossFadeState: _patternsExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),

                    const SizedBox(height: 24),

                    // ━━ Resumo visual ━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    _buildSummary(theme, cs),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Footer fixo ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: AppColors.gray200),
                ),
              ),
              child: Row(
                children: [
                  // Dica
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.gray400),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'O app precisa estar na bandeja para executar',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.gray400,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(_isEditing ? Icons.save : Icons.add, size: 18),
                    label: Text(_isEditing ? 'Salvar' : 'Criar Agendamento'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Componentes auxiliares ────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.gray600),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.gray700,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 14),
          Text('Horário:', style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          )),
          const Spacer(),
          // Hora
          _timeSpinner(
            value: _hour,
            max: 23,
            onChanged: (v) => setState(() => _hour = v),
            cs: cs,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(':', style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            )),
          ),
          // Minuto
          _timeSpinner(
            value: _minute,
            max: 59,
            onChanged: (v) => setState(() => _minute = v),
            cs: cs,
          ),
        ],
      ),
    );
  }

  Widget _timeSpinner({
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
    required ColorScheme cs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onChanged(value > 0 ? value - 1 : max),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.remove, size: 16, color: cs.primary),
            ),
          ),
          Container(
            width: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          InkWell(
            onTap: () => onChanged(value < max ? value + 1 : 0),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.add, size: 16, color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomIntervalSelector(ThemeData theme, ColorScheme cs) {
    final presets = [15, 30, 60, 120, 360, 720];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('Intervalo de execução',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((m) {
              final selected = _customMinutes == m;
              final label = m < 60
                  ? '$m min'
                  : '${m ~/ 60}h${m % 60 > 0 ? " ${m % 60}m" : ""}';
              return InkWell(
                onTap: () => setState(() => _customMinutes = m),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : AppColors.gray200,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? Colors.white : AppColors.gray600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaySelector(ColorScheme cs) {
    const days = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    const fullDays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = i + 1;
        final selected = _weekdays.contains(day);
        return Tooltip(
          message: fullDays[i],
          child: InkWell(
            onTap: () {
              setState(() {
                if (selected) {
                  _weekdays.remove(day);
                } else {
                  _weekdays.add(day);
                }
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary
                    : AppColors.gray50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : AppColors.gray300,
                  width: selected ? 0 : 1,
                ),
              ),
              child: Text(
                days[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.gray500,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPatternsSection(ColorScheme cs, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedPatterns.addAll(DataPatterns.allPatterns
                        .where((p) => p.enabled)
                        .map((p) => p.name));
                  });
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Todos'),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _selectedPatterns.clear()),
                icon: const Icon(Icons.deselect, size: 16),
                label: const Text('Nenhum'),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                DataPatterns.allPatterns.where((p) => p.enabled).map((p) {
              final selected = _selectedPatterns.contains(p.name);
              return FilterChip(
                label:
                    Text(p.name, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedPatterns.add(p.name);
                    } else {
                      _selectedPatterns.remove(p.name);
                    }
                  });
                },
                selectedColor: cs.primary.withValues(alpha: 0.12),
                checkmarkColor: cs.primary,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(ThemeData theme, ColorScheme cs) {
    final timeStr =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';
    final freqStr = _frequencyName(_frequency);
    final hasPath = _path != null && _path!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.06),
            cs.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.gray600, height: 1.4),
                children: [
                  const TextSpan(
                      text: 'Resumo: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: '$freqStr às $timeStr'),
                  if (_frequency == ScheduleFrequency.custom)
                    TextSpan(text: ' (a cada $_customMinutes min)'),
                  const TextSpan(text: ' · '),
                  TextSpan(
                      text: '${_selectedPatterns.length} padrões',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: cs.primary)),
                  const TextSpan(text: ' · '),
                  TextSpan(
                      text: hasPath
                          ? _path!.split(RegExp(r'[/\\]')).last
                          : '(sem diretório)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(
      String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return TextField(
      controller: TextEditingController(text: value.toString()),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.gray50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gray200),
        ),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: (txt) {
        final v = int.tryParse(txt);
        if (v != null && v >= min && v <= max) onChanged(v);
      },
    );
  }

  IconData _frequencyIcon(ScheduleFrequency f) {
    switch (f) {
      case ScheduleFrequency.daily:
        return Icons.today;
      case ScheduleFrequency.weekly:
        return Icons.date_range;
      case ScheduleFrequency.monthly:
        return Icons.calendar_month;
      case ScheduleFrequency.custom:
        return Icons.timer_outlined;
    }
  }

  String _frequencyName(ScheduleFrequency f) {
    switch (f) {
      case ScheduleFrequency.daily:
        return 'Diário';
      case ScheduleFrequency.weekly:
        return 'Semanal';
      case ScheduleFrequency.monthly:
        return 'Mensal';
      case ScheduleFrequency.custom:
        return 'Custom';
    }
  }

  Future<void> _pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _path = result);
    }
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para o agendamento')),
      );
      return;
    }
    if (_path == null || _path!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um diretório')),
      );
      return;
    }
    if (_selectedPatterns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um padrão')),
      );
      return;
    }

    final schedule = ScanSchedule(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      path: _path!,
      selectedPatterns: _selectedPatterns.toList(),
      includeSubfolders: _includeSubfolders,
      maxFileSizeMb: _maxFileSizeMb,
      frequency: _frequency,
      customIntervalMinutes: _customMinutes,
      hour: _hour,
      minute: _minute,
      weekdays: _weekdays.toList()..sort(),
      dayOfMonth: _dayOfMonth,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      lastRunAt: widget.existing?.lastRunAt,
    );

    final provider = context.read<ScheduleProvider>();
    if (_isEditing) {
      provider.updateSchedule(schedule);
    } else {
      provider.addSchedule(schedule);
    }

    Navigator.pop(context);
  }
}

// ── Frequency Card Widget ───────────────────────────────────────────────────

class _FrequencyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _FrequencyCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.1)
              : AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : AppColors.gray200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? cs.primary : AppColors.gray400),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? cs.primary : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
