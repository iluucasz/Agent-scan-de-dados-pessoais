import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_config.dart';
import '../models/scan_schedule.dart';
import '../services/file_scanner_service_impl.dart';
import '../services/database_service.dart';

/// Serviço singleton que gerencia o agendamento de scans em background.
///
/// Usa [Timer.periodic] de 1 minuto para verificar quais agendamentos
/// devem ser executados. Os agendamentos são persistidos em SharedPreferences.
class SchedulerService {
  SchedulerService._();
  static final SchedulerService instance = SchedulerService._();

  static const String _storageKey = 'seusdados_schedules';

  final List<ScanSchedule> _schedules = [];
  Timer? _ticker;
  bool _running = false;

  /// Callback opcional para notificar a UI quando um agendamento é atualizado.
  VoidCallback? onScheduleUpdated;

  /// Callback quando um scan agendado é concluído com sucesso.
  VoidCallback? onScanCompleted;

  List<ScanSchedule> get schedules => List.unmodifiable(_schedules);

  // ── Persistência ──────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _schedules.clear();
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        _schedules.add(ScanSchedule.fromJson(item as Map<String, dynamic>));
      }
    }
    _ensureTicker();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _schedules.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(json));
  }

  // ── CRUD ──────────────────────────────────────────────────────

  Future<void> addSchedule(ScanSchedule schedule) async {
    final withNext = schedule.copyWith(
      nextRunAt: schedule.computeNextRun(DateTime.now()),
    );
    _schedules.add(withNext);
    await _persist();
    _ensureTicker();
    onScheduleUpdated?.call();
  }

  Future<void> updateSchedule(ScanSchedule schedule) async {
    final idx = _schedules.indexWhere((s) => s.id == schedule.id);
    if (idx == -1) return;
    final withNext = schedule.copyWith(
      nextRunAt:
          schedule.enabled ? schedule.computeNextRun(DateTime.now()) : null,
    );
    _schedules[idx] = withNext;
    await _persist();
    onScheduleUpdated?.call();
  }

  Future<void> removeSchedule(String id) async {
    _schedules.removeWhere((s) => s.id == id);
    await _persist();
    onScheduleUpdated?.call();
  }

  Future<void> toggleEnabled(String id) async {
    final idx = _schedules.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final s = _schedules[idx];
    final toggled = s.copyWith(
      enabled: !s.enabled,
      nextRunAt: !s.enabled ? s.computeNextRun(DateTime.now()) : null,
    );
    _schedules[idx] = toggled;
    await _persist();
    onScheduleUpdated?.call();
  }

  // ── Timer ─────────────────────────────────────────────────────

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _tick() async {
    if (_running) return; // evita execução paralela
    final now = DateTime.now();

    for (var i = 0; i < _schedules.length; i++) {
      final s = _schedules[i];
      if (!s.enabled) continue;
      if (s.nextRunAt == null) continue;
      if (now.isBefore(s.nextRunAt!)) continue;

      // Hora de executar
      _running = true;
      try {
        await _executeScan(s);
        _schedules[i] = s.copyWith(
          lastRunAt: DateTime.now(),
          nextRunAt: s.computeNextRun(DateTime.now()),
        );
        await _persist();
        onScheduleUpdated?.call();
      } catch (e) {
        debugPrint('❌ Erro no scan agendado "${s.name}": $e');
      } finally {
        _running = false;
      }
    }
  }

  Future<void> _executeScan(ScanSchedule schedule) async {
    debugPrint('⏰ Executando scan agendado: ${schedule.name}');

    final config = ScanConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scanName: '${schedule.name} (agendado)',
      path: schedule.path,
      selectedPatterns: schedule.selectedPatterns,
      includeSubfolders: schedule.includeSubfolders,
      maxFileSize: schedule.maxFileSizeMb * 1024 * 1024,
      createdAt: DateTime.now(),
    );

    final scanner = FileScannerServiceImpl();
    final result = await scanner.scan(
      config: config,
      onProgress: (_, __) {},
      onStatus: (_) {},
    );

    // Salva no banco local
    await DatabaseService.instance.saveScanResult(result);
    debugPrint(
        '✅ Scan agendado "${schedule.name}" concluído: ${result.totalDataFound} itens');
    onScanCompleted?.call();
  }
}
