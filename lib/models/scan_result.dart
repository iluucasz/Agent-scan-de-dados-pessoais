import 'personal_data.dart';

class ScanResult {
  final List<PersonalData> foundData;
  final int totalFilesScanned;
  final int totalDataFound;
  final DateTime scanDate;
  final Duration scanDuration;
  final String scannedPath;

  ScanResult({
    required this.foundData,
    required this.totalFilesScanned,
    required this.totalDataFound,
    required this.scanDate,
    required this.scanDuration,
    required this.scannedPath,
  });

  Map<String, int> getDataTypeSummary() {
    final summary = <String, int>{};
    for (var data in foundData) {
      summary[data.dataType] = (summary[data.dataType] ?? 0) + 1;
    }
    return summary;
  }
}
