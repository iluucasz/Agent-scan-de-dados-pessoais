enum LogLevel { info, warning, error }

enum LogCategory { installation, execution, error }

class LogEntry {
  final int? id;
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final String? details;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.details,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'category': category.name,
        'message': message,
        'details': details,
      };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
        id: map['id'] as int?,
        timestamp: DateTime.parse(map['timestamp'] as String),
        level: LogLevel.values.byName(map['level'] as String),
        category: LogCategory.values.byName(map['category'] as String),
        message: map['message'] as String,
        details: map['details'] as String?,
      );
}
