import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class CorporateDeployScreen extends StatefulWidget {
  const CorporateDeployScreen({super.key});

  @override
  State<CorporateDeployScreen> createState() => _CorporateDeployScreenState();
}

class _CorporateDeployScreenState extends State<CorporateDeployScreen>
    with SingleTickerProviderStateMixin {
  static final Uri _agentCenterUri =
      Uri.parse('https://pulse.seusdados.com/central-agentes');
  static final Uri _agentDownloadUri = Uri.parse(
    'https://privacypulse.nyc3.cdn.digitaloceanspaces.com/Agent/PrivacyPulse.exe',
  );
  static const String _portalTokenPlaceholder =
      '<token_copiado_na_central_de_agentes>';
  static const String _gpoCommandTemplate =
      'PrivacyPulse.exe /silent /token=$_portalTokenPlaceholder';

  late TabController _tabController;

  static const _guides = [
    _DeployGuide(
      label: 'GPO / AD',
      icon: Icons.account_tree_outlined,
      steps: [
        '1. Na Central de Agentes, copie o token corporativo da organização.',
        '',
        '2. Copie o instalador do Agent para um compartilhamento de rede acessível:',
        r'   \\servidor\pacotes\PrivacyPulse.exe',
        '',
        '3. No Active Directory, abra o Group Policy Management.',
        '',
        '4. Use Startup Script ou Scheduled Task para executar o Agent com o token.',
        '',
        '5. Aplique o GPO à OU ou grupo desejado.',
        '',
        '6. No próximo boot/logon, a máquina consome o token e troca por JWT automaticamente.',
      ],
      command:
          r'\\servidor\pacotes\PrivacyPulse.exe /silent /token=<token_copiado_na_central_de_agentes>',
    ),
    _DeployGuide(
      label: 'PowerShell',
      icon: Icons.terminal,
      steps: [
        '1. Na Central de Agentes, copie o token corporativo da organização.',
        '',
        '2. Certifique-se que WinRM está habilitado nas máquinas alvo:',
        '   winrm quickconfig',
        '',
        '3. Execute o script abaixo na máquina de gerenciamento:',
      ],
      command: r'''\$computers = @("PC1", "PC2", "PC3")
Invoke-Command -ComputerName \$computers -ScriptBlock {
      Start-Process "\\servidor\pacotes\PrivacyPulse.exe" `
        -ArgumentList "/silent /token=<token_copiado_na_central_de_agentes>" -Wait
}''',
    ),
    _DeployGuide(
      label: 'Intune',
      icon: Icons.cloud_outlined,
      steps: [
        '1. Na Central de Agentes, copie o token corporativo da organização.',
        '',
        '2. Converta o .exe para .intunewin com a ferramenta:',
        '   Microsoft Win32 Content Prep Tool',
        '',
        '3. No Intune Portal > Apps > Windows > Add App (Win32)',
        '',
        '4. Install command:',
        '   PrivacyPulse.exe /silent /token=<token_copiado_na_central_de_agentes>',
        '',
        '5. Uninstall command:',
        '   PrivacyPulse.exe /uninstall /silent',
        '',
        '6. Detection rule: verificar chave de registro:',
        r'   HKLM\Software\SeusDados\AgentVersion',
        '',
        '7. Atribua ao grupo de dispositivos desejado.',
      ],
      command:
          'PrivacyPulse.exe /silent /token=<token_copiado_na_central_de_agentes>',
    ),
    _DeployGuide(
      label: 'SCCM / MECM',
      icon: Icons.dns_outlined,
      steps: [
        '1. Na Central de Agentes, copie o token corporativo da organização.',
        '',
        '2. Crie um Application ou Package no SCCM/MECM.',
        '',
        '3. Install Program:',
        '   PrivacyPulse.exe /silent /token=<token_copiado_na_central_de_agentes>',
        '',
        '4. Crie um Deployment para a Collection desejada.',
        '',
        '5. Defina janela de manutenção se necessário.',
        '',
        '6. Monitore o status em Monitoring > Deployments.',
      ],
      command:
          'PrivacyPulse.exe /silent /token=<token_copiado_na_central_de_agentes>',
    ),
    _DeployGuide(
      label: 'PDQ Deploy',
      icon: Icons.rocket_launch_outlined,
      steps: [
        '1. Na Central de Agentes, copie o token corporativo da organização.',
        '',
        '2. No PDQ Deploy, crie um novo Package.',
        '',
        '3. Step 1 > Install:',
        '   PrivacyPulse.exe /silent /token=<token_copiado_na_central_de_agentes>',
        '',
        '4. Selecione os targets (computadores ou grupos).',
        '',
        '5. Deploy Now ou agende para uma janela de manutenção.',
        '',
        '6. Acompanhe o status na coluna de resultados.',
      ],
      command:
          'PrivacyPulse.exe /silent /token=<token_copiado_na_central_de_agentes>',
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

  Future<void> _openAgentCenter() async {
    final ok = await launchUrl(
      _agentCenterUri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a Central de Agentes.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadAgent() async {
    final ok = await launchUrl(
      _agentDownloadUri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o download do Agent.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPortalCard(theme)),
                const SizedBox(width: 20),
                Expanded(child: _buildDistributionCard(theme)),
              ],
            ),
            const SizedBox(height: 32),
            _buildGuidesCard(theme),
            const SizedBox(height: 24),
            _buildInfoBanner(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
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
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Use o token da Central de Agentes e distribua via GPO, Intune, SCCM ou PDQ',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.gray500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPortalCard(ThemeData theme) {
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
              const Icon(Icons.public_outlined,
                  color: AppColors.primary600, size: 20),
              const SizedBox(width: 8),
              Text('Origem do Token',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'O token corporativo não é gerado neste Agent. A TI deve copiar o token na Central de Agentes do portal e usar esse valor na distribuição em massa.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.gray500, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fluxo recomendado',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.info700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Acesse a Central de Agentes no portal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.info700,
                  ),
                ),
                Text(
                  '2. Copie o token corporativo da organização.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.info700,
                  ),
                ),
                Text(
                  '3. Use esse token no comando de distribuição via GPO, Intune, SCCM ou PDQ.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.info700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openAgentCenter,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Abrir Central de Agentes'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _copy(_agentCenterUri.toString()),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar link do portal'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gray600,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(ThemeData theme) {
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
              const Icon(Icons.approval_outlined,
                  color: AppColors.primary600, size: 20),
              const SizedBox(width: 8),
              Text('Distribuição pela TI',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'O usuário final não precisa gerar token nem abrir PowerShell. A TI distribui o Agent já parametrizado com o token copiado do portal.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.gray500, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOWNLOAD DO AGENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.gray400,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _agentDownloadUri.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.gray700,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _downloadAgent,
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Baixar Agent'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy(_agentDownloadUri.toString()),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gray600,
                        side: const BorderSide(color: AppColors.gray300),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildChecklistRow(
            theme,
            Icons.file_present_outlined,
            'Baixe o Agent genérico no link acima e publique esse arquivo em um compartilhamento interno ou ferramenta de distribuição.',
          ),
          const SizedBox(height: 8),
          _buildChecklistRow(
            theme,
            Icons.vpn_key_outlined,
            'Copie o token corporativo na Central de Agentes.',
          ),
          const SizedBox(height: 8),
          _buildChecklistRow(
            theme,
            Icons.account_tree_outlined,
            'Use esse token no comando da ferramenta de distribuição escolhida.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INSTALAÇÃO SILENCIOSA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.gray400,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        _gpoCommandTemplate,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      color: AppColors.gray400,
                      tooltip: 'Copiar comando modelo',
                      onPressed: () => _copy(_gpoCommandTemplate),
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

  Widget _buildChecklistRow(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.gray400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.gray700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuidesCard(ThemeData theme) {
    return Container(
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
              children: _guides.map((g) => _buildGuideContent(g)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideContent(_DeployGuide guide) {
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
          const Text(
            'COMANDO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.gray400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
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

  Widget _buildInfoBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'O token corporativo vem da Central de Agentes no portal, não desta tela. '
              'A TI usa esse token no comando de distribuição e o Agent troca esse valor por JWT automaticamente no primeiro bootstrap.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF1D4ED8),
                height: 1.5,
              ),
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
