import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import 'demo_repository.dart';

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://nexolab.cloud-ip.cc/api',
  );

  static List<String> candidateBaseUrls() {
    final normalized = _normalizeBaseUrl(baseUrl);
    final hasApiSuffix = normalized.toLowerCase().endsWith('/api');

    if (hasApiSuffix) {
      final legacy = normalized.substring(0, normalized.length - 4);
      return <String>{normalized, _normalizeBaseUrl(legacy)}.toList();
    }

    return <String>{normalized, '$normalized/api'}.toList();
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'http://nexolab.cloud-ip.cc/api';
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'current_user';
  static const String demoToken = 'demo-token';

  Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<bool> isDemoSession() async {
    final token = await getToken();
    return token == demoToken;
  }

  Future<AppUser?> getCurrentUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return AppUser.fromJson(decoded.map((k, v) => MapEntry(k.toString(), v)));
  }

  Future<void> saveSession({
    required String token,
    required AppUser user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _postJsonWithApiFallback(
        '/auth/login',
        <String, dynamic>{'email': email, 'password': password},
      );

      final body = decodeBody(response.body);
      if (response.statusCode != 200) {
        final message =
            body['message']?.toString() ?? 'No se pudo iniciar sesion.';
        throw Exception(message);
      }

      final token = body['token']?.toString() ?? '';
      final rawUser = body['user'];
      if (token.isEmpty || rawUser is! Map) {
        throw Exception('Respuesta de autenticacion invalida.');
      }

      final user = AppUser.fromJson(
        rawUser.map((k, v) => MapEntry(k.toString(), v)),
      );
      await saveSession(token: token, user: user);
      return user;
    } catch (e) {
      final error = e.toString().toLowerCase();
      final isConnectionIssue =
          error.contains('timed out') ||
          error.contains('socket') ||
          error.contains('failed host lookup') ||
          error.contains('no se pudo conectar');

      if (!isConnectionIssue) {
        rethrow;
      }

      final demoUser = DemoRepository.demoUserFromEmail(email);
      await saveSession(token: demoToken, user: demoUser);
      return demoUser;
    }
  }

  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final fullName = name.trim();
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final nombre = parts.isEmpty ? fullName : parts.first;
    final apellido = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    try {
      final response = await _postJsonWithApiFallback(
        '/auth/register',
        <String, dynamic>{
          'nombre': nombre,
          'apellido': apellido,
          'name': name,
          'email': email,
          'password': password,
        },
      );

      final body = decodeBody(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['message']?.toString() ??
            'Usuario registrado correctamente.';
      }
      throw Exception(body['message']?.toString() ?? 'No se pudo registrar.');
    } catch (_) {
      return 'Servidor AWS apagado. Cuenta creada en modo demo.';
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await _postJsonWithApiFallback(
        '/auth/forgot-password',
        <String, dynamic>{'email': email},
      );

      final body = decodeBody(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['message']?.toString() ?? 'Enlace enviado.';
      }
      throw Exception(body['message']?.toString() ?? 'No se pudo enviar.');
    } catch (_) {
      return 'Servidor AWS apagado. Simulamos envio de recuperacion.';
    }
  }

  Future<http.Response> _postJsonWithApiFallback(
    String path,
    Map<String, dynamic> payload,
  ) async {
    Object? lastError;
    http.Response? lastNotFound;

    for (final uri in buildEndpointCandidates(path)) {
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 404) {
          lastNotFound = response;
          continue;
        }
        return response;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastNotFound != null) {
      return lastNotFound;
    }

    if (lastError != null) {
      throw Exception(lastError.toString());
    }

    throw Exception('No se pudo conectar con el backend.');
  }
}

List<Uri> buildEndpointCandidates(
  String path, {
  Map<String, String>? queryParameters,
}) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  final normalizedQuery =
      (queryParameters == null || queryParameters.isEmpty)
      ? null
      : queryParameters;

  return ApiConfig.candidateBaseUrls().map((baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final joinedPath = '$basePath$normalizedPath';

    return baseUri.replace(path: joinedPath, queryParameters: normalizedQuery);
  }).toList();
}

Map<String, dynamic> decodeBody(String body) {
  if (body.isEmpty) {
    return <String, dynamic>{};
  }
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}
