import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// Serviço singleton para notificações nativas do Windows (toast).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    try {
      await localNotifier.setup(
        appName: 'PrivacyPulse',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar notificações: $e');
    }
  }

  /// Exibe uma notificação nativa (toast no Windows).
  Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    try {
      final notification = LocalNotification(
        title: title,
        body: body,
      );
      await notification.show();
    } catch (e) {
      debugPrint('⚠️ Erro ao exibir notificação: $e');
    }
  }
}
