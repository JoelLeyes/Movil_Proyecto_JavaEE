import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import 'auth_service.dart';
import 'demo_repository.dart';

class ApiService {
  ApiService(this._authService);

  final AuthService _authService;

  Future<List<AppUser>> searchUsers(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      return const <AppUser>[];
    }

    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'GET',
        path: '/usuarios',
        token: token,
        queryParameters: <String, String>{'q': q},
      );

      if (response.statusCode != 200) {
        throw Exception('Error buscando usuarios (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return const <AppUser>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (u) => AppUser.fromJson(u.map((k, v) => MapEntry(k.toString(), v))),
          )
          .toList();
    } catch (_) {
      return DemoRepository.searchUsers(q);
    }
  }

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

  Future<List<ChatMessage>> searchMessages({
    required int chatId,
    required String query,
  }) async {
    final q = query.trim();
    if (q.length < 2) {
      return const <ChatMessage>[];
    }

    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'GET',
        path: '/chats/$chatId/messages',
        token: token,
        queryParameters: <String, String>{'search': q},
      );

      if (response.statusCode != 200) {
        throw Exception('Error buscando mensajes (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return const <ChatMessage>[];
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
      return DemoRepository.searchMessages(chatId, q);
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
          'contenido': content,
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
    if (!isGroup) {
      return DemoRepository.createChat(name: name, isGroup: false);
    }

    return DemoRepository.createChat(name: name, isGroup: true);
  }

  Future<ChatPreview> createGroupChat({
    required String name,
    required List<int> memberIds,
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
          'tipo': 'GRUPAL',
          'nombre': name,
          'miembros': memberIds,
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo crear el grupo.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw Exception('Respuesta invalida del servidor.');
      }

      return ChatPreview.fromJson(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      final members = DemoRepository.usersByIds(memberIds);
      return DemoRepository.createChat(
        name: name,
        isGroup: true,
        members: members,
      );
    }
  }

  Future<ChatPreview> createPrivateChat({required AppUser otherUser}) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'POST',
        path: '/chats',
        token: token,
        jsonBody: <String, dynamic>{'otroUsuarioId': otherUser.id},
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
      return DemoRepository.createChat(name: otherUser.name, isGroup: false);
    }
  }

  Future<List<ChatParticipant>> getParticipants({required int chatId}) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'GET',
        path: '/chats/$chatId/participantes',
        token: token,
      );

      if (response.statusCode != 200) {
        throw Exception('No se pudieron cargar participantes.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return const <ChatParticipant>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (p) => ChatParticipant.fromJson(
              p.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
    } catch (_) {
      return DemoRepository.participants(chatId);
    }
  }

  Future<void> addParticipant({
    required int chatId,
    required int userId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'POST',
        path: '/chats/$chatId/participantes',
        token: token,
        jsonBody: <String, dynamic>{'usuarioId': userId},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo agregar miembro.');
      }
    } catch (_) {
      final user = DemoRepository.userById(userId);
      if (user != null) {
        DemoRepository.addParticipant(chatId, user);
      }
    }
  }

  Future<void> leaveGroup({required int chatId}) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'DELETE',
        path: '/chats/$chatId/participantes',
        token: token,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo abandonar el grupo.');
      }
    } catch (_) {
      DemoRepository.leaveGroup(chatId);
    }
  }

  Future<AppUser> updateMyStatus(String status) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'PUT',
        path: '/usuarios/me/estado',
        token: token,
        jsonBody: <String, dynamic>{'tipoEstado': status},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo actualizar el estado.');
      }

      final current = await _authService.getCurrentUser();
      if (current == null) {
        throw Exception('Usuario no disponible.');
      }

      final updated = AppUser(
        id: current.id,
        name: current.name,
        email: current.email,
        role: current.role,
        cargo: current.cargo,
        sector: current.sector,
        status: status,
      );
      await _authService.saveSession(token: token, user: updated);
      return updated;
    } catch (_) {
      final updated = DemoRepository.updateStatus(status);
      final token = await _authService.getToken();
      if (token != null && token.isNotEmpty) {
        await _authService.saveSession(token: token, user: updated);
      }
      return updated;
    }
  }

  Future<void> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'PUT',
        path: '/usuarios/me/password',
        token: token,
        jsonBody: <String, dynamic>{
          'passwordActual': currentPassword,
          'passwordNueva': newPassword,
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = decodeBody(response.body);
        throw Exception(
          body['message']?.toString() ?? 'No se pudo cambiar la contrasena.',
        );
      }
    } catch (e) {
      final ok = DemoRepository.updatePassword(
        current: currentPassword,
        next: newPassword,
      );
      if (!ok) {
        throw Exception(
          e.toString().contains('Exception:')
              ? e.toString().replaceFirst('Exception: ', '')
              : 'La contrasena actual no es correcta.',
        );
      }
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
          case 'PUT':
            headers['Content-Type'] = 'application/json';
            response = await http
                .put(
                  uri,
                  headers: headers,
                  body: jsonEncode(jsonBody ?? <String, dynamic>{}),
                )
                .timeout(const Duration(seconds: 8));
            break;
          case 'DELETE':
            response = await http
                .delete(uri, headers: headers)
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
