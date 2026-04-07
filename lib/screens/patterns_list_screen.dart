import 'package:flutter/material.dart';
import '../constants/data_patterns.dart';

import '../theme/app_colors.dart';

class PatternsListScreen extends StatelessWidget {
  const PatternsListScreen({super.key});

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

  IconData _getCategoryIcon(PatternCategory category) {
    switch (category) {
      case PatternCategory.id:
        return Icons.badge;
      case PatternCategory.personal:
        return Icons.person;
      case PatternCategory.contact:
        return Icons.contact_phone;
      case PatternCategory.financial:
        return Icons.credit_card;
      case PatternCategory.sensitive:
        return Icons.warning;
      case PatternCategory.health:
        return Icons.medical_services;
      case PatternCategory.biometric:
        return Icons.fingerprint;
      case PatternCategory.location:
        return Icons.location_on;
    }
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
          constraints: const BoxConstraints(maxWidth: 1200),
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
                      Icons.pattern,
                      size: 32,
                      color: AppColors.primary700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Biblioteca de Padrões',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DataPatterns.totalPatterns} padrões de dados organizados em ${PatternCategory.values.length} categorias',
                          style: const TextStyle(
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

              // Resumo por categoria com cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: PatternCategory.values.map((category) {
                  final count = DataPatterns.countByCategory[category] ?? 0;
                  final color = _getCategoryColor(category);
                  return Container(
                    width: 160,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          size: 28,
                          color: color,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count padrões',
                          style: TextStyle(
                            fontSize: 11,
                            color: color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              // Lista por categoria
              ...patternsByCategory.entries.map((entry) {
                final categoryColor = _getCategoryColor(entry.key);
                return Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getCategoryIcon(entry.key),
                                size: 24,
                                color: categoryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key.label,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: categoryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${entry.value.length} padrões disponíveis',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          categoryColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Patterns Grid
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: entry.value.map((pattern) {
                            return Container(
                              width: (MediaQuery.of(context).size.width > 1400)
                                  ? 360
                                  : (MediaQuery.of(context).size.width > 1000)
                                      ? 280
                                      : double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.gray50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.gray200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pattern.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppColors.gray900,
                                          ),
                                        ),
                                      ),
                                      if (!pattern.enabled)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.gray300,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Desabilitado',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.gray700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    pattern.description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.gray600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.gray300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      pattern.regex,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: AppColors.gray800,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
