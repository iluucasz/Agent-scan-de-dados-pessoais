import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/organization.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  Organization? _organization;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const String _tokenKey = 'seusdados_token';
  static const String _userKey = 'seusdados_user';
  static const String _orgKey = 'seusdados_organization';

  // Estado do fluxo Agent OTP
  bool _isAwaitingOtp = false;
  String? _pendingAgentEmail;

  User? get user => _user;
  Organization? get organization => _organization;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get token => _user?.token;
  ApiService get apiService => _apiService;
  bool get isAwaitingOtp => _isAwaitingOtp;
  String? get pendingAgentEmail => _pendingAgentEmail;

  Future<void> initialize({String? provisioningToken}) async {
    await checkStoredAuth();

    final normalizedToken = provisioningToken?.trim();
    if (_isAuthenticated ||
        normalizedToken == null ||
        normalizedToken.isEmpty) {
      return;
    }

    await bootstrapWithProvisioningToken(normalizedToken);
  }

  // Verifica se há autenticação armazenada (similar ao checkStoredAuth do React)
  Future<void> checkStoredAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_tokenKey);

      if (storedToken == null || storedToken.isEmpty) {
        debugPrint('🔍 Nenhum token armazenado encontrado');
        _isLoading = false;
        _isAuthenticated = false;
        notifyListeners();
        return;
      }

      debugPrint('🔍 Token armazenado encontrado, validando...');

      // Validar se o token ainda é válido
      final response = await _apiService.validateToken(storedToken);

      final userData = response['user'] as Map<String, dynamic>;
      final orgData = response['organization'] as Map<String, dynamic>?;

      _user = User.fromJson(userData, token: storedToken);

      if (orgData != null) {
        _organization = Organization.fromJson(orgData);
      }

      _apiService.setToken(storedToken);
      _isAuthenticated = true;
      _errorMessage = null;

      debugPrint('✅ Autenticação restaurada com sucesso: ${_user?.name}');
    } catch (e) {
      debugPrint('❌ Token inválido ou expirado, fazendo logout: $e');
      await _clearStoredAuth();
      _isAuthenticated = false;
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Salvar dados de autenticação localmente
  Future<void> _saveAuthData(
      String token, User user, Organization? organization) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, user.toJson().toString());
      if (organization != null) {
        await prefs.setString(_orgKey, organization.toJson().toString());
      }
      debugPrint('💾 Dados de autenticação salvos localmente');
    } catch (e) {
      debugPrint('⚠️  Erro ao salvar dados: $e');
    }
  }

  // Limpar dados de autenticação armazenados
  Future<void> _clearStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_orgKey);
      debugPrint('🗑️  Dados de autenticação removidos');
    } catch (e) {
      debugPrint('⚠️  Erro ao limpar dados: $e');
    }
  }

  /// Detecta se o token parece ser JWT (começa com "eyJ") ou token permanente de agent (hex)
  bool _isJwt(String token) {
    return token.startsWith('eyJ');
  }

  Future<void> _loadOrganizationForToken(String accessToken) async {
    _organization = null;

    if (accessToken.isEmpty) {
      return;
    }

    _apiService.setToken(accessToken);
    try {
      final meResponse = await _apiService.getMe();
      final orgData = meResponse['organization'] as Map<String, dynamic>?;
      if (orgData != null) {
        _organization = Organization.fromJson(orgData);
      }
    } catch (e) {
      debugPrint('⚠️  Não foi possível buscar organização: $e');
    }
  }

  Future<void> _completeAgentSession(
    Map<String, dynamic> userData,
    String accessToken,
  ) async {
    _user = User.fromJson(userData, token: accessToken);
    await _loadOrganizationForToken(accessToken);
    await _saveAuthData(accessToken, _user!, _organization);

    _isAuthenticated = true;
    _isAwaitingOtp = false;
    _pendingAgentEmail = null;
    _errorMessage = null;
    _isLoading = false;

    notifyListeners();
  }

  // Login com token (auto-detecta JWT vs token de agent)
  Future<bool> login(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final isJwt = _isJwt(token);
    debugPrint(
        '🔑 login(): token=${token.substring(0, token.length.clamp(0, 10))}... isJwt=$isJwt length=${token.length}');

    // Se parece JWT, usar fluxo direto /api/auth/me
    if (isJwt) {
      debugPrint('🔑 login(): usando fluxo JWT direto');
      return _loginWithJwt(token);
    }

    // Caso contrário, tentar fluxo de Agent (token permanente hex)
    debugPrint('🔑 login(): usando fluxo Agent (2 etapas)');
    return _loginAgentStep1(token);
  }

  // Login direto com JWT (fluxo original)
  Future<bool> _loginWithJwt(String token) async {
    try {
      final response = await _apiService.validateToken(token);

      debugPrint('✅ Resposta da API: $response');

      final userData = response['user'] as Map<String, dynamic>;
      final orgData = response['organization'] as Map<String, dynamic>?;
      final orgScope = response['orgScope'] as Map<String, dynamic>?;

      debugPrint('✅ User data: $userData');
      debugPrint('✅ Organization data: $orgData');
      debugPrint('✅ OrgScope: $orgScope');

      _user = User.fromJson(userData, token: token);

      if (orgData != null) {
        _organization = Organization.fromJson(orgData);
      }

      _apiService.setToken(token);
      await _saveAuthData(token, _user!, _organization);

      _isAuthenticated = true;
      _errorMessage = null;
      _isLoading = false;

      debugPrint(
          '✅ Login bem-sucedido: ${_user?.name} - ${_organization?.name}');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao fazer login com JWT: $e');

      _errorMessage = 'Erro ao fazer login: ${e.toString()}';
      _isAuthenticated = false;
      _isLoading = false;

      notifyListeners();
      return false;
    }
  }

  // Step 1 do fluxo Agent: envia token permanente, backend envia OTP por e-mail
  Future<bool> _loginAgentStep1(String token) async {
    try {
      final response = await _apiService.agentVerifyToken(token);

      debugPrint('✅ Agent verify-token response: $response');

      final email = response['email'] as String?;
      if (email == null || email.isEmpty) {
        throw Exception('E-mail do agent não retornado pela API');
      }

      // Guardar estado para step 2
      _pendingAgentEmail = email;
      _isAwaitingOtp = true;
      _isLoading = false;
      _errorMessage = null;

      debugPrint('📧 OTP enviado para: $email');
      notifyListeners();
      // Retornar false porque login ainda não está completo (falta OTP)
      return false;
    } catch (e) {
      debugPrint('❌ Erro no fluxo agent verify-token: $e');

      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isAuthenticated = false;
      _isLoading = false;
      _isAwaitingOtp = false;

      notifyListeners();
      return false;
    }
  }

  // Step 2 do fluxo Agent: envia código OTP, recebe JWT
  Future<bool> loginAgentOtp(String code) async {
    if (_pendingAgentEmail == null) {
      _errorMessage = 'Sessão expirada. Insira o token novamente.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.agentVerifyOtp(
        _pendingAgentEmail!,
        code.trim(),
      );

      debugPrint('✅ Agent verify-otp response: $response');

      final userData = response['user'] as Map<String, dynamic>;
      final orgScope = response['orgScope'] as Map<String, dynamic>?;

      // O backend retorna o accessToken dentro de user
      final accessToken = userData['accessToken'] as String? ?? '';

      debugPrint('✅ Agent user data: $userData');
      debugPrint('✅ Agent orgScope: $orgScope');

      if (accessToken.isEmpty) {
        throw Exception('JWT não retornado pelo backend');
      }

      await _completeAgentSession(userData, accessToken);

      debugPrint('✅ Login Agent bem-sucedido: ${_user?.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Erro no fluxo agent verify-otp: $e');

      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;

      notifyListeners();
      return false;
    }
  }

  Future<bool> bootstrapWithProvisioningToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      _errorMessage = 'Token de provisionamento inválido.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response =
          await _apiService.exchangeProvisioningToken(normalizedToken);

      final userData = response['user'] as Map<String, dynamic>;
      final accessToken = userData['accessToken'] as String? ?? '';

      if (accessToken.isEmpty) {
        throw Exception('JWT não retornado pelo backend');
      }

      await _completeAgentSession(userData, accessToken);
      debugPrint('✅ Bootstrap corporativo concluído: ${_user?.email}');
      return true;
    } catch (e) {
      debugPrint('❌ Erro no bootstrap corporativo: $e');

      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isAuthenticated = false;
      _isLoading = false;

      notifyListeners();
      return false;
    }
  }

  // Cancelar fluxo Agent OTP e voltar para tela de token
  void cancelAgentOtp() {
    _isAwaitingOtp = false;
    _pendingAgentEmail = null;
    _errorMessage = null;
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    _user = null;
    _organization = null;
    _isAuthenticated = false;
    _errorMessage = null;
    _apiService.clearToken();

    // Limpar dados armazenados
    await _clearStoredAuth();

    notifyListeners();
  }

  // Limpar erro
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Verificar se o token ainda é válido
  Future<bool> validateToken() async {
    if (_user == null || _user!.token.isEmpty) {
      return false;
    }

    try {
      // TODO: Implementar validação real do token com a API
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      logout();
      return false;
    }
  }
}
