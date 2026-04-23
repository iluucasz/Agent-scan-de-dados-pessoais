import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class CorporateDeployScreen extends StatefulWidget {
  const CorporateDeployScreen({super.key});

  @override
  State<CorporateDeployScreen> createState() => _CorporateDeployScreenState();
}

class _CorporateDeployScreenState extends State<CorporateDeployScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _orgToken = 'ORG-XXXX-YYYY-ZZZZ'; // placeholder

  static const _guides = [
    _DeployGuide(
      label: 'GPO / AD',
      icon: Icons.account_tree_outlined,
      steps: [
        '1. Copie o instalador para um compartilhamento de rede acessível:',
        r'   \\servidor\pacotes\SeusDados.msi',
        '',
        '2. No Active Directory, crie um GPO em:',
        '   Configuração do Computador > Políticas >',
        '   Configurações de Software > Instalação de Software',
        '',
        '3. Aponte para o caminho UNC do .msi',
        '',
        '4. Aplique ao grupo/OU desejado',
        '',
        '5. Os endpoints instalam automaticamente no próximo logon',
      ],
      command:
          r'msiexec /i \\servidor\pacotes\SeusDados.msi /qn TOKEN=<seu_token>',
    ),
    _DeployGuide(
      label: 'PowerShell',
      icon: Icons.terminal,
      steps: [
        '1. Certifique-se que WinRM está habilitado nas máquinas alvo',
        '',
        '2. Execute o script abaixo na máquina de gerenciamento:',
      ],
      command: r'''\$computers = @("PC1", "PC2", "PC3")
Invoke-Command -ComputerName \$computers -ScriptBlock {
    Start-Process "\\servidor\pacotes\SeusDados.exe" `
        -ArgumentList "/silent /token=<seu_token>" -Wait
}''',
    ),
    _DeployGuide(
      label: 'Intune',
      icon: Icons.cloud_outlined,
      steps: [
        '1. Converta o .exe para .intunewin com a Microsoft Win32 Content Prep Tool',
        '',
        '2. No Intune Portal > Apps > Windows > Add App (Win32)',
        '',
        '3. Install command:',
        '   SeusDados.exe /silent /token=<seu_token>',
        '',
        '4. Uninstall command:',
        '   SeusDados.exe /uninstall /silent',
        '',
        '5. Detection rule: verificar chave de registro',
        r'   HKLM\Software\SeusDados\AgentVersion',
        '',
        '6. Atribua ao grupo de dispositivos desejado',
      ],
      command: 'SeusDados.exe /silent /token=<seu_token>',
    ),
    _DeployGuide(
      label: 'SCCM / MECM',
      icon: Icons.dns_outlined,
      steps: [
        '1. Crie um Application ou Package no SCCM',
        '',
        '2. Install Program:',
        '   SeusDados.exe /silent /token=<seu_token>',
        '',
        '3. Crie um Deployment para a Collection desejada',
        '',
        '4. Defina janela de manutenção se necessário',
      ],
      command: 'SeusDados.exe /silent /token=<seu_token>',
    ),
    _DeployGuide(
      label: 'PDQ Deploy',
      icon: Icons.rocket_launch_outlined,
      steps: [
        '1. Crie um novo Package no PDQ Deploy',
        '',
        '2. Step 1 > Install:',
        '   SeusDados.exe /silent /token=<seu_token>',
        '',
        '3. Selecione os targets (computadores ou grupos)',
        '',
        '4. Clique em Deploy Now ou agende para uma janela de manutenção',
      ],
      command: 'SeusDados.exe /silent /token=<seu_token>',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _guides.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado para a área de transferência'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.corporate_fare,
                    size: 28,
                    color: AppColors.primary600,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deploy Corporativo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Distribua o Agent em massa sem interação do usuário',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Cards superiores ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Token de provisionamento
                Expanded(child: _buildTokenCard(cs, theme)),
                const SizedBox(width: 20),
                // Instalador
                Expanded(child: _buildInstallerCard(cs, theme)),
              ],
            ),

            const SizedBox(height: 32),

            // ── Guias de deploy ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined,
                            color: AppColors.primary600, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Guias de Deploy',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.primary600,
                    unselectedLabelColor: AppColors.gray500,
                    indicatorColor: AppColors.primary600,
                    indicatorSize: TabBarIndicatorSize.label,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: _guides
                        .map((g) => Tab(
                              child: Row(
                                children: [
                                  Icon(g.icon, size: 16),
                                  const SizedBox(width: 6),
                                  Text(g.label),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 380,
                    child: TabBarView(
                      controller: _tabController,
                      children: _guides
                          .map((g) => _buildGuideContent(g, cs))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Aviso informativo ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O token de provisionamento autentica a organização, não o usuário individual. '
                      'O Agent instalado via GPO usa esse token para se registrar automaticamente '
                      'sem que o colaborador precise fazer login.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF1D4ED8),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(ColorScheme cs, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_outlined,
                  color: AppColors.primary600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Token de Provisionamento',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Use este token no instalador para autenticar a organização automaticamente.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.gray500, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _orgToken,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  color: AppColors.gray500,
                  tooltip: 'Copiar token',
                  onPressed: () => _copy(_orgToken),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Funcionalidade disponível em breve')),
              );
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Gerar novo token'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gray600,
              side: const BorderSide(color: AppColors.gray300),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallerCard(ColorScheme cs, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_outlined,
                  color: AppColors.primary600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Instalador',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pacote para distribuição silenciosa via GPO, Intune, SCCM ou PDQ.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.gray500, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildInstallerRow(theme, Icons.file_present_outlined, 'SeusDados.exe',
              'Instalador Windows (silent)'),
          const SizedBox(height: 8),
          _buildInstallerRow(theme, Icons.inventory_2_outlined, 'SeusDados.msi',
              'Pacote MSI para GPO/SCCM'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instalação silenciosa',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SeusDados.exe /silent /token=<token>',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      color: AppColors.gray400,
                      tooltip: 'Copiar comando',
                      onPressed: () =>
                          _copy('SeusDados.exe /silent /token=$_orgToken'),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallerRow(
      ThemeData theme, IconData icon, String name, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.gray400),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600, color: AppColors.gray700)),
              Text(subtitle,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.gray400)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Download disponível em breve')),
            );
          },
          icon: const Icon(Icons.download, size: 14),
          label: const Text('Baixar'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary600,
            textStyle: const TextStyle(fontSize: 12),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildGuideContent(_DeployGuide guide, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...guide.steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                step,
                style: TextStyle(
                  fontSize: 13,
                  color: step.startsWith('   ')
                      ? AppColors.gray500
                      : AppColors.gray700,
                  fontFamily: step.startsWith('   ') ? 'monospace' : null,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Comando',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.gray400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    guide.command,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFCDD6F4),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  color: const Color(0xFF6C7086),
                  tooltip: 'Copiar comando',
                  onPressed: () => _copy(guide.command),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeployGuide {
  final String label;
  final IconData icon;
  final List<String> steps;
  final String command;

  const _DeployGuide({
    required this.label,
    required this.icon,
    required this.steps,
    required this.command,
  });
}
