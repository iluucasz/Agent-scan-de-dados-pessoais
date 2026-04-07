import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings,
                      size: 32,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurações',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Personalize suas preferências e configurações do aplicativo',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Restaurar Padrões'),
                    onPressed: () =>
                        _showResetDialog(context, settingsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Informações do usuário
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.12),
                      cs.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authProvider.user?.name ?? 'Usuário',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authProvider.user?.email ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.business, size: 16, color: cs.primary),
                              const SizedBox(width: 6),
                              Text(
                                authProvider.organization?.name ??
                                    'Organização',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Aparência
              _buildSectionHeader('Aparência', Icons.palette),
              _buildSettingCard(
                child: _buildSwitchTile(
                  icon: Icons.dark_mode,
                  iconColor: AppColors.info600,
                  title: 'Modo Escuro',
                  subtitle: 'Tema escuro para a interface',
                  // TODO(dark-mode): Feature paused for now.
                  // value: settings.darkMode,
                  // onChanged: settingsProvider.setDarkMode,
                  value: false,
                  onChanged: null,
                ),
              ),
              const SizedBox(height: 24),

              // Varredura
              _buildSectionHeader('Configurações de Escaneamento', Icons.radar),
              _buildSettingCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.folder_open,
                            size: 24, color: AppColors.primary600),
                      ),
                      title: Text(
                        'Caminho Padrão',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        settings.defaultScanPath.isEmpty
                            ? 'Nenhum caminho definido'
                            : settings.defaultScanPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(Icons.edit, color: cs.primary),
                      onTap: () =>
                          _selectDefaultPath(context, settingsProvider),
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      icon: Icons.account_tree,
                      iconColor: AppColors.success600,
                      title: 'Incluir Subpastas',
                      subtitle: 'Incluir subpastas por padrão',
                      value: settings.includeSubfoldersByDefault,
                      onChanged: settingsProvider.setIncludeSubfoldersByDefault,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description,
                            size: 24, color: AppColors.primary600),
                      ),
                      title: Text(
                        'Tamanho Máximo do Arquivo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${settings.defaultMaxFileSize} MB',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: SizedBox(
                        width: 120,
                        child: DropdownButton<int>(
                          value: [10, 50, 100, 200]
                                  .contains(settings.defaultMaxFileSize)
                              ? settings.defaultMaxFileSize
                              : 100,
                          isExpanded: true,
                          items: const [10, 50, 100, 200]
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value MB'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              settingsProvider.setDefaultMaxFileSize(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Histórico e Dados
              _buildSectionHeader('Histórico e Dados', Icons.history),
              _buildSettingCard(
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.save,
                      iconColor: AppColors.success600,
                      title: 'Salvar Resultados Automaticamente',
                      subtitle: 'Salvar resultados no histórico',
                      value: settings.autoSaveResults,
                      onChanged: settingsProvider.setAutoSaveResults,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.history,
                            size: 24, color: AppColors.info600),
                      ),
                      title: Text(
                        'Máximo de Itens no Histórico',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${settings.maxHistoryItems} varreduras',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: SizedBox(
                        width: 100,
                        child: DropdownButton<int>(
                          value: settings.maxHistoryItems,
                          isExpanded: true,
                          items: [10, 25, 50, 100, 200].map((value) {
                            return DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              settingsProvider.setMaxHistoryItems(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notificações
              _buildSectionHeader('Notificações', Icons.notifications),
              _buildSettingCard(
                child: _buildSwitchTile(
                  icon: Icons.notifications,
                  iconColor: AppColors.warning600,
                  title: 'Ativar Notificações',
                  subtitle: 'Receber notificações ao concluir varreduras',
                  value: settings.notificationsEnabled,
                  onChanged: (value) {
                    settingsProvider.setNotificationsEnabled(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Notificações serão implementadas em breve'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Sobre
              _buildSectionHeader('Sobre o Aplicativo', Icons.info),
              _buildSettingCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info,
                            size: 24, color: AppColors.info600),
                      ),
                      title: Text(
                        'Versão',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '1.0.0',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description,
                            size: 24, color: AppColors.success600),
                      ),
                      title: Text(
                        'Licença',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'MIT License',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.code,
                            size: 24, color: AppColors.primary600),
                      ),
                      title: Text(
                        'Desenvolvido com Flutter',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Migrado de React/Electron',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 24, color: iconColor),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: cs.primary,
      ),
    );
  }

  Future<void> _selectDefaultPath(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        settingsProvider.setDefaultScanPath(path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Caminho padrão definido: $path'),
              backgroundColor: AppColors.success600,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seleção de diretório não disponível na web. Use a versão desktop para esta funcionalidade.',
              style: TextStyle(fontSize: 13),
            ),
            backgroundColor: AppColors.warning600,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showResetDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Configurações Padrão'),
        content: const Text(
          'Tem certeza que deseja restaurar todas as configurações para os valores padrão?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              settingsProvider.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configurações restauradas'),
                  backgroundColor: AppColors.success600,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary600,
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
}
