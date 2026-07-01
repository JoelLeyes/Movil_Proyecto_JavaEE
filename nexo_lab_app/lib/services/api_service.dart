import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/chat_models.dart';
import 'auth_service.dart';

class ApiService {
  ApiService(this._authService);

  final AuthService _authService;
  static const Duration _requestTimeout = Duration(seconds: 25);

  Exception _asApiException(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) {
      return Exception(
        'Conexión perdida. Revise su conexión o vuelva a intentarlo más tarde.',
      );
    }
    return Exception(raw);
  }

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
    } catch (e) {
      throw _asApiException(e);
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
    } catch (e) {
      throw _asApiException(e);
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
    } catch (e) {
      throw _asApiException(e);
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
    } catch (e) {
      throw _asApiException(e);
    }
  }

  Future<void> sendMessage({
    required int chatId,
    required String content,
    String type = 'TEXT',
    ChatAttachment? attachment,
    List<UploadFilePayload> attachmentFiles = const <UploadFilePayload>[],
    String? replyToMessageId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = attachmentFiles.isNotEmpty
          ? await _authorizedMultipartRequestWithFallback(
              method: 'POST',
              path: '/chats/$chatId/messages',
              token: token,
              fields: <String, String>{
                'contenido': content,
                if (replyToMessageId != null && replyToMessageId.isNotEmpty)
                  'respondaId': replyToMessageId,
              },
              files: attachmentFiles,
            )
          : await _authorizedRequestWithFallback(
              method: 'POST',
              path: '/chats/$chatId/messages',
              token: token,
              formFields: attachment == null
                  ? <String, String>{
                      'contenido': content,
                      if (replyToMessageId != null && replyToMessageId.isNotEmpty)
                        'respondaId': replyToMessageId,
                    }
                  : null,
              jsonBody: attachment != null
                  ? <String, dynamic>{
                      'contenido': content,
                      'content': content,
                      'type': type,
                      'attachment': attachment.toJson(),
                      if (replyToMessageId != null && replyToMessageId.isNotEmpty)
                        'respondaId': replyToMessageId,
                    }
                  : null,
            );

      if (response.statusCode != 201) {
        throw Exception('Error enviando mensaje (${response.statusCode}).');
      }
    } catch (e) {
      throw _asApiException(e);
    }
  }

  Future<void> reactToMessage({
    required int chatId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'POST',
        path: '/chats/$chatId/reacciones',
        token: token,
        jsonBody: <String, dynamic>{
          'msgId': messageId,
          'emoji': emoji,
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo registrar la reaccion.');
      }
    } catch (e) {
      throw _asApiException(e);
    }
  }

  Future<void> renameGroupChat({
    required int chatId,
    required String name,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'PUT',
        path: '/chats/$chatId/nombre',
        token: token,
        jsonBody: <String, dynamic>{'nombre': name},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = decodeBody(response.body);
        throw Exception(
          body['message']?.toString() ?? 'No se pudo renombrar el grupo.',
        );
      }
    } catch (e) {
      throw _asApiException(e);
    }
  }

  Future<ChatPreview> createChat({
    required String name,
    required bool isGroup,
  }) async {
    throw Exception('Conexión perdida. Revise su conexión o vuelva a intentarlo más tarde.');
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
    } catch (e) {
      throw _asApiException(e);
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
    } catch (e) {
      throw _asApiException(e);
    }
  }

  Future<String> uploadGroupPhoto({
    required int chatId,
    required UploadFilePayload photo,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedMultipartRequestWithFallback(
        method: 'POST',
        path: '/chats/$chatId/foto',
        token: token,
        fields: const <String, String>{},
        files: <UploadFilePayload>[photo],
        fileFieldName: 'foto',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = decodeBody(response.body);
        throw Exception(
          body['message']?.toString() ?? 'No se pudo actualizar la foto del grupo.',
        );
      }

      final decoded = decodeBody(response.body);
      return decoded['fotoGrupoUrl']?.toString() ?? '';
    } catch (e) {
      throw _asApiException(e);
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
    } catch (e) {
      throw _asApiException(e);
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
    } catch (e) {
      throw _asApiException(e);
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
    } catch (e) {
      throw _asApiException(e);
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
        fotoPerfilUrl: current.fotoPerfilUrl,
      );
      await _authService.saveSession(token: token, user: updated);
      return updated;
    } catch (e) {
      throw _asApiException(e);
    }
  }

  Future<AppUser> updateMyProfile({
    required String name,
    required String lastName,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedRequestWithFallback(
        method: 'PUT',
        path: '/usuarios/me',
        token: token,
        jsonBody: <String, dynamic>{
          'nombre': name,
          'apellido': lastName,
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = decodeBody(response.body);
        throw Exception(
          body['message']?.toString() ?? 'No se pudo actualizar el perfil.',
        );
      }

      final decoded = decodeBody(response.body);
      final updated = AppUser.fromJson(decoded);
      await _authService.saveSession(token: token, user: updated);
      return updated;
    } catch (e) {
      throw _asApiException(e);
    }
  }

  Future<AppUser> uploadMyPhoto({
    required UploadFilePayload photo,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay sesion activa.');
      }

      final response = await _authorizedMultipartRequestWithFallback(
        method: 'POST',
        path: '/usuarios/me/foto',
        token: token,
        fields: const <String, String>{},
        files: <UploadFilePayload>[photo],
        fileFieldName: 'foto',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = decodeBody(response.body);
        throw Exception(
          body['message']?.toString() ?? 'No se pudo actualizar la foto.',
        );
      }

      final decoded = decodeBody(response.body);
      final updated = AppUser.fromJson(decoded);
      final tokenAfter = await _authService.getToken();
      if (tokenAfter == null || tokenAfter.isEmpty) {
        throw Exception('No hay sesion activa.');
      }
      await _authService.saveSession(token: tokenAfter, user: updated);
      return updated;
    } catch (e) {
      throw _asApiException(e);
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
      throw _asApiException(e);
    }
  }

  Future<http.Response> _authorizedRequestWithFallback({
    required String method,
    required String path,
    required String token,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? jsonBody,
    Map<String, String>? formFields,
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
              .timeout(_requestTimeout);
            break;
          case 'POST':
            if (formFields != null) {
              headers['Content-Type'] = 'application/x-www-form-urlencoded';
              response = await http
                  .post(
                    uri,
                    headers: headers,
                    body: Uri(queryParameters: formFields).query,
                  )
                  .timeout(_requestTimeout);
            } else {
              headers['Content-Type'] = 'application/json';
              response = await http
                  .post(
                    uri,
                    headers: headers,
                    body: jsonEncode(jsonBody ?? <String, dynamic>{}),
                  )
                  .timeout(_requestTimeout);
            }
            break;
          case 'PUT':
            headers['Content-Type'] = 'application/json';
            response = await http
                .put(
                  uri,
                  headers: headers,
                  body: jsonEncode(jsonBody ?? <String, dynamic>{}),
                )
                .timeout(_requestTimeout);
            break;
          case 'DELETE':
            response = await http
              .delete(uri, headers: headers)
              .timeout(_requestTimeout);
            break;
          default:
            throw Exception('Metodo HTTP no soportado: $method');
        }

        if (response.statusCode == 404) {
          lastNotFound = response;
          continue;
        }

        return response;
      } on TimeoutException {
        lastError = Exception(
          'Timeout al conectar con $uri. El servidor tardó más de ${_requestTimeout.inSeconds}s en responder.',
        );
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

  Future<http.Response> _authorizedMultipartRequestWithFallback({
    required String method,
    required String path,
    required String token,
    Map<String, String>? fields,
    List<UploadFilePayload> files = const <UploadFilePayload>[],
    String fileFieldName = 'archivo',
  }) async {
    Object? lastError;
    http.Response? lastNotFound;

    for (final uri in buildEndpointCandidates(path)) {
      try {
        final request = http.MultipartRequest(method.toUpperCase(), uri)
          ..headers['Authorization'] = 'Bearer $token';

        fields?.forEach((key, value) {
          request.fields[key] = value;
        });

        for (final file in files) {
          request.files.add(
            http.MultipartFile.fromBytes(
              fileFieldName,
              file.bytes,
              filename: file.fileName,
              contentType: _mediaTypeForFile(file.fileName, file.mimeType),
            ),
          );
        }

        final streamed = await request.send().timeout(_requestTimeout);
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 404) {
          lastNotFound = response;
          continue;
        }

        return response;
      } on TimeoutException {
        lastError = Exception(
          'Timeout al conectar con $uri. El servidor tardó más de ${_requestTimeout.inSeconds}s en responder.',
        );
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

  MediaType _mediaTypeForFile(String fileName, String? mimeType) {
    if (mimeType != null && mimeType.contains('/')) {
      final parts = mimeType.split('/');
      if (parts.length == 2) {
        return MediaType(parts[0], parts[1]);
      }
    }

    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.gif')) {
      return MediaType('image', 'gif');
    }
    if (lower.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }
    return MediaType('application', 'octet-stream');
  }
}
