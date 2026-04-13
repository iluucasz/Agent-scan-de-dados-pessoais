import 'package:flutter/material.dart';
import '../constants/data_patterns.dart';

/// Define um preset de escaneamento com padrões, opções e limites pré-configurados.
class ScanPreset {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<String> patternNames;
  final bool includeSubfolders;
  final int maxFileSizeMb;

  const ScanPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.patternNames,
    required this.includeSubfolders,
    required this.maxFileSizeMb,
  });
}

/// Presets disponíveis para o usuário.
abstract final class ScanPresets {
  /// Rápido: apenas documentos de alta criticidade (CPF, CNPJ, e-mail, cartão).
  static final quick = ScanPreset(
    id: 'quick',
    name: 'Rápido',
    description:
        'Documentos de alta criticidade: CPF, CNPJ, cartão de crédito e e-mail.',
    icon: Icons.bolt,
    patternNames: [
      DataPatterns.cpf.name,
      DataPatterns.cnpj.name,
      DataPatterns.email.name,
      DataPatterns.cartaoCredito.name,
    ],
    includeSubfolders: false,
    maxFileSizeMb: 10,
  );

  /// Completo: todos os padrões, subpastas, arquivos grandes.
  static final complete = ScanPreset(
    id: 'complete',
    name: 'Completo',
    description:
        'Todos os padrões de dados pessoais, com subpastas e arquivos de até 200 MB.',
    icon: Icons.shield,
    patternNames: DataPatterns.allPatterns.map((p) => p.name).toList(),
    includeSubfolders: true,
    maxFileSizeMb: 200,
  );

  /// Personalizado: o usuário configura manualmente (sem alteração automática).
  static const custom = ScanPreset(
    id: 'custom',
    name: 'Personalizado',
    description: 'Configure manualmente os padrões e opções de escaneamento.',
    icon: Icons.tune,
    patternNames: [],
    includeSubfolders: true,
    maxFileSizeMb: 100,
  );

  static List<ScanPreset> get all => [quick, complete, custom];
}
