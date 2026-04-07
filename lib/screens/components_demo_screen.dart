import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_badge.dart';
import '../widgets/custom_input.dart';

class ComponentsDemoScreen extends StatefulWidget {
  const ComponentsDemoScreen({super.key});

  @override
  State<ComponentsDemoScreen> createState() => _ComponentsDemoScreenState();
}

class _ComponentsDemoScreenState extends State<ComponentsDemoScreen> {
  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Componentes UI Base'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botões
            const Text('Botões',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Variantes:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      CustomButton(
                        text: 'Primary',
                        onPressed: () {},
                        variant: ButtonVariant.primary,
                      ),
                      CustomButton(
                        text: 'Secondary',
                        onPressed: () {},
                        variant: ButtonVariant.secondary,
                      ),
                      CustomButton(
                        text: 'Success',
                        onPressed: () {},
                        variant: ButtonVariant.success,
                      ),
                      CustomButton(
                        text: 'Danger',
                        onPressed: () {},
                        variant: ButtonVariant.danger,
                      ),
                      CustomButton(
                        text: 'Outline',
                        onPressed: () {},
                        variant: ButtonVariant.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Tamanhos:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CustomButton(
                        text: 'Small',
                        onPressed: () {},
                        size: ButtonSize.sm,
                      ),
                      CustomButton(
                        text: 'Medium',
                        onPressed: () {},
                        size: ButtonSize.md,
                      ),
                      CustomButton(
                        text: 'Large',
                        onPressed: () {},
                        size: ButtonSize.lg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Estados:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      CustomButton(
                        text: 'Com Ícone',
                        onPressed: () {},
                        icon: Icons.download,
                      ),
                      CustomButton(
                        text: 'Loading',
                        onPressed: () {},
                        loading: true,
                      ),
                      const CustomButton(
                        text: 'Disabled',
                        onPressed: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Full Width',
                    onPressed: () {},
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Badges
            const Text('Badges',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const CustomCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CustomBadge(text: 'ID', variant: BadgeVariant.id),
                  CustomBadge(text: 'Pessoal', variant: BadgeVariant.personal),
                  CustomBadge(text: 'Contato', variant: BadgeVariant.contact),
                  CustomBadge(
                      text: 'Financeiro', variant: BadgeVariant.financial),
                  CustomBadge(
                      text: 'Sensível', variant: BadgeVariant.sensitive),
                  CustomBadge(text: 'Saúde', variant: BadgeVariant.health),
                  CustomBadge(
                      text: 'Biométrico', variant: BadgeVariant.biometric),
                  CustomBadge(
                      text: 'Localização', variant: BadgeVariant.location),
                  CustomBadge(
                      text: 'Pequeno',
                      variant: BadgeVariant.neutral,
                      small: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Inputs
            const Text('Inputs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            CustomCard(
              child: Column(
                children: [
                  CustomInput(
                    label: 'Nome',
                    hint: 'Digite seu nome',
                    controller: _textController,
                  ),
                  const SizedBox(height: 16),
                  const CustomInput(
                    label: 'Email',
                    hint: 'email@exemplo.com',
                    helper: 'Seu email será usado para login',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  const CustomInput(
                    label: 'Senha',
                    hint: '••••••••',
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  const CustomInput(
                    label: 'Campo com erro',
                    hint: 'Campo obrigatório',
                    error: 'Este campo é obrigatório',
                  ),
                  const SizedBox(height: 16),
                  const CustomInput(
                    label: 'Campo somente leitura',
                    hint: 'Não editável',
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  const CustomInput(
                    label: 'Descrição',
                    hint: 'Digite uma descrição...',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cards
            const Text('Cards',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card Padrão',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Este é um card com padding e elevação padrão.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CustomCard(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card clicado!')),
                );
              },
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card Clicável',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Clique neste card para ver o efeito.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
