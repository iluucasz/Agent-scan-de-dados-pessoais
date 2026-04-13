import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_badge.dart';
import '../theme/app_colors.dart';
import '../providers/scan_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/scan_flow_service.dart';
import '../constants/data_patterns.dart';
import '../models/area.dart';
import '../models/processo.dart';
import '../models/scan_preset.dart';

class ScanConfigScreen extends StatefulWidget {
  const ScanConfigScreen({super.key});

  @override
  State<ScanConfigScreen> createState() => _ScanConfigScreenState();
}

class _ScanConfigScreenState extends State<ScanConfigScreen> {
  static const List<int> _maxFileSizeOptionsMb = [10, 50, 100, 200];

  String? _selectedPath;
  final Set<String> _selectedPatterns = {};
  bool _includeSubfolders = true;
  int _maxFileSizeMb = 10;
  final _scanNameController = TextEditingController();
  bool _isEditingScanName = false;
  String _selectedPresetId = 'quick';

  @override
  void initState() {
    super.initState();

    // Valor padrão vem das Configurações (global)
    final globalIncludeSubfolders =
        context.read<SettingsProvider>().settings.includeSubfoldersByDefault;
    _includeSubfolders = globalIncludeSubfolders;

    final globalMaxFileSize =
        context.read<SettingsProvider>().settings.defaultMaxFileSize;
    _maxFileSizeMb = _maxFileSizeOptionsMb.contains(globalMaxFileSize)
        ? globalMaxFileSize
        : 100;

    // Aplicar preset padrão (Rápido)
    _applyPreset(ScanPresets.quick);

    // Nome padrão do escaneamento (caso o usuário não defina manualmente)
    if (_scanNameController.text.trim().isEmpty) {
      _scanNameController.text =
          'Escaneamento ${_formatDatePtBr(DateTime.now())}';
    }
  }

  Future<void> _selectDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        setState(() {
          _selectedPath = selectedDirectory;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seleção de diretório não disponível na web. Use a versão desktop (Windows/Linux/Mac) para esta funcionalidade.',
              style: TextStyle(fontSize: 13),
            ),
            backgroundColor: AppColors.warning600,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _formatDatePtBr(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _buildScanNameFromAreaProcess({
    required Area area,
    required Processo processo,
  }) {
    final date = _formatDatePtBr(DateTime.now());
    return 'Escaneamento da Área ${area.name} e Processo ${processo.name} $date';
  }

  void _applyPreset(ScanPreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      if (preset.id != 'custom') {
        _selectedPatterns
          ..clear()
          ..addAll(preset.patternNames);
        _includeSubfolders = preset.includeSubfolders;
        _maxFileSizeMb = preset.maxFileSizeMb;
      }
    });
  }

  Future<void> _openAreaProcessSelector() async {
    final authProvider = context.read<AuthProvider>();
    final apiService = ApiService();
    apiService.setToken(authProvider.user!.token);

    final selection = await showDialog<AreaProcessSelection>(
      context: context,
      builder: (context) => AreaProcessSelectorDialog(apiService: apiService),
    );

    if (!mounted || selection == null) {
      return;
    }

    setState(() {
      _scanNameController.text = _buildScanNameFromAreaProcess(
        area: selection.area,
        processo: selection.processo,
      );
      _isEditingScanName = false;
    });
  }

  void _togglePattern(String patternName) {
    setState(() {
      _selectedPresetId = 'custom';
      if (_selectedPatterns.contains(patternName)) {
        _selectedPatterns.remove(patternName);
      } else {
        _selectedPatterns.add(patternName);
      }
    });
  }

  void _selectAllPatterns() {
    setState(() {
      _selectedPresetId = 'custom';
      _selectedPatterns.addAll(
        DataPatterns.allPatterns.map((p) => p.name),
      );
    });
  }

  void _clearAllPatterns() {
    setState(() {
      _selectedPresetId = 'custom';
      _selectedPatterns.clear();
    });
  }

  void _selectCategoryPatterns(PatternCategory category) {
    setState(() {
      _selectedPresetId = 'custom';
      final categoryPatterns = DataPatterns.getByCategory(category);
      _selectedPatterns.addAll(categoryPatterns.map((p) => p.name));
    });
  }

