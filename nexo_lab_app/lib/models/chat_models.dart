class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String email;
  final String role;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) {
      return name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase();
    }
    return 'NL';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: toIntValue(json['id']) ?? 0,
      name: json['name']?.toString() ?? 'Usuario',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Usuario',
    );
  }
}

class ChatPreview {
  const ChatPreview({
    required this.id,
    required this.name,
    required this.type,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final int id;
  final String name;
  final String type;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get isGroup => type.toUpperCase() == 'GROUP';

  factory ChatPreview.fromJson(Map<String, dynamic> json) {
    final rawDate =
        json['lastMessageAt']?.toString() ??
        json['updatedAt']?.toString() ??
        json['last_message_at']?.toString();
    final rawType =
        json['type']?.toString() ??
        json['chatType']?.toString() ??
        (((json['isGroup'] ?? false) == true) ? 'GROUP' : 'PRIVATE');

    return ChatPreview(
      id: toIntValue(json['id']) ?? 0,
      name: json['name']?.toString() ?? 'Sin nombre',
      type: rawType,
      lastMessage:
          json['lastMessage']?.toString() ??
          json['preview']?.toString() ??
          'Sin mensajes aun',
      lastMessageAt: rawDate == null ? null : DateTime.tryParse(rawDate),
      unreadCount:
          toIntValue(json['unreadCount']) ??
          toIntValue(json['unread']) ??
          0,
    );
  }
}

class ChatAttachment {
  const ChatAttachment({
    required this.fileName,
    required this.fileType,
  });

  final String fileName;
  final String fileType;

  bool get isImage => fileType.toUpperCase() == 'IMAGE';

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'fileType': fileType,
    'filename': fileName,
  };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      fileName:
          json['fileName']?.toString() ??
          json['filename']?.toString() ??
          json['name']?.toString() ??
          'archivo',
      fileType:
          json['fileType']?.toString() ??
          json['mimeType']?.toString() ??
          json['type']?.toString() ??
          'FILE',
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.attachment,
    required this.timestamp,
    required this.read,
  });

  final String id;
  final int senderId;
  final String senderName;
  final String content;
  final String type;
  final ChatAttachment? attachment;
  final DateTime timestamp;
  final bool read;

  bool get isFile => type.toUpperCase() == 'FILE';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawTimestamp =
        json['timestamp']?.toString() ??
        json['sentAt']?.toString() ??
        json['createdAt']?.toString();
    final rawAttachment = json['attachment'] ?? json['file'];
    final sender = json['sender'];

    return ChatMessage(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      senderId:
          toIntValue(json['senderId']) ??
          (sender is Map ? toIntValue(sender['id']) : null) ??
          toIntValue(json['userId']) ??
          0,
      senderName:
          json['senderName']?.toString() ??
          (sender is Map ? sender['name']?.toString() : null) ??
          json['author']?.toString() ??
          'Usuario',
      content:
          json['content']?.toString() ??
          json['message']?.toString() ??
          json['text']?.toString() ??
          '',
      type:
          json['type']?.toString() ??
          ((rawAttachment == null) ? 'TEXT' : 'FILE'),
      attachment: rawAttachment is Map
          ? ChatAttachment.fromJson(
              rawAttachment.map((k, v) => MapEntry(k.toString(), v)),
            )
          : null,
      timestamp: DateTime.tryParse(rawTimestamp ?? '') ?? DateTime.now(),
      read: toBoolValue(json['read']) ?? toBoolValue(json['isRead']) ?? false,
    );
  }
}

int? toIntValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool? toBoolValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final lowered = value.trim().toLowerCase();
    if (lowered == 'true' || lowered == '1') {
      return true;
    }
    if (lowered == 'false' || lowered == '0') {
      return false;
    }
  }
  if (value is num) {
    return value != 0;
  }
  return null;
}
