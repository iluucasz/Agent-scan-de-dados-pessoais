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
              ...schedules.map((s) => _buildScheduleCard(context, s, theme, cs)),
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
            color: s.enabled ? cs.primary.withValues(alpha: 0.3) : AppColors.gray200,
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
                    color: s.enabled
                        ? AppColors.success50
                        : AppColors.gray100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    s.enabled ? Icons.play_circle : Icons.pause_circle,
                    color: s.enabled
                        ? AppColors.success600
                        : AppColors.gray400,
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
                  icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger500),
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
                _chip(Icons.pattern, '${s.selectedPatterns.length} padrões', cs),
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
      // Padrão: todos os padrões selecionados
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Editar Agendamento' : 'Novo Agendamento',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nome
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do agendamento',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Diretório
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Diretório',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.folder_outlined),
                              ),
                              child: Text(
                                _path ?? 'Nenhum selecionado',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _path != null
                                      ? null
                                      : AppColors.gray400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _pickDirectory,
                            icon: const Icon(Icons.folder_open),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Frequência
                      Text('Frequência',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ScheduleFrequency.values.map((f) {
                          final selected = _frequency == f;
                          return ChoiceChip(
                            label: Text(_frequencyName(f)),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _frequency = f),
                            selectedColor: cs.primary.withValues(alpha: 0.15),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Horário
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              'Hora',
                              _hour,
                              0,
                              23,
                              (v) => setState(() => _hour = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              'Minuto',
                              _minute,
                              0,
                              59,
                              (v) => setState(() => _minute = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Opções condicionais
                      if (_frequency == ScheduleFrequency.weekly) ...[
                        Text('Dias da semana',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _buildWeekdaySelector(),
                        const SizedBox(height: 16),
                      ],

                      if (_frequency == ScheduleFrequency.monthly) ...[
                        _buildNumberField(
                          'Dia do mês',
                          _dayOfMonth,
                          1,
                          28,
                          (v) => setState(() => _dayOfMonth = v),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_frequency == ScheduleFrequency.custom) ...[
                        _buildNumberField(
                          'Intervalo (minutos)',
                          _customMinutes,
                          5,
                          1440,
                          (v) => setState(() => _customMinutes = v),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Subpastas + tamanho
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              title: const Text('Incluir subpastas'),
                              value: _includeSubfolders,
                              onChanged: (v) =>
                                  setState(() => _includeSubfolders = v),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<int>(
                              value: _maxFileSizeMb,
                              decoration: const InputDecoration(
                                labelText: 'Tam. máx.',
                                border: OutlineInputBorder(),
                                isDense: true,
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
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Padrões
                      Text('Padrões de dados',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedPatterns.addAll(DataPatterns
                                    .allPatterns
                                    .where((p) => p.enabled)
                                    .map((p) => p.name));
                              });
                            },
                            child: const Text('Todos'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedPatterns.clear()),
                            child: const Text('Nenhum'),
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedPatterns.length} selecionados',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: DataPatterns.allPatterns
                            .where((p) => p.enabled)
                            .map((p) {
                          final selected = _selectedPatterns.contains(p.name);
                          return FilterChip(
                            label: Text(p.name, style: const TextStyle(fontSize: 12)),
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
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _save,
                    child: Text(_isEditing ? 'Salvar' : 'Criar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField(
      String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return TextField(
      controller: TextEditingController(text: value.toString()),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: (txt) {
        final v = int.tryParse(txt);
        if (v != null && v >= min && v <= max) onChanged(v);
      },
    );
  }

  Widget _buildWeekdaySelector() {
    const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return Wrap(
      spacing: 6,
      children: List.generate(7, (i) {
        final day = i + 1; // 1=seg, 7=dom
        final selected = _weekdays.contains(day);
        return FilterChip(
          label: Text(days[i]),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _weekdays.add(day);
              } else {
                _weekdays.remove(day);
              }
            });
          },
          visualDensity: VisualDensity.compact,
        );
      }),
    );
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
        return 'Personalizado';
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
