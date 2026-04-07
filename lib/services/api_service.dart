import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import '../models/scan_config_api.dart';
import '../models/scan_run_response.dart';
import '../models/external_scan_results.dart';
import '../models/scan_job.dart';
import '../models/area.dart';
import '../models/processo.dart';

class ApiService {
  // URL base da API Privacy Pulse
  static const String baseUrl =
      'https://privacy-pulse-n76om.ondigitalocean.app';

  // Endpoints
  static const String authMeEndpoint = '/api/auth/me';
  static const String scanConfigsEndpoint = '/api/data-scan-configs';
  static const String externalScanResultsEndpoint =
      '/api/external-scan-results';
  static const String scanJobsEndpoint = '/api/data-scan-jobs';

  // Agent auth endpoints
  static const String agentVerifyTokenEndpoint = '/api/auth/agent/verify-token';
  static const String agentVerifyOtpEndpoint = '/api/auth/agent/verify-otp';

  // Áreas e Processos
  static const String areasEndpoint = '/api/areas';

  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  String? getToken() {
    return _token;
  }

  bool hasToken() {
    return _token != null && _token!.isNotEmpty;
  }

  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // Validar token e buscar dados do usuário (GET /api/auth/me)
  // Retorna user, organization e orgScope conforme API real
  Future<Map<String, dynamic>> validateToken(String token) async {
    debugPrint('🌐 validateToken: GET $baseUrl$authMeEndpoint');
    late final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl$authMeEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint('🌐 validateToken: erro de rede: $e');
      throw Exception('Erro de conexão com o servidor');
    }

