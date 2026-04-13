import 'package:flutter/foundation.dart';

import '../models/scan_schedule.dart';
import '../services/scheduler_service.dart';

/// Provider para gerenciar estado de agendamentos na UI.
class ScheduleProvider with ChangeNotifier {
  final SchedulerService _service = SchedulerService.instance;

  List<ScanSchedule> get schedules => _service.schedules;

  Future<void> initialize() async {
    await _service.load();
    _service.onScheduleUpdated = () => notifyListeners();
    notifyListeners();
  }

  Future<void> addSchedule(ScanSchedule schedule) async {
    await _service.addSchedule(schedule);
    notifyListeners();
  }

  Future<void> updateSchedule(ScanSchedule schedule) async {
    await _service.updateSchedule(schedule);
    notifyListeners();
  }

  Future<void> removeSchedule(String id) async {
    await _service.removeSchedule(id);
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    await _service.toggleEnabled(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _service.onScheduleUpdated = null;
    super.dispose();
  }
}
