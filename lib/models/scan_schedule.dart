/// Frequência de agendamento de scan.
enum ScheduleFrequency {
  daily,
  weekly,
  monthly,
  custom,
}

/// Modelo que representa um agendamento de scan recorrente.
class ScanSchedule {
  final String id;
  final String name;
  final String path;
  final List<String> selectedPatterns;
  final bool includeSubfolders;
  final int maxFileSizeMb;
  final ScheduleFrequency frequency;

  /// Intervalo em minutos (usado quando frequency == custom).
  final int customIntervalMinutes;

  /// Hora do dia para execução (0–23).
  final int hour;

  /// Minuto da hora (0–59).
  final int minute;

  /// Dias da semana (1=segunda … 7=domingo). Usado quando frequency == weekly.
  final List<int> weekdays;

  /// Dia do mês (1–28). Usado quando frequency == monthly.
  final int dayOfMonth;

  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;

  const ScanSchedule({
    required this.id,
    required this.name,
    required this.path,
    required this.selectedPatterns,
    this.includeSubfolders = true,
    this.maxFileSizeMb = 100,
    this.frequency = ScheduleFrequency.daily,
    this.customIntervalMinutes = 60,
    this.hour = 8,
    this.minute = 0,
    this.weekdays = const [1, 2, 3, 4, 5],
    this.dayOfMonth = 1,
    this.enabled = true,
    required this.createdAt,
    this.lastRunAt,
    this.nextRunAt,
  });

  ScanSchedule copyWith({
    String? id,
    String? name,
    String? path,
    List<String>? selectedPatterns,
    bool? includeSubfolders,
    int? maxFileSizeMb,
    ScheduleFrequency? frequency,
    int? customIntervalMinutes,
    int? hour,
    int? minute,
    List<int>? weekdays,
    int? dayOfMonth,
    bool? enabled,
    DateTime? createdAt,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
  }) {
    return ScanSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      selectedPatterns: selectedPatterns ?? this.selectedPatterns,
      includeSubfolders: includeSubfolders ?? this.includeSubfolders,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      frequency: frequency ?? this.frequency,
      customIntervalMinutes:
          customIntervalMinutes ?? this.customIntervalMinutes,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      nextRunAt: nextRunAt ?? this.nextRunAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'selectedPatterns': selectedPatterns,
      'includeSubfolders': includeSubfolders,
      'maxFileSizeMb': maxFileSizeMb,
      'frequency': frequency.name,
      'customIntervalMinutes': customIntervalMinutes,
      'hour': hour,
      'minute': minute,
      'weekdays': weekdays,
      'dayOfMonth': dayOfMonth,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'lastRunAt': lastRunAt?.toIso8601String(),
      'nextRunAt': nextRunAt?.toIso8601String(),
    };
  }

  factory ScanSchedule.fromJson(Map<String, dynamic> json) {
    return ScanSchedule(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      selectedPatterns: (json['selectedPatterns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      includeSubfolders: json['includeSubfolders'] as bool? ?? true,
      maxFileSizeMb: json['maxFileSizeMb'] as int? ?? 100,
      frequency: ScheduleFrequency.values.firstWhere(
        (f) => f.name == json['frequency'],
        orElse: () => ScheduleFrequency.daily,
      ),
      customIntervalMinutes: json['customIntervalMinutes'] as int? ?? 60,
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
      weekdays:
          (json['weekdays'] as List<dynamic>?)?.map((e) => e as int).toList() ??
              const [1, 2, 3, 4, 5],
      dayOfMonth: json['dayOfMonth'] as int? ?? 1,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastRunAt: json['lastRunAt'] != null
          ? DateTime.parse(json['lastRunAt'] as String)
          : null,
      nextRunAt: json['nextRunAt'] != null
          ? DateTime.parse(json['nextRunAt'] as String)
          : null,
    );
  }

  /// Calcula a próxima execução a partir de [from].
  DateTime computeNextRun(DateTime from) {
    switch (frequency) {
      case ScheduleFrequency.daily:
        var next = DateTime(from.year, from.month, from.day, hour, minute);
        if (next.isBefore(from) || next.isAtSameMomentAs(from)) {
          next = next.add(const Duration(days: 1));
        }
        return next;

      case ScheduleFrequency.weekly:
        final sortedDays = List<int>.from(weekdays)..sort();
        for (var d = 0; d < 8; d++) {
          final candidate = from.add(Duration(days: d));
          final dow = candidate.weekday; // 1=monday..7=sunday
          if (sortedDays.contains(dow)) {
            final next = DateTime(
                candidate.year, candidate.month, candidate.day, hour, minute);
            if (next.isAfter(from)) return next;
          }
        }
        // Fallback: próxima semana no primeiro dia habilitado
        final firstDay = sortedDays.isNotEmpty ? sortedDays.first : 1;
        var candidate = from.add(const Duration(days: 7));
        while (candidate.weekday != firstDay) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return DateTime(
            candidate.year, candidate.month, candidate.day, hour, minute);

      case ScheduleFrequency.monthly:
        var next = DateTime(from.year, from.month, dayOfMonth, hour, minute);
        if (next.isBefore(from) || next.isAtSameMomentAs(from)) {
          final m = from.month + 1;
          next = DateTime(from.year + (m > 12 ? 1 : 0), (m - 1) % 12 + 1,
              dayOfMonth, hour, minute);
        }
        return next;

      case ScheduleFrequency.custom:
        return from.add(Duration(minutes: customIntervalMinutes));
    }
  }

  String get frequencyLabel {
    switch (frequency) {
      case ScheduleFrequency.daily:
        return 'Diário';
      case ScheduleFrequency.weekly:
        return 'Semanal';
      case ScheduleFrequency.monthly:
        return 'Mensal';
      case ScheduleFrequency.custom:
        return 'A cada $customIntervalMinutes min';
    }
  }
}
