import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/scan_result.dart';
import '../models/personal_data.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'seusdados.db';
  static const int _dbVersion = 1;

  // Singleton
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Inicializar FFI para Windows/Linux/MacOS
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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de resultados de scan
    await db.execute('''
      CREATE TABLE scan_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scan_date TEXT NOT NULL,
        scan_duration INTEGER NOT NULL,
        scanned_path TEXT NOT NULL,
        total_files_scanned INTEGER NOT NULL,
        total_data_found INTEGER NOT NULL
      )
    ''');

    // Tabela de dados pessoais encontrados
    await db.execute('''
      CREATE TABLE personal_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scan_result_id INTEGER NOT NULL,
        data_type TEXT NOT NULL,
        value TEXT NOT NULL,
        file_path TEXT NOT NULL,
        line_number INTEGER NOT NULL,
        confidence REAL NOT NULL,
        FOREIGN KEY (scan_result_id) REFERENCES scan_results (id) ON DELETE CASCADE
      )
    ''');

    // Índices para melhorar performance
    await db.execute('''
      CREATE INDEX idx_scan_date ON scan_results(scan_date DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_personal_data_scan ON personal_data(scan_result_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Implementar migrações futuras aqui
  }

  // Salvar resultado de scan
  Future<int> saveScanResult(ScanResult result) async {
    final db = await database;

    // Inserir resultado
    final scanId = await db.insert('scan_results', {
      'scan_date': result.scanDate.toIso8601String(),
      'scan_duration': result.scanDuration.inSeconds,
      'scanned_path': result.scannedPath,
      'total_files_scanned': result.totalFilesScanned,
      'total_data_found': result.totalDataFound,
    });

    // Inserir dados encontrados
    for (final data in result.foundData) {
      await db.insert('personal_data', {
        'scan_result_id': scanId,
        'data_type': data.dataType,
        'value': data.value,
        'file_path': data.filePath,
        'line_number': data.lineNumber,
        'confidence': data.confidence,
      });
    }

    return scanId;
  }

  // Buscar todos os resultados
  Future<List<ScanResult>> getAllScanResults() async {
    final db = await database;

    final results = await db.query(
      'scan_results',
      orderBy: 'scan_date DESC',
    );

    final scanResults = <ScanResult>[];

    for (final row in results) {
      final scanId = row['id'] as int;

      // Buscar dados pessoais deste scan
      final dataRows = await db.query(
        'personal_data',
        where: 'scan_result_id = ?',
        whereArgs: [scanId],
      );

      final foundData = dataRows.map((dataRow) {
        return PersonalData(
          dataType: dataRow['data_type'] as String,
          value: dataRow['value'] as String,
          filePath: dataRow['file_path'] as String,
          lineNumber: dataRow['line_number'] as int,
          confidence: dataRow['confidence'] as double,
        );
      }).toList();

      scanResults.add(ScanResult(
        foundData: foundData,
        totalFilesScanned: row['total_files_scanned'] as int,
        totalDataFound: row['total_data_found'] as int,
        scanDate: DateTime.parse(row['scan_date'] as String),
        scanDuration: Duration(seconds: row['scan_duration'] as int),
        scannedPath: row['scanned_path'] as String,
      ));
    }

    return scanResults;
  }

  // Buscar resultado específico
  Future<ScanResult?> getScanResult(int id) async {
    final db = await database;

    final results = await db.query(
      'scan_results',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final scanId = row['id'] as int;

    final dataRows = await db.query(
      'personal_data',
      where: 'scan_result_id = ?',
      whereArgs: [scanId],
    );

    final foundData = dataRows.map((dataRow) {
      return PersonalData(
        dataType: dataRow['data_type'] as String,
        value: dataRow['value'] as String,
        filePath: dataRow['file_path'] as String,
        lineNumber: dataRow['line_number'] as int,
        confidence: dataRow['confidence'] as double,
      );
    }).toList();

    return ScanResult(
      foundData: foundData,
      totalFilesScanned: row['total_files_scanned'] as int,
      totalDataFound: row['total_data_found'] as int,
      scanDate: DateTime.parse(row['scan_date'] as String),
      scanDuration: Duration(seconds: row['scan_duration'] as int),
      scannedPath: row['scanned_path'] as String,
    );
  }

  // Deletar resultado
  Future<int> deleteScanResult(int id) async {
    final db = await database;

    // Deletar dados pessoais (CASCADE já faz isso automaticamente)
    await db.delete(
      'personal_data',
      where: 'scan_result_id = ?',
      whereArgs: [id],
    );

    // Deletar resultado
    return await db.delete(
      'scan_results',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Limpar todo o histórico
  Future<void> clearAllHistory() async {
    final db = await database;
    await db.delete('personal_data');
    await db.delete('scan_results');
  }

  // Estatísticas gerais
  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    final scansResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM scan_results');
    final totalScans = scansResult.first['count'] as int? ?? 0;

    final dataResult = await db
        .rawQuery('SELECT SUM(total_data_found) as sum FROM scan_results');
    final totalDataFound = dataResult.first['sum'] as int? ?? 0;

    final filesResult = await db
        .rawQuery('SELECT SUM(total_files_scanned) as sum FROM scan_results');
    final totalFilesScanned = filesResult.first['sum'] as int? ?? 0;

    return {
      'totalScans': totalScans,
      'totalDataFound': totalDataFound,
      'totalFilesScanned': totalFilesScanned,
    };
  }

  // Fechar banco de dados
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
