import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import 'auth_service.dart';
import 'demo_repository.dart';

class ApiService {
  ApiService(this._authService);

  final AuthService _authService;

  Future<List<ChatPreview>> getChats() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'GET',
        path: '/chats',
        token: token,
      );

      if (response.statusCode != 200) {
        throw Exception('Error cargando chats (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Respuesta invalida del servidor.');
      }

      return decoded
          .whereType<Map>()
          .map(
            (m) => ChatPreview.fromJson(
              m.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
    } catch (_) {
      return DemoRepository.chats();
    }
  }

  Future<List<ChatMessage>> getMessages({
    required int chatId,
    String? sinceIso,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

        final response = await _authorizedRequestWithFallback(
        method: 'GET',
        path: '/chats/$chatId/messages',
        token: token,
        queryParameters: (sinceIso == null || sinceIso.isEmpty)
          ? null
          : <String, String>{'since': sinceIso},
        );

      if (response.statusCode != 200) {
        throw Exception('Error cargando mensajes (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Respuesta invalida del servidor.');
      }

      return decoded
          .whereType<Map>()
          .map(
            (m) => ChatMessage.fromJson(
              m.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
    } catch (_) {
      if (!DemoRepository.hasChat(chatId)) {
        return const <ChatMessage>[];
      }
      final since = sinceIso == null ? null : DateTime.tryParse(sinceIso);
      return DemoRepository.messages(chatId, since: since);
    }
  }

  Future<void> sendMessage({
    required int chatId,
    required String content,
    String type = 'TEXT',
    ChatAttachment? attachment,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'POST',
        path: '/chats/$chatId/messages',
        token: token,
        jsonBody: <String, dynamic>{
          'content': content,
          'type': type,
          if (attachment != null) 'attachment': attachment.toJson(),
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Error enviando mensaje (${response.statusCode}).');
      }
    } catch (_) {
      final sender =
          await _authService.getCurrentUser() ??
          const AppUser(id: 1, name: 'Usuario', email: '', role: 'Usuario');
      DemoRepository.appendMessage(
        chatId: chatId,
        sender: sender,
        content: content,
        type: type,
        attachment: attachment,
      );
    }
  }

  Future<ChatPreview> createChat({
    required String name,
    required bool isGroup,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'POST',
        path: '/chats',
        token: token,
        jsonBody: <String, dynamic>{
          'name': name,
          'type': isGroup ? 'GROUP' : 'PRIVATE',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo crear el chat.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw Exception('Respuesta invalida del servidor.');
      }

      return ChatPreview.fromJson(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return DemoRepository.createChat(name: name, isGroup: isGroup);
    }
  }

  Future<http.Response> _authorizedRequestWithFallback({
    required String method,
    required String path,
    required String token,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? jsonBody,
  }) async {
    Object? lastError;
    http.Response? lastNotFound;

    for (final uri in buildEndpointCandidates(
      path,
      queryParameters: queryParameters,
    )) {
      try {
        final headers = <String, String>{'Authorization': 'Bearer $token'};
        http.Response response;

        switch (method.toUpperCase()) {
          case 'GET':
            response = await http
                .get(uri, headers: headers)
                .timeout(const Duration(seconds: 8));
            break;
          case 'POST':
            headers['Content-Type'] = 'application/json';
            response = await http
                .post(
                  uri,
                  headers: headers,
                  body: jsonEncode(jsonBody ?? <String, dynamic>{}),
                )
                .timeout(const Duration(seconds: 8));
            break;
          default:
            throw Exception('Metodo HTTP no soportado: $method');
        }

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
