import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Gerencia o ícone na bandeja do sistema (system tray) e intercepta
/// o fechamento da janela para minimizar em vez de encerrar.
class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _initialized = false;

  /// Inicializa o system tray e o gerenciador de janela.
  /// Deve ser chamado depois de `WidgetsFlutterBinding.ensureInitialized()`.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // ── Window Manager ────────────────────────────────────────────
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      minimumSize: Size(900, 600),
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(this);
    // Impede o encerramento imediato no botão X.
    await windowManager.setPreventClose(true);

    // ── Tray Icon ─────────────────────────────────────────────────
    final iconPath = Platform.resolvedExecutable
        .replaceAll(RegExp(r'[^\\\/]+$'), '')
        .replaceAll(r'\', '/')
        + 'data/flutter_assets/assets/icons/pv-pulse.png';

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('SeusDADOS');

    final menu = Menu(items: [
      MenuItem(key: 'show', label: 'Abrir SeusDADOS'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Sair'),
    ]);

    await trayManager.setContextMenu(menu);
    trayManager.addListener(this);
  }

  /// Libera listeners (chamar em dispose do app, se necessário).
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  // ── TrayListener ──────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    // Clique simples no ícone restaura a janela.
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'exit':
        // Sair de verdade.
        windowManager.setPreventClose(false);
        windowManager.close();
        break;
    }
  }

  // ── WindowListener ────────────────────────────────────────────

  @override
  void onWindowClose() {
    // Minimiza para a bandeja em vez de fechar.
    windowManager.hide();
  }
}
