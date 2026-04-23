import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class CorporateDeployScreen extends StatefulWidget {
  const CorporateDeployScreen({super.key});

  @override
  State<CorporateDeployScreen> createState() => _CorporateDeployScreenState();
}

class _CorporateDeployScreenState extends State<CorporateDeployScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _tokenVisible = false;

  static const _guides = [
    _DeployGuide(
      label: 'GPO / AD',
      icon: Icons.account_tree_outlined,
      steps: [
        '1. Copie o instalador para um compartilhamento de rede acessível:',
        r'   \\servidor\pacotes\SeusDados.msi',
        '',
        '2. No Active Directory, abra o Group Policy Management',
        '',
        '3. Crie um novo GPO ou edite um existente:',
        '   Configuração do Computador > Políticas >',
        '   Configurações de Software > Instalação de Software',
        '',
        '4. Aponte para o caminho UNC do .msi',
        '',
        '5. Aplique ao grupo/OU desejado',
        '',
        '6. Os endpoints instalam automaticamente no próximo logon/reboot',
      ],
      command:
          r'msiexec /i \\servidor\pacotes\SeusDados.msi /qn TOKEN=<seu_token>',
    ),
    _DeployGuide(
      label: 'PowerShell',
      icon: Icons.terminal,
      steps: [
        '1. Certifique-se que WinRM está habilitado nas máquinas alvo:',
        '   winrm quickconfig',
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
        '1. Converta o .exe para .intunewin com a ferramenta:',
        '   Microsoft Win32 Content Prep Tool',
        '',
        '2. No Intune Portal > Apps > Windows > Add App (Win32)',
        '',
        '3. Install command:',
        '   SeusDados.exe /silent /token=<seu_token>',
        '',
        '4. Uninstall command:',
        '   SeusDados.exe /uninstall /silent',
        '',
        '5. Detection rule: verificar chave de registro:',
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
        '1. Crie um Application ou Package no SCCM/MECM',
        '',
        '2. Install Program:',
        '   SeusDados.exe /silent /token=<seu_token>',
        '',
        '3. Crie um Deployment para a Collection desejada',
        '',
        '4. Defina janela de manutenção se necessário',
        '',
        '5. Monitore o status em Monitoring > Deployments',
      ],
      command: 'SeusDados.exe /silent /token=<seu_token>',
    ),
    _DeployGuide(
      label: 'PDQ Deploy',
      icon: Icons.rocket_launch_outlined,
      steps: [
        '1. No PDQ Deploy, crie um novo Package',
        '',
        '2. Step 1 > Install:',
        '   SeusDados.exe /silent /token=<seu_token>',
        '',
        '3. Selecione os targets (computadores ou grupos)',
        '',
        '4. Deploy Now ou agende para uma janela de manutenção',
        '',
        '5. Acompanhe o status na coluna de resultados',
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
    final authToken =
        context.watch<AuthProvider>().token ?? '';

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
                Expanded(child: _buildTokenCard(theme, authToken)),
                const SizedBox(width: 20),
                Expanded(child: _buildInstallerCard(theme, authToken)),
              ],
            ),
            const SizedBox(height: 32),
            _buildGuidesCard(theme, authToken),
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
              'Distribua o Agent em massa via GPO, Intune, SCCM ou PDQ',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.gray500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTokenCard(ThemeData theme, String authToken) {
    final displayToken =
        _tokenVisible ? authToken : '•' * authToken.length;

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
              Text('Token de Provisionamento',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Use este token no instalador para autenticar a organização automaticamente, sem login do colaborador.',
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
                    displayToken,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _tokenVisible
                          ? AppColors.primary700
                          : AppColors.gray400,
                      letterSpacing: _tokenVisible ? 1.0 : 0,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _tokenVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  color: AppColors.gray400,
                  tooltip: _tokenVisible ? 'Ocultar token' : 'Mostrar token',
                  onPressed: () =>
                      setState(() => _tokenVisible = !_tokenVisible),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  color: AppColors.gray400,
                  tooltip: 'Copiar token',
                  onPressed: () => _copy(authToken),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Disponível em breve'),
                  duration: Duration(seconds: 2)),
            ),
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

  Widget _buildInstallerCard(ThemeData theme, String authToken) {
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
              Text('Instalador',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pacote para distribuição silenciosa. Compatível com GPO, Intune, SCCM e PDQ.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.gray500, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildFileRow(theme, Icons.file_present_outlined, 'SeusDados.exe',
              'Instalador Windows — suporte a /silent'),
          const SizedBox(height: 8),
          _buildFileRow(theme, Icons.inventory_2_outlined, 'SeusDados.msi',
              'Pacote MSI — ideal para GPO e SCCM'),
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
                      tooltip: 'Copiar',
                      onPressed: () => _copy(
                          'SeusDados.exe /silent /token=$authToken'),
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

  Widget _buildFileRow(
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray700)),
              Text(subtitle,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.gray400)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Download disponível em breve'),
                duration: Duration(seconds: 2)),
          ),
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

  Widget _buildGuidesCard(ThemeData theme, String authToken) {
    final guides = _guides
        .map((g) => _DeployGuide(
              label: g.label,
              icon: g.icon,
              steps: g.steps,
              command: g.command.replaceAll('<seu_token>', authToken),
            ))
        .toList();

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
              children:
                  guides.map((g) => _buildGuideContent(g)).toList(),
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
          const Icon(Icons.info_outline,
              color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'O token de provisionamento identifica a organização, não o usuário. '
              'O Agent instalado via GPO usa esse token para se registrar automaticamente — '
              'o colaborador não precisa fazer login.',
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
