import '../models/chat_models.dart';

class DemoRepository {
  static final List<ChatPreview> _chats = [
    ChatPreview(
      id: 1,
      name: 'Desarrollo de Software',
      type: 'GROUP',
      lastMessage: 'Maria: subieron el build nuevo',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 10)),
      unreadCount: 3,
    ),
    ChatPreview(
      id: 2,
      name: 'Equipo UX',
      type: 'GROUP',
      lastMessage: 'Revisen el Figma actualizado',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
    ),
    ChatPreview(
      id: 3,
      name: 'Carlos Ramirez',
      type: 'PRIVATE',
      lastMessage: 'OK, lo reviso ahora mismo',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 1,
    ),
    ChatPreview(
      id: 4,
      name: 'Gerencia General',
      type: 'GROUP',
      lastMessage: 'Reunion manana a las 9am',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
    ),
  ];

  static final Map<int, List<ChatMessage>> _messagesByChat = {
    1: [
      ChatMessage(
        id: 'm1',
        senderId: 2,
        senderName: 'Maria Lopez',
        content: 'Suban el nuevo build al servidor de pruebas.',
        type: 'TEXT',
        timestamp: DateTime.now().subtract(const Duration(minutes: 55)),
        read: true,
      ),
      ChatMessage(
        id: 'm2',
        senderId: 1,
        senderName: 'Alvaro Garula',
        content: 'Perfecto, yo hago el deploy al EC2.',
        type: 'TEXT',
        timestamp: DateTime.now().subtract(const Duration(minutes: 50)),
        read: true,
      ),
      ChatMessage(
        id: 'm6',
        senderId: 2,
        senderName: 'Maria Lopez',
        content: 'Adjunto el informe del sprint.',
        type: 'FILE',
        attachment: ChatAttachment(
          fileName: 'informe_sprint.pdf',
          fileType: 'PDF',
        ),
        timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
        read: true,
      ),
    ],
    2: [
      ChatMessage(
        id: 'm3',
        senderId: 4,
        senderName: 'Lucia Martinez',
        content: 'Subi los cambios de la home en Figma.',
        type: 'TEXT',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 2, minutes: 20),
        ),
        read: true,
      ),
    ],
    3: [
      ChatMessage(
        id: 'm4',
        senderId: 3,
        senderName: 'Carlos Ramirez',
        content: 'Hola, ya viste el ticket 321?',
        type: 'TEXT',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 3, minutes: 12),
        ),
        read: false,
      ),
    ],
    4: [
      ChatMessage(
        id: 'm5',
        senderId: 5,
        senderName: 'Direccion',
        content: 'Recordatorio: reunion general manana 9:00.',
        type: 'TEXT',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        read: true,
      ),
    ],
  };

  static int _idSequence = 2000;

  static AppUser demoUserFromEmail(String email) {
    return AppUser(
      id: 1,
      name: 'Alvaro Garula',
      email: email,
      role: 'Desarrollador',
    );
  }

  static List<ChatPreview> chats() => List<ChatPreview>.from(_chats);

  static List<ChatMessage> messages(int chatId, {DateTime? since}) {
    final source = _messagesByChat[chatId] ?? const <ChatMessage>[];
    if (since == null) {
      return List<ChatMessage>.from(source);
    }
    return source.where((m) => m.timestamp.isAfter(since)).toList();
  }

  static void appendMessage({
    required int chatId,
    required AppUser sender,
    required String content,
    String type = 'TEXT',
    ChatAttachment? attachment,
  }) {
    _idSequence += 1;
    final message = ChatMessage(
      id: 'm$_idSequence',
      senderId: sender.id,
      senderName: sender.name,
      content: content,
      type: type,
      attachment: attachment,
      timestamp: DateTime.now(),
      read: false,
    );

    final list = _messagesByChat.putIfAbsent(chatId, () => <ChatMessage>[]);
    list.add(message);

    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex >= 0) {
      final chat = _chats[chatIndex];
      _chats[chatIndex] = ChatPreview(
        id: chat.id,
        name: chat.name,
        type: chat.type,
        lastMessage: '${sender.name}: $content',
        lastMessageAt: message.timestamp,
        unreadCount: chat.unreadCount,
      );
    }
  }

  static bool hasChat(int chatId) => _chats.any((c) => c.id == chatId);

  static ChatPreview createChat({
    required String name,
    required bool isGroup,
  }) {
    _idSequence += 1;
    final chat = ChatPreview(
      id: _idSequence,
      name: name,
      type: isGroup ? 'GROUP' : 'PRIVATE',
      lastMessage: 'Sin mensajes aun',
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );
    _chats.insert(0, chat);
    _messagesByChat[_idSequence] = <ChatMessage>[];
    return chat;
  }
}