  void _startScan() {
    if (_selectedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma pasta para escanear'),
          backgroundColor: AppColors.warning600,
        ),
      );
      return;
    }

    if (_selectedPatterns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione pelo menos um padrão'),
          backgroundColor: AppColors.warning600,
        ),
      );
      return;
    }

    final scanProvider = context.read<ScanProvider>();

    scanProvider.createConfig(
      scanName: _scanNameController.text.trim(),
      path: _selectedPath!,
      selectedPatterns: _selectedPatterns.toList(),
      includeSubfolders: _includeSubfolders,
      maxFileSize: _maxFileSizeMb * 1024 * 1024, // MB para bytes
    );

    // Iniciar scan com integração da API
    final authProvider = context.read<AuthProvider>();
    final apiService = ApiService();
    apiService.setToken(authProvider.user!.token);
    final scanFlowService = ScanFlowService(apiService);

    scanProvider.startScanWithApiIntegration(
      currentUser: authProvider.user!,
      scanFlowService: scanFlowService,
    );

    // Navegar para tela de progresso
    Navigator.pushNamed(context, '/scan-progress');
  }

  @override
  Widget build(BuildContext context) {
    final patternsByCategory = <PatternCategory, List<DataPattern>>{};

    for (var pattern in DataPatterns.allPatterns) {
      patternsByCategory.putIfAbsent(pattern.category, () => []).add(pattern);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.radar,
                      size: 32,
                      color: AppColors.primary700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuração de Escaneamento',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Configure os parâmetros e padrões de dados para escanear seus arquivos',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Preset selector ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.speed,
                            size: 24,
                            color: AppColors.primary600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Modo de Escaneamento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Escolha um preset ou configure manualmente',
                      style: TextStyle(fontSize: 13, color: AppColors.gray600),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: ScanPresets.all.map((preset) {
                        final isSelected = _selectedPresetId == preset.id;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: preset.id != ScanPresets.all.last.id
                                  ? 12
                                  : 0,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _applyPreset(preset),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [
                                              AppColors.primary600,
                                              AppColors.primary700,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected ? null : AppColors.gray50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary600
                                          : AppColors.gray200,
                                      width: isSelected ? 2 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary600
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        preset.icon,
                                        size: 28,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.gray600,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        preset.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.gray800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        preset.description,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.white70
                                              : AppColors.gray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Grid Layout - 2 columns
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // Seleção de pasta
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.gray200, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.folder_open,
                                      size: 24,
                                      color: AppColors.primary600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Diretório de Origem',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gray900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _selectedPath == null
                                      ? const LinearGradient(
                                          colors: [
                                            AppColors.primary600,
                                            AppColors.primary700
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            AppColors.gray100,
                                            AppColors.gray50
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _selectedPath == null
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary600
                                                .withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : [],
                                  border: _selectedPath != null
                                      ? Border.all(
                                          color: AppColors.gray300, width: 1.5)
                                      : null,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _selectDirectory,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18, horizontal: 24),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.folder_open,
                                            color: _selectedPath == null
                                                ? Colors.white
                                                : AppColors.primary600,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _selectedPath == null
                                                ? 'Selecionar Diretório'
                                                : 'Alterar Diretório',
                                            style: TextStyle(
                                              color: _selectedPath == null
                                                  ? Colors.white
                                                  : AppColors.gray700,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_selectedPath != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.success50,
                                        Colors.white
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.success100,
                                        width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.success600,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _selectedPath!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.success700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nome do escaneamento
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gray200,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.drive_file_rename_outline,
                                      size: 24,
                                      color: AppColors.primary600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Nome do Escaneamento',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gray900,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isEditingScanName =
                                            !_isEditingScanName;
                                      });
                                    },
                                    icon: Icon(
                                      _isEditingScanName
                                          ? Icons.check
                                          : Icons.edit,
                                      size: 18,
                                      color: AppColors.primary700,
                                    ),
                                    label: Text(
                                      _isEditingScanName
                                          ? 'Concluir'
                                          : 'Editar',
                                      style: const TextStyle(
                                        color: AppColors.primary700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.primary300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CustomInput(
                                label: null,
                                hint:
                                    'Ex: Escaneamento da Área RH e Processo Gestão de usuários ${_formatDatePtBr(DateTime.now())}',
                                helper:
                                    'Você pode editar manualmente ou gerar automaticamente por Área e Processo.',
                                controller: _scanNameController,
                                readOnly: !_isEditingScanName,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _openAreaProcessSelector,
                                  icon: const Icon(
                                    Icons.account_tree_outlined,
                                    size: 18,
                                    color: AppColors.info700,
                                  ),
                                  label: const Text(
                                    'Definir Área e Processo',
                                    style: TextStyle(
                                      color: AppColors.info700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.info100,
                                    ),
                                    minimumSize: const Size.fromHeight(52),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Opções de scan
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.gray200, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.info100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.settings,
                                      size: 24,
                                      color: AppColors.info600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Opções de Escaneamento',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gray900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.gray200),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Incluir subpastas',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Escanear recursivamente em todas as subpastas',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  trailing: Switch(
                                    value: _includeSubfolders,
                                    onChanged: (value) {
                                      setState(() {
                                        _includeSubfolders = value;
                                      });
                                    },
                                    activeThumbColor: AppColors.primary600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Builder(
                                builder: (context) {
                                  final theme = Theme.of(context);
                                  final cs = theme.colorScheme;
                                  const options = _maxFileSizeOptionsMb;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tamanho máximo do arquivo (MB)',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<int>(
                                        initialValue:
                                            options.contains(_maxFileSizeMb)
                                                ? _maxFileSizeMb
                                                : 10,
                                        items: options
                                            .map(
                                              (v) => DropdownMenuItem<int>(
                                                value: v,
                                                child: Text('$v MB'),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _maxFileSizeMb = value;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          filled: true,
                                          helperText:
                                              'Arquivos maiores serão ignorados',
                                          helperStyle: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Right Column
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // Seleção de padrões
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.gray200, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.pattern,
                                      size: 24,
                                      color: AppColors.primary600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Padrões de Dados',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gray900,
                                      ),
                                    ),
                                  ),
                                  CustomBadge(
                                    text:
                                        '${_selectedPatterns.length} selecionados',
                                    variant: _selectedPatterns.isEmpty
                                        ? BadgeVariant.neutral
                                        : BadgeVariant.contact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Selecione os tipos de dados pessoais para detectar',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.gray600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.primary600,
                                            AppColors.primary700
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary600
                                                .withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _selectAllPatterns,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 14, horizontal: 16),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.check_box,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Selecionar Todos',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.danger500,
                                          width: 2,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _clearAllPatterns,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 14, horizontal: 16),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.clear,
                                                  size: 20,
                                                  color: AppColors.danger600,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Limpar Todos',
                                                  style: TextStyle(
                                                    color: AppColors.danger600,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Selecionar por Categoria:',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    PatternCategory.values.map((category) {
                                  return GestureDetector(
                                    onTap: () =>
                                        _selectCategoryPatterns(category),
                                    child: CustomBadge(
                                      text: category.label,
                                      variant:
                                          _getCategoryBadgeVariant(category),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Lista de padrões por categoria
                        ...patternsByCategory.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getCategoryColor(entry.key)
                                        .withValues(alpha: 0.05),
                                    Colors.white,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getCategoryColor(entry.key)
                                      .withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CustomBadge(
                                        text: entry.key.label,
                                        variant:
                                            _getCategoryBadgeVariant(entry.key),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${entry.value.where((p) => _selectedPatterns.contains(p.name)).length}/${entry.value.length}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.gray700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: entry.value.map((pattern) {
                                      final isSelected = _selectedPatterns
                                          .contains(pattern.name);
                                      return FilterChip(
                                        label: Text(
                                          pattern.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? AppColors.primary700
                                                : AppColors.gray700,
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: (selected) =>
                                            _togglePattern(pattern.name),
                                        selectedColor: AppColors.primary100,
                                        backgroundColor: Colors.white,
                                        checkmarkColor: AppColors.primary600,
                                        side: BorderSide(
                                          color: isSelected
                                              ? AppColors.primary300
                                              : AppColors.gray200,
                                          width: 1,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        showCheckmark: true,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              // Botão de iniciar - Full Width
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.success600, AppColors.success700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success600.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _startScan,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Iniciar Escaneamento',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  BadgeVariant _getCategoryBadgeVariant(PatternCategory category) {
    switch (category) {
      case PatternCategory.id:
        return BadgeVariant.id;
      case PatternCategory.personal:
        return BadgeVariant.personal;
      case PatternCategory.contact:
        return BadgeVariant.contact;
      case PatternCategory.financial:
        return BadgeVariant.financial;
      case PatternCategory.sensitive:
        return BadgeVariant.sensitive;
      case PatternCategory.health:
        return BadgeVariant.health;
      case PatternCategory.biometric:
        return BadgeVariant.biometric;
      case PatternCategory.location:
        return BadgeVariant.location;
    }
  }

  Color _getCategoryColor(PatternCategory category) {
    switch (category) {
      case PatternCategory.id:
        return AppColors.primary600;
      case PatternCategory.personal:
        return AppColors.info600;
      case PatternCategory.contact:
        return AppColors.success600;
      case PatternCategory.financial:
        return AppColors.warning600;
      case PatternCategory.sensitive:
        return AppColors.danger600;
      case PatternCategory.health:
        return const Color(0xFFE91E63);
      case PatternCategory.biometric:
        return const Color(0xFF9C27B0);
      case PatternCategory.location:
        return const Color(0xFF00BCD4);
    }
  }

  @override
  void dispose() {
    _scanNameController.dispose();
    super.dispose();
  }
}

class AreaProcessSelection {
  final Area area;
  final Processo processo;

  const AreaProcessSelection({required this.area, required this.processo});
}

class AreaProcessSelectorDialog extends StatefulWidget {
  final ApiService apiService;

  const AreaProcessSelectorDialog({
    super.key,
    required this.apiService,
  });

  @override
  State<AreaProcessSelectorDialog> createState() =>
      _AreaProcessSelectorDialogState();
}

class _AreaProcessSelectorDialogState extends State<AreaProcessSelectorDialog> {
  bool _loadingAreas = true;
  bool _loadingProcesses = false;
  String? _error;

  List<Area> _areas = const [];
  List<Processo> _processes = const [];

  Area? _selectedArea;
  Processo? _selectedProcess;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _loadingAreas = true;
      _error = null;
    });

    try {
      final areas = await widget.apiService.getAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas.where((a) => a.isActive).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAreas = false;
        });
      }
    }
  }

  Future<void> _loadProcesses(int areaId) async {
    setState(() {
      _loadingProcesses = true;
      _error = null;
      _processes = const [];
      _selectedProcess = null;
    });

    try {
      final processes = await widget.apiService.getProcessesByArea(areaId);
      if (!mounted) return;
      setState(() {
        _processes = processes.where((p) => p.isActive).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProcesses = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Definir Área e Processo'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger100),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_loadingAreas) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else ...[
              DropdownButtonFormField<Area>(
                key: ValueKey<String>(
                  'area-${_selectedArea?.id ?? 'none'}',
                ),
                initialValue: _selectedArea,
                decoration: const InputDecoration(
                  labelText: 'Área',
                  border: OutlineInputBorder(),
                ),
                items: _areas
                    .map(
                      (a) => DropdownMenuItem<Area>(
                        value: a,
                        child: Text(a.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedArea = value;
                  });
                  _loadProcesses(value.id);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Processo>(
                key: ValueKey<String>(
                  'process-${_selectedArea?.id ?? 'none'}-${_selectedProcess?.id ?? 'none'}',
                ),
                initialValue: _selectedProcess,
                decoration: const InputDecoration(
                  labelText: 'Processo',
                  border: OutlineInputBorder(),
                ),
                items: _processes
                    .map(
                      (p) => DropdownMenuItem<Processo>(
                        value: p,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: _loadingProcesses
                    ? null
                    : (value) {
                        setState(() {
                          _selectedProcess = value;
                        });
                      },
              ),
              if (_loadingProcesses) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_selectedArea != null && _selectedProcess != null)
              ? () {
                  Navigator.of(context).pop(
                    AreaProcessSelection(
                      area: _selectedArea!,
                      processo: _selectedProcess!,
                    ),
                  );
                }
              : null,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
