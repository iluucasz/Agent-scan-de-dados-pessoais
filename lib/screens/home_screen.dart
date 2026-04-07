import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/scan_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de introdução compacto
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary50, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary200, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/icons/pv-pulse.png',
                        height: 40,
                        width: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proteção de Dados Pessoais',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Detecte e proteja dados pessoais sensíveis em seus arquivos',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.gray700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botão de scan melhorado
              Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary600, AppColors.primary700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary600.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pushNamed(context, '/scan-config');
                    },
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar, size: 28, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Novo Escaneamento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward,
                              size: 20, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Último resultado
              Consumer<ScanProvider>(
                builder: (context, scanProvider, _) {
                  final result = scanProvider.lastResult;

                  if (result == null) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 48,
                              color: AppColors.gray400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma varredura realizada ainda',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.gray600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                result.foundData.isEmpty
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: result.foundData.isEmpty
                                    ? AppColors.success600
                                    : AppColors.danger600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Última Varredura',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/scan-results');
                                },
                                icon: const Icon(Icons.visibility),
                                label: const Text('Ver Detalhes'),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${result.totalFilesScanned}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary600,
                                    ),
                                  ),
                                  const Text(
                                    'Arquivos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${result.totalDataFound}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: result.foundData.isEmpty
                                          ? AppColors.gray400
                                          : AppColors.danger600,
                                    ),
                                  ),
                                  const Text(
                                    'Dados Encontrados',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${result.scanDuration.inSeconds}s',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.info600,
                                    ),
                                  ),
                                  const Text(
                                    'Duração',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