    debugPrint('🌐 validateToken: status=${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } else if (response.statusCode == 401) {
      throw Exception('Token inválido ou expirado');
    } else {
      throw Exception('Erro ao validar token: ${response.statusCode}');
    }
  }

  // Step 1 do fluxo Agent: envia token permanente, backend dispara OTP por e-mail
  // Retorna { challenge_id, next, email }
  Future<Map<String, dynamic>> agentVerifyToken(String token) async {
    final url = '$baseUrl$agentVerifyTokenEndpoint';
    debugPrint('🌐 agentVerifyToken: POST $url');
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      debugPrint('🌐 agentVerifyToken: erro de rede: $e');
      throw Exception('Erro de conexão com o servidor');
    }

    debugPrint(
        '🌐 agentVerifyToken: status=${response.statusCode} body=${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      final msg = body['message'] ??
          'Erro ao validar token de agent: ${response.statusCode}';
      throw Exception(msg);
    }
  }

  // Step 2 do fluxo Agent: envia email + código OTP, retorna JWT + user + orgScope
  Future<Map<String, dynamic>> agentVerifyOtp(String email, String code) async {
    final url = '$baseUrl$agentVerifyOtpEndpoint';
    debugPrint('🌐 agentVerifyOtp: POST $url');
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'code': code}),
      );
    } catch (e) {
      debugPrint('🌐 agentVerifyOtp: erro de rede: $e');
      throw Exception('Erro de conexão com o servidor');
    }

    debugPrint('🌐 agentVerifyOtp: status=${response.statusCode}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      final msg = body['message'] ?? 'Código inválido ou expirado';
      throw Exception(msg);
    }
  }

  // Buscar dados atualizados do usuário autenticado (reutiliza token armazenado)
  Future<Map<String, dynamic>> getMe() async {
    if (_token == null) {
      throw Exception('Token não encontrado. Faça login primeiro.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$authMeEndpoint'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else {
        throw Exception('Erro ao buscar dados: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // Logout - limpa o token
  void logout() {
    clearToken();
  }

  // Testa conectividade com a API
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ========== SCAN API METHODS ==========

  // ========== ÁREAS / PROCESSOS API METHODS ==========

  Future<List<Area>> getAreas() async {
    if (_token == null) {
      throw Exception('Token não encontrado. Faça login primeiro.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$areasEndpoint'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => Area.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else {
        throw Exception('Erro ao buscar áreas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<List<Processo>> getProcessesByArea(int areaId) async {
    if (_token == null) {
      throw Exception('Token não encontrado. Faça login primeiro.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$areasEndpoint/$areaId/processos'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => Processo.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else {
        throw Exception('Erro ao buscar processos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // 1. Criar configuração de scan na API
  Future<ScanConfigResponse> createScanConfig(ScanConfigApi config) async {
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl$scanConfigsEndpoint'),
        headers: _getHeaders(),
        body: jsonEncode(config.toJson()),
      );
    } catch (e) {
      throw Exception('Erro de rede ao criar configuração: $e');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ScanConfigResponse.fromJson(data);
      } catch (e) {
        debugPrint('❌ Erro ao parsear configuração: $e');
        debugPrint('❌ Body: ${response.body}');
        throw Exception('Erro ao parsear resposta de configuração: $e');
      }
    } else if (response.statusCode == 401) {
      throw Exception('Não autorizado. Faça login novamente.');
    } else {
      throw Exception('Erro ao criar configuração: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  // 2. Executar scan com upload de arquivos (multipart/form-data)
  Future<ScanRunResponse> runScan({
    required int configId,
    required String scanName,
    List<File>? files,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$scanConfigsEndpoint/$configId/run'),
      );

      // Headers com autenticação
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.headers['Accept'] = 'application/json';

      // Adiciona scanName
      request.fields['scanName'] = scanName;

      // Adiciona arquivos se houver
      if (files != null && files.isNotEmpty) {
        for (final file in files) {
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          final multipartFile = http.MultipartFile(
            'files[]',
            stream,
            length,
            filename: file.path.split(Platform.pathSeparator).last,
            contentType: MediaType('application', 'octet-stream'),
          );
          request.files.add(multipartFile);
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('🌐 runScan response status: ${response.statusCode}');
      debugPrint('🌐 runScan response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ScanRunResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else {
        throw Exception('Erro ao executar scan: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao executar scan: $e');
    }
  }

  // 3. Enviar resultados processados localmente
  Future<ExternalScanResultsResponse> sendExternalScanResults(
    ExternalScanResultsPayload payload,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$externalScanResultsEndpoint'),
        headers: _getHeaders(),
        body: jsonEncode(payload.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ExternalScanResultsResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else {
        throw Exception('Erro ao enviar resultados: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao enviar resultados: $e');
    }
  }

  // 4. Buscar resultados de um scan específico
  Future<Map<String, dynamic>> getExternalScanResults(String scanId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$externalScanResultsEndpoint/$scanId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Resultados não encontrados');
      } else {
        throw Exception('Erro ao buscar resultados: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // 5. Listar todas as configurações de scan
  Future<List<ScanConfigResponse>> listScanConfigs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$scanConfigsEndpoint'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) =>
                ScanConfigResponse.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else {
        throw Exception('Erro ao listar configurações: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // 6. Listar jobs de scan (histórico)
  Future<List<ScanJob>> listScanJobs() async {
    late final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl$scanJobsEndpoint'),
        headers: _getHeaders(),
      );
    } catch (e) {
      throw Exception('Erro de rede ao listar jobs: $e');
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) => ScanJob.fromJson(
                item is Map<String, dynamic> ? item : <String, dynamic>{}))
            .toList();
      } catch (e) {
        debugPrint('❌ Erro ao parsear lista de jobs: $e');
        throw Exception('Erro ao parsear lista de jobs: $e');
      }
    } else if (response.statusCode == 401) {
      throw Exception('Não autorizado. Faça login novamente.');
    } else {
      throw Exception('Erro ao listar jobs: HTTP ${response.statusCode}');
    }
  }

  // 7. Buscar job específico (GET /api/data-scan-jobs/{id})
  Future<ScanJob> getScanJob(int jobId) async {
    late final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl$scanJobsEndpoint/$jobId'),
        headers: _getHeaders(),
      );
    } catch (e) {
      throw Exception('Erro de rede ao buscar job $jobId: $e');
    }

    debugPrint('🌐 getScanJob($jobId): status=${response.statusCode} body=${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

    if (response.statusCode == 401) {
      throw Exception('Não autorizado. Faça login novamente.');
    } else if (response.statusCode == 404) {
      throw Exception('Job $jobId não encontrado');
    } else if (response.statusCode != 200) {
      throw Exception('Erro ao buscar job $jobId: HTTP ${response.statusCode}');
    }

    try {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw FormatException('Esperava Map, recebeu ${data.runtimeType}');
      }
      return ScanJob.fromJson(data);
    } catch (e) {
      debugPrint('❌ Erro ao parsear job $jobId: $e');
      debugPrint('❌ Body bruto: ${response.body}');
      throw Exception('Erro ao parsear resposta do job $jobId: $e');
    }
  }

  // 8. Buscar configuração específica (GET /api/data-scan-configs/{id})
  Future<ScanConfigResponse> getScanConfig(int configId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$scanConfigsEndpoint/$configId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ScanConfigResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Configuração não encontrada');
      } else {
        throw Exception('Erro ao buscar configuração: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // 9. Deletar configuração (DELETE /api/data-scan-configs/{id})
  Future<void> deleteScanConfig(int configId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$scanConfigsEndpoint/$configId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Configuração $configId deletada com sucesso');
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Configuração não encontrada');
      } else {
        throw Exception('Erro ao deletar configuração: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // 10. Deletar todos os jobs (DELETE /api/data-scan-jobs)
  Future<Map<String, dynamic>> deleteAllScanJobs() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$scanJobsEndpoint'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Jobs deletados: ${data['message']}');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Não autorizado. Faça login novamente.');
      } else {
        throw Exception('Erro ao deletar jobs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }
}
