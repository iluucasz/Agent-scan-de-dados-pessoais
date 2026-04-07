import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_card.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tokenController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = _tokenController.text.trim();

    // Validação básica
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira seu token de acesso';
        _isLoading = false;
      });
      return;
    }

    if (token.length < 10) {
      setState(() {
        _errorMessage = 'Token inválido. Deve ter pelo menos 10 caracteres';
        _isLoading = false;
      });
      return;
    }

    // Usar AuthProvider para fazer login
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(token);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Se entrou em modo OTP (agent flow), o AuthProvider não retorna success
      // mas isAwaitingOtp será true
      if (authProvider.isAwaitingOtp) {
        // Mostra campo OTP — tratado pelo Consumer no build
        setState(() {
          _errorMessage = null;
        });
        return;
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login realizado com sucesso!'),
              backgroundColor: AppColors.success600,
            ),
          );

          // Navegar para dashboard após login bem-sucedido
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Erro ao fazer login';
        });
      }
    }
  }

  Future<void> _handleOtpSubmit() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira o código OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginAgentOtp(code);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login realizado com sucesso!'),
            backgroundColor: AppColors.success600,
          ),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Código inválido';
        });
      }
    }
  }

  void _cancelOtp() {
    final authProvider = context.read<AuthProvider>();
    authProvider.cancelAgentOtp();
    _otpController.clear();
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo e título
                Image.asset(
                  'assets/icons/pv-pulse.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'SeusDADOS Client',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray900,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Verificação de Dados Pessoais - LGPD',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Card de login
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final isOtpStep = authProvider.isAwaitingOtp;

                    return CustomCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isOtpStep ? 'Verificação OTP' : 'Autenticação',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isOtpStep
                                ? 'Enviamos um código de verificação para ${authProvider.pendingAgentEmail}'
                                : 'Digite seu token de acesso da Privacy Pulse',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.gray600,
                                    ),
                          ),
                          const SizedBox(height: 24),

                          if (!isOtpStep) ...[
                            // Campo de token
                            CustomInput(
                              label: 'Token de Acesso',
                              hint: 'Cole seu token aqui',
                              controller: _tokenController,
                              error: _errorMessage,
                              keyboardType: TextInputType.text,
                              onChanged: (value) {
                                if (_errorMessage != null) {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                }
                              },
                              prefix: const Icon(Icons.key, size: 20),
                            ),
                            const SizedBox(height: 24),

                            // Botão de login
                            CustomButton(
                              text: _isLoading ? 'Autenticando...' : 'Entrar',
                              onPressed: _isLoading ? null : _handleLogin,
                              loading: _isLoading,
                              fullWidth: true,
                              size: ButtonSize.lg,
                            ),
                          ] else ...[
                            // Campo de OTP
                            CustomInput(
                              label: 'Código OTP',
                              hint: 'Digite o código recebido por e-mail',
                              controller: _otpController,
                              error: _errorMessage,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                if (_errorMessage != null) {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                }
                              },
                              prefix: const Icon(Icons.lock_outline, size: 20),
                            ),
                            const SizedBox(height: 24),

                            // Botão de verificar OTP
                            CustomButton(
                              text: _isLoading
                                  ? 'Verificando...'
                                  : 'Verificar Código',
                              onPressed: _isLoading ? null : _handleOtpSubmit,
                              loading: _isLoading,
                              fullWidth: true,
                              size: ButtonSize.lg,
                            ),
                            const SizedBox(height: 12),

                            // Botão de voltar
                            TextButton.icon(
                              onPressed: _isLoading ? null : _cancelOtp,
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Voltar e usar outro token'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.gray600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Link de ajuda
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Acesse o painel Privacy Pulse para obter seu token'),
                                ),
                              );
                            },
                            child: const Text(
                              'Onde encontro meu token?',
                              style: TextStyle(
                                color: AppColors.primary600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Informação adicional
                CustomCard(
                  color: AppColors.info50,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.info700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'O token é necessário para conectar com a API Privacy Pulse e realizar varreduras',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.info700,
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

  @override
  void dispose() {
    _tokenController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
