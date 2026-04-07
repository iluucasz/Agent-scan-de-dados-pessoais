import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_badge.dart';
import '../theme/app_colors.dart';
import '../providers/scan_provider.dart';
import '../models/personal_data.dart';

class ScanResultsScreen extends StatefulWidget {
  const ScanResultsScreen({super.key});

  @override
  State<ScanResultsScreen> createState() => _ScanResultsScreenState();
}

class _ScanResultsScreenState extends State<ScanResultsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _displayedItems = 20;
  bool _isLoadingMore = false;

  Future<void> _openPulseEscaneamento() async {
    final uri = Uri.parse('https://pulse.seusdados.com/escaneamento');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o link no navegador.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    final scanProvider = context.read<ScanProvider>();
    final result = scanProvider.lastResult;

    if (result != null &&
        _displayedItems < result.foundData.length &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });

      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _displayedItems =
                (_displayedItems + 20).clamp(0, result.foundData.length);
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<ScanProvider>();
    final result = scanProvider.lastResult;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resultados')),
        body: const Center(
          child: Text('Nenhum resultado disponível'),
        ),
      );
    }

    final summary = result.getDataTypeSummary();
    final hasFindings = result.foundData.isNotEmpty;
    final displayedData = result.foundData.take(_displayedItems).toList();

    return ExcludeSemantics(
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Resultados do Scan'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                scanProvider.clearResults();
                Navigator.pushReplacementNamed(context, '/scan-config');
              },
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              },
            ),
          ],
        ),
        floatingActionButton: _displayedItems > 20
            ? ExcludeSemantics(
                child: FloatingActionButton.small(
                  heroTag: "scroll_to_top",
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  backgroundColor: AppColors.primary600,
                  child:
                      const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                ),
              )
            : null,
        body: Column(
          children: [
            _buildHeader(result, hasFindings, summary),
            Expanded(
              child: hasFindings
                  ? _buildResultsList(displayedData, result)
                  : _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(result, bool hasFindings, Map<String, int> summary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Status principal
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasFindings
                            ? AppColors.danger100
                            : AppColors.success100,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        hasFindings ? Icons.warning_amber : Icons.check_circle,
                        size: 40,
                        color: hasFindings
                            ? AppColors.danger600
                            : AppColors.success600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasFindings
                          ? 'Dados Pessoais Encontrados'
                          : 'Arquivos Seguros',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: hasFindings
                            ? AppColors.danger700
                            : AppColors.success700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${result.totalFilesScanned} arquivos • ${result.totalDataFound} itens • ${result.scanDuration.inSeconds}s',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Botões de ação principais - circulares
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: FloatingActionButton(
                        heroTag: 'refresh_header',
                        onPressed: () {
                          context.read<ScanProvider>().clearResults();
                          Navigator.pushReplacementNamed(
                              context, '/scan-config');
                        },
                        backgroundColor: AppColors.primary600,
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ExcludeSemantics(
                      child: FloatingActionButton(
                        heroTag: 'home_header',
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/',
                            (route) => false,
                          );
                        },
                        backgroundColor: AppColors.gray600,
                        child: const Icon(Icons.home, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ExcludeSemantics(
                      child: FloatingActionButton(
                        heroTag: 'go_pulse_header',
                        onPressed: _openPulseEscaneamento,
                        backgroundColor: AppColors.info600,
                        child: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Resumo dos tipos encontrados
          if (hasFindings && summary.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20, color: AppColors.danger600),
                      SizedBox(width: 8),
                      Text(
                        'Tipos de dados encontrados:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: summary.entries
                        .map((entry) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.danger100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.danger100),
                              ),
                              child: Text(
                                '${entry.key} (${entry.value})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.danger700,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<PersonalData> displayedData, result) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...displayedData.map((data) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildFileCard(data),
              )),
          if (_displayedItems < result.foundData.length)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : CustomButton(
                        text:
                            'Carregar mais (${result.foundData.length - _displayedItems} restantes)',
                        icon: Icons.expand_more,
                        onPressed: _loadMoreItems,
                        variant: ButtonVariant.secondary,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success100,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 48,
              color: AppColors.success600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tudo limpo!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.success700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nenhum dado pessoal foi encontrado\nem seus arquivos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.gray600,
            ),
          ),
          const SizedBox(height: 32),
          CustomButton(
            text: 'Nova Varredura',
            icon: Icons.refresh,
            onPressed: () {
              context.read<ScanProvider>().clearResults();
              Navigator.pushReplacementNamed(context, '/scan-config');
            },
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(PersonalData data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.danger100, width: 1),
      ),
      child: Semantics(
        label: '',
        button: false,
        enabled: false,
        child: ExcludeSemantics(
          excluding: true,
          child: Material(
            color: AppColors.danger50,
            borderRadius: BorderRadius.circular(12),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.all(16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expansionAnimationStyle:
                  const AnimationStyle(duration: Duration.zero),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger600,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.warning, color: Colors.white, size: 20),
              ),
              title: Text(
                data.fileName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.danger700,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  CustomBadge(
                    text: data.dataType,
                    variant: _getBadgeVariantForType(data.dataType),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        data.confidence >= 0.9
                            ? Icons.star
                            : data.confidence >= 0.7
                                ? Icons.star_half
                                : Icons.star_border,
                        size: 14,
                        color: AppColors.warning600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Confiança: ${data.confidenceLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_open,
                              size: 16, color: AppColors.gray600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.filePath,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.gray600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Conteúdo encontrado:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: Text(
                          data.value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: AppColors.gray800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BadgeVariant _getBadgeVariantForType(String type) {
    final typeLower = type.toLowerCase();

    if (typeLower.contains('cpf') ||
        typeLower.contains('rg') ||
        typeLower.contains('cnh')) {
      return BadgeVariant.id;
    } else if (typeLower.contains('nome') || typeLower.contains('nascimento')) {
      return BadgeVariant.personal;
    } else if (typeLower.contains('email') ||
        typeLower.contains('telefone') ||
        typeLower.contains('celular')) {
      return BadgeVariant.contact;
    } else if (typeLower.contains('cartão') ||
        typeLower.contains('conta') ||
        typeLower.contains('pix')) {
      return BadgeVariant.financial;
    } else if (typeLower.contains('senha') || typeLower.contains('token')) {
      return BadgeVariant.sensitive;
    } else if (typeLower.contains('saúde') ||
        typeLower.contains('sus') ||
        typeLower.contains('médico')) {
      return BadgeVariant.health;
    } else if (typeLower.contains('biométrico') ||
        typeLower.contains('digital') ||
        typeLower.contains('facial')) {
      return BadgeVariant.biometric;
    } else if (typeLower.contains('gps') ||
        typeLower.contains('coordenada') ||
        typeLower.contains('endereço')) {
      return BadgeVariant.location;
    }

    return BadgeVariant.neutral;
  }
}
