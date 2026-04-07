import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/scan_provider.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'scan_config_screen.dart';
import 'scan_history_screen.dart';
import 'settings_screen.dart';
import 'patterns_list_screen.dart';

class DashboardLayout extends StatefulWidget {
  final int initialIndex;

  const DashboardLayout({super.key, this.initialIndex = 0});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  late int _selectedIndex;
  bool _isSidebarExpanded = true;

  // Mantém as telas vivas para navegação instantânea via sidebar.
  // Definido aqui (sem late) para evitar problemas em hot reload.
  final List<Widget> _screens = [
    const HomeScreen(),
    const ScanConfigScreen(),
    const ScanHistoryScreen(),
    const PatternsListScreen(),
    const SettingsScreen(),
  ];

  static const int _maxBadgeCount = 99;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/',
    ),
    _NavItem(
      icon: Icons.radar,
      label: 'Escaneamento',
      route: '/scan-config',
    ),
    _NavItem(
      icon: Icons.history,
      label: 'Histórico',
      route: '/scan-history',
    ),
    _NavItem(
      icon: Icons.list_alt,
      label: 'Padrões de Dados',
      route: '/patterns',
    ),
    _NavItem(
      icon: Icons.settings,
      label: 'Configurações',
      route: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 1200;
    final bool isMediumScreen = screenWidth > 800;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarExpanded
                ? (isLargeScreen ? 260 : 220)
                : (isMediumScreen ? 72 : 0),
            child: _isSidebarExpanded || isMediumScreen
                ? _buildSidebar(authProvider)
                : null,
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(authProvider, screenWidth),

                // Content Area
                Expanded(
                  child: Container(
                    color: cs.surfaceContainerHighest,
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _screens,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(AuthProvider authProvider) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Brand
          Container(
            height: 70,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/icons/pv-pulse.png',
                    height: _isSidebarExpanded ? 56 : 44,
                    width: _isSidebarExpanded ? null : 44,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isSidebarExpanded ? 12 : 8,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedIndex = index);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: _isSidebarExpanded ? 20 : 18,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.72),
                            ),
                            if (_isSidebarExpanded) ...[
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? cs.primary
                                        : cs.onSurface.withValues(alpha: 0.86),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // User Info
          if (_isSidebarExpanded)
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary100,
                    radius: 16,
                    child: Text(
                      authProvider.user?.name[0].toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: AppColors.primary700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          authProvider.user?.name ?? 'Usuário',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray900,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authProvider.organization?.name ?? 'Organização',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.gray500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AuthProvider authProvider, double screenWidth) {
    final bool isSmallScreen = screenWidth < 800;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // Menu Toggle
            IconButton(
              icon: Icon(
                _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                color: cs.onSurface.withValues(alpha: 0.86),
              ),
              onPressed: () {
                setState(() => _isSidebarExpanded = !_isSidebarExpanded);
              },
              tooltip: _isSidebarExpanded ? 'Recolher Menu' : 'Expandir Menu',
            ),

            const SizedBox(width: 16),

            // Page Title
            if (!isSmallScreen) ...[
              Text(
                _navItems[_selectedIndex].label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
            ],

            const Spacer(),

            // Actions
            if (!isSmallScreen) ...[
              // Quick Action Button
              if (_selectedIndex == 0)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _selectedIndex = 1);
                  },
                  icon: const Icon(Icons.radar, size: 20),
                  label: const Text('Novo Escaneamento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

              const SizedBox(width: 16),
            ],

            // Notifications
            Consumer<ScanProvider>(
              builder: (context, scanProvider, _) {
                final badgeCount = _getNotificationBadgeCount(scanProvider);

                return PopupMenuButton<void>(
                  tooltip: null,
                  offset: const Offset(0, 46),
                  itemBuilder: (context) => _buildNotificationMenuItems(
                    scanProvider: scanProvider,
                    isSmallScreen: isSmallScreen,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.gray600,
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: _NotificationBadge(count: badgeCount),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 8),

            // User Menu
            PopupMenuButton<String>(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary100,
                      radius: 16,
                      child: Text(
                        authProvider.user?.name[0].toUpperCase() ?? 'U',
                        style: const TextStyle(
                          color: AppColors.primary700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!isSmallScreen) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.gray600,
                      ),
                    ],
                  ],
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 12),
                      Text(authProvider.user?.name ?? 'Usuário'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 18),
                      SizedBox(width: 12),
                      Text('Configurações'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: AppColors.danger600),
                      SizedBox(width: 12),
                      Text(
                        'Sair',
                        style: TextStyle(color: AppColors.danger600),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'settings') {
                  setState(() => _selectedIndex = 4);
                } else if (value == 'logout') {
                  authProvider.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  int _getNotificationBadgeCount(ScanProvider scanProvider) {
    if (scanProvider.status == ScanStatus.running) {
      final found = scanProvider.totalDataFound;
      if (found <= 0) {
        return 1;
      }
      return found > _maxBadgeCount ? _maxBadgeCount : found;
    }

    if (scanProvider.status == ScanStatus.failed) {
      return 1;
    }

    return 0;
  }

  List<PopupMenuEntry<void>> _buildNotificationMenuItems({
    required ScanProvider scanProvider,
    required bool isSmallScreen,
  }) {
    final items = <PopupMenuEntry<void>>[];

    items.add(
      PopupMenuItem<void>(
        enabled: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: const Text(
            'Notificações',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gray900,
            ),
          ),
        ),
      ),
    );

    items.add(const PopupMenuDivider());

    final content = _buildNotificationContent(
      scanProvider: scanProvider,
      isSmallScreen: isSmallScreen,
    );

    if (content.isEmpty) {
      items.add(
        const PopupMenuItem<void>(
          enabled: false,
          child: SizedBox(
            width: 340,
            child: Text(
              'Sem notificações no momento',
              style: TextStyle(color: AppColors.gray600),
            ),
          ),
        ),
      );
      return items;
    }

    items.addAll(
      content
          .map(
            (row) => PopupMenuItem<void>(
              enabled: false,
              child: SizedBox(
                width: 340,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(row.icon, size: 18, color: row.iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        row.text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray800,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );

    return items;
  }

  List<_NotificationRow> _buildNotificationContent({
    required ScanProvider scanProvider,
    required bool isSmallScreen,
  }) {
    if (scanProvider.status == ScanStatus.running) {
      final total = scanProvider.totalFiles;
      final scanned = scanProvider.filesScanned;
      final progressText = total > 0
          ? 'Escaneados: $scanned/$total arquivos'
          : 'Escaneados: $scanned arquivos';

      final phase = _formatScanPhase(scanProvider.currentPhase);

      final rows = <_NotificationRow>[
        const _NotificationRow(
          icon: Icons.radar,
          iconColor: AppColors.primary600,
          text: 'Escaneamento em andamento',
        ),
        _NotificationRow(
          icon: Icons.folder_open,
          iconColor: AppColors.gray600,
          text: progressText,
        ),
        _NotificationRow(
          icon: Icons.find_in_page,
          iconColor: AppColors.gray600,
          text: 'Dados encontrados: ${scanProvider.totalDataFound}',
        ),
        _NotificationRow(
          icon: Icons.timeline,
          iconColor: AppColors.gray600,
          text: 'Fase: $phase',
        ),
      ];

      if (!isSmallScreen && scanProvider.currentFileName.trim().isNotEmpty) {
        rows.add(
          _NotificationRow(
            icon: Icons.insert_drive_file,
            iconColor: AppColors.gray600,
            text: 'Arquivo: ${scanProvider.currentFileName}',
          ),
        );
      }

      return rows;
    }

    if (scanProvider.status == ScanStatus.failed) {
      return <_NotificationRow>[
        _NotificationRow(
          icon: Icons.error_outline,
          iconColor: AppColors.danger600,
          text: scanProvider.errorMessage?.trim().isNotEmpty == true
              ? scanProvider.errorMessage!
              : 'Ocorreu um erro durante o escaneamento',
        ),
      ];
    }

    if (scanProvider.status == ScanStatus.completed &&
        scanProvider.lastResult != null) {
      final result = scanProvider.lastResult!;

      return <_NotificationRow>[
        _NotificationRow(
          icon: Icons.check_circle_outline,
          iconColor: AppColors.success600,
          text:
              'Último scan concluído: ${result.totalFilesScanned} arquivos, ${result.totalDataFound} itens encontrados',
        ),
      ];
    }

    return const <_NotificationRow>[];
  }

  String _formatScanPhase(ScanPhaseStatus phase) {
    switch (phase) {
      case ScanPhaseStatus.idle:
        return 'Aguardando';
      case ScanPhaseStatus.creatingConfig:
        return 'Criando configuração';
      case ScanPhaseStatus.uploadingFiles:
        return 'Enviando arquivos';
      case ScanPhaseStatus.scanningLocally:
        return 'Escaneando localmente';
      case ScanPhaseStatus.sendingResults:
        return 'Enviando resultados';
      case ScanPhaseStatus.completedWithApi:
        return 'Concluído (API)';
      case ScanPhaseStatus.completedLocalOnly:
        return 'Concluído (local)';
      case ScanPhaseStatus.failed:
        return 'Falhou';
    }
  }
}

class _NotificationRow {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _NotificationRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });
}

class _NotificationBadge extends StatelessWidget {
  final int count;

  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();
    final isDot = count == 1;

    if (isDot) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.danger600,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.danger600,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
