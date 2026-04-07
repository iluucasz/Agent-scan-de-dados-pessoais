class AppSettings {
  final bool darkMode;
  final bool autoSaveResults;
  final bool notificationsEnabled;
  final int maxHistoryItems;
  final String defaultScanPath;
  final bool includeSubfoldersByDefault;
  final int defaultMaxFileSize; // em MB

  AppSettings({
    this.darkMode = false,
    this.autoSaveResults = true,
    this.notificationsEnabled = true,
    this.maxHistoryItems = 50,
    this.defaultScanPath = '',
    this.includeSubfoldersByDefault = true,
    this.defaultMaxFileSize = 100,
  });

  AppSettings copyWith({
    bool? darkMode,
    bool? autoSaveResults,
    bool? notificationsEnabled,
    int? maxHistoryItems,
    String? defaultScanPath,
    bool? includeSubfoldersByDefault,
    int? defaultMaxFileSize,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      autoSaveResults: autoSaveResults ?? this.autoSaveResults,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      maxHistoryItems: maxHistoryItems ?? this.maxHistoryItems,
      defaultScanPath: defaultScanPath ?? this.defaultScanPath,
      includeSubfoldersByDefault:
          includeSubfoldersByDefault ?? this.includeSubfoldersByDefault,
      defaultMaxFileSize: defaultMaxFileSize ?? this.defaultMaxFileSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'darkMode': darkMode,
      'autoSaveResults': autoSaveResults,
      'notificationsEnabled': notificationsEnabled,
      'maxHistoryItems': maxHistoryItems,
      'defaultScanPath': defaultScanPath,
      'includeSubfoldersByDefault': includeSubfoldersByDefault,
      'defaultMaxFileSize': defaultMaxFileSize,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      darkMode: json['darkMode'] ?? false,
      autoSaveResults: json['autoSaveResults'] ?? true,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      maxHistoryItems: json['maxHistoryItems'] ?? 50,
      defaultScanPath: json['defaultScanPath'] ?? '',
      includeSubfoldersByDefault: json['includeSubfoldersByDefault'] ?? true,
      defaultMaxFileSize: json['defaultMaxFileSize'] ?? 100,
    );
  }
}
