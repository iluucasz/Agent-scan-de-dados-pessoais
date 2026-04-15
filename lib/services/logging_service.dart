import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/log_entry.dart';

class LoggingService {
  static Database? _database;
  static const String _dbName = 'seusdados_logs.db';
  static const int _dbVersion = 1;

  LoggingService._();
  static final LoggingService instance = LoggingService._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String dbPath = join(appDocDir.path, _dbName);

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        level TEXT NOT NULL,
        category TEXT NOT NULL,
        message TEXT NOT NULL,
        details TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_logs_timestamp ON logs(timestamp DESC)');
    await db.execute(
        'CREATE INDEX idx_logs_level ON logs(level)');
    await db.execute(
        'CREATE INDEX idx_logs_category ON logs(category)');
  }

  // ---------- write ----------

  Future<void> log(
    LogLevel level,
    LogCategory category,
    String message, {
    String? details,
  }) async {
    try {
      final db = await database;
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: message,
        details: details,
      );
      await db.insert('logs', entry.toMap());
    } catch (e) {
      debugPrint('[LoggingService] Failed to write log: $e');
    }
  }

  Future<void> info(LogCategory category, String message,
          {String? details}) =>
      log(LogLevel.info, category, message, details: details);

  Future<void> warning(LogCategory category, String message,
          {String? details}) =>
      log(LogLevel.warning, category, message, details: details);

  Future<void> error(LogCategory category, String message,
          {String? details}) =>
      log(LogLevel.error, category, message, details: details);

  // ---------- read ----------

  Future<List<LogEntry>> getLogs({
    LogLevel? level,
    LogCategory? category,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await database;

    final where = <String>[];
    final args = <dynamic>[];

    if (level != null) {
      where.add('level = ?');
      args.add(level.name);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category.name);
    }

    final rows = await db.query(
      'logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(LogEntry.fromMap).toList();
  }

  Future<int> getLogCount({LogLevel? level, LogCategory? category}) async {
    final db = await database;

    final where = <String>[];
    final args = <dynamic>[];

    if (level != null) {
      where.add('level = ?');
      args.add(level.name);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category.name);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM logs${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
      args.isEmpty ? null : args,
    );

    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> clearLogs() async {
    final db = await database;
    await db.delete('logs');
  }
}
