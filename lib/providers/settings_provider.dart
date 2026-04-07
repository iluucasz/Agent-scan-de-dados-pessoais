import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';

class SettingsProvider with ChangeNotifier {
  AppSettings _settings = AppSettings();
  static const String _settingsKey = 'seusdados_settings';

  AppSettings get settings => _settings;

  // Inicializar com configurações salvas
  Future<void> initialize() async {
    await _loadSettings();
    notifyListeners();
  }

  // Carregar configurações do shared_preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(settingsMap);
        debugPrint('✅ Configurações carregadas: ${_settings.toJson()}');
      } else {
        debugPrint('ℹ️ Nenhuma configuração salva encontrada, usando padrões');
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar configurações: $e');
      _settings = AppSettings(); // Usar configurações padrão em caso de erro
    }
  }

  // Atualizar modo escuro
  void setDarkMode(bool value) {
    _settings = _settings.copyWith(darkMode: value);
    _saveSettings();
    notifyListeners();
  }

  // Atualizar auto-save
  void setAutoSaveResults(bool value) {
    _settings = _settings.copyWith(autoSaveResults: value);
    _saveSettings();
    notifyListeners();
  }

  // Atualizar notificações
  void setNotificationsEnabled(bool value) {
    _settings = _settings.copyWith(notificationsEnabled: value);
    _saveSettings();
    notifyListeners();
  }

  // Atualizar máximo de itens no histórico
  void setMaxHistoryItems(int value) {
    _settings = _settings.copyWith(maxHistoryItems: value);
    _saveSettings();
    notifyListeners();
  }

  // Atualizar caminho padrão
  void setDefaultScanPath(String value) {
    _settings = _settings.copyWith(defaultScanPath: value);
    _saveSettings();
    notifyListeners();
  }

  // Atualizar incluir subpastas por padrão
  void setIncludeSubfoldersByDefault(bool value) {
    _settings = _settings.copyWith(includeSubfoldersByDefault: value);
    _saveSettings();
    notifyListeners();
  }

  // Atualizar tamanho máximo padrão
  void setDefaultMaxFileSize(int value) {
    _settings = _settings.copyWith(defaultMaxFileSize: value);
    _saveSettings();
    notifyListeners();
  }

  // Resetar para padrões
  void resetToDefaults() {
    _settings = AppSettings();
    _saveSettings();
    notifyListeners();
  }

  // Salvar configurações
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      debugPrint('✅ Configurações salvas: ${_settings.toJson()}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar configurações: $e');
    }
  }
}
