import '../models/chat_models.dart';

class DemoRepository {
  static final List<AppUser> _users = [
    const AppUser(
      id: 1,
      name: 'Alvaro Garula',
      email: 'alvaro@nexolab.com',
      role: 'DESARROLLADOR',
      cargo: 'Desarrollador Java',
      sector: 'SISTEMAS',
      status: 'DISPONIBLE',
    ),
    const AppUser(
      id: 2,
      name: 'Maria Lopez',
      email: 'maria@nexolab.com',
      role: 'LIDER',
      cargo: 'Tech Lead',
      sector: 'SISTEMAS',
      status: 'DISPONIBLE',
    ),
    const AppUser(
      id: 3,
      name: 'Carlos Ramirez',
      email: 'carlos@nexolab.com',
      role: 'DESARROLLADOR',
      cargo: 'Backend Dev',
      sector: 'SISTEMAS',
      status: 'OCUPADO',
    ),
    const AppUser(
      id: 4,
      name: 'Lucia Martinez',
      email: 'lucia@nexolab.com',
      role: 'QA',
      cargo: 'QA Engineer',
      sector: 'SISTEMAS',
      status: 'EN_REUNION',
    ),
    const AppUser(
      id: 5,
      name: 'Ana Gomez',
      email: 'ana@nexolab.com',
      role: 'HR',
      cargo: 'People Partner',
      sector: 'RRHH',
      status: 'DESCONECTADO',
    ),
  ];

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

  static final Map<int, List<ChatParticipant>> _participantsByChat = {
    1: const [
      ChatParticipant(
        id: 1,
        name: 'Alvaro Garula',
        email: 'alvaro@nexolab.com',
        role: 'ADMINISTRADOR',
      ),
      ChatParticipant(
        id: 2,
        name: 'Maria Lopez',
        email: 'maria@nexolab.com',
        role: 'MIEMBRO',
      ),
      ChatParticipant(
        id: 3,
        name: 'Carlos Ramirez',
        email: 'carlos@nexolab.com',
        role: 'MIEMBRO',
      ),
    ],
    2: const [
      ChatParticipant(
        id: 1,
        name: 'Alvaro Garula',
        email: 'alvaro@nexolab.com',
        role: 'ADMINISTRADOR',
      ),
      ChatParticipant(
        id: 4,
        name: 'Lucia Martinez',
        email: 'lucia@nexolab.com',
        role: 'MIEMBRO',
      ),
    ],
    4: const [
      ChatParticipant(
        id: 1,
        name: 'Alvaro Garula',
        email: 'alvaro@nexolab.com',
        role: 'MIEMBRO',
      ),
      ChatParticipant(
        id: 5,
        name: 'Ana Gomez',
        email: 'ana@nexolab.com',
        role: 'ADMINISTRADOR',
      ),
    ],
  };

  static AppUser _currentDemoUser = _users.first;
  static String _currentPassword = 'Demo123!';

  static int _idSequence = 2000;

  static AppUser demoUserFromEmail(String email) {
    _currentDemoUser = AppUser(
      id: _currentDemoUser.id,
      name: _currentDemoUser.name,
      email: email,
      role: _currentDemoUser.role,
      cargo: _currentDemoUser.cargo,
      sector: _currentDemoUser.sector,
      status: _currentDemoUser.status,
    );
    return _currentDemoUser;
  }

  static List<ChatPreview> chats() => List<ChatPreview>.from(_chats);

  static List<AppUser> searchUsers(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      return const <AppUser>[];
    }
    return _users
        .where(
          (u) =>
              u.id != _currentDemoUser.id &&
              (u.name.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q)),
        )
        .toList();
  }

  static AppUser? userById(int id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<AppUser> usersByIds(List<int> ids) {
    if (ids.isEmpty) {
      return const <AppUser>[];
    }
    final set = ids.toSet();
    return _users.where((u) => set.contains(u.id)).toList();
  }

  static List<ChatMessage> messages(int chatId, {DateTime? since}) {
    final source = _messagesByChat[chatId] ?? const <ChatMessage>[];
    if (since == null) {
      return List<ChatMessage>.from(source);
    }
    return source.where((m) => m.timestamp.isAfter(since)).toList();
  }

  static List<ChatMessage> searchMessages(int chatId, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const <ChatMessage>[];
    }
    return (_messagesByChat[chatId] ?? const <ChatMessage>[])
        .where((m) => m.content.toLowerCase().contains(q))
        .toList();
  }

  static List<ChatParticipant> participants(int chatId) {
    return List<ChatParticipant>.from(
      _participantsByChat[chatId] ?? const <ChatParticipant>[],
    );
  }

  static bool addParticipant(int chatId, AppUser user) {
    final chat = _chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => const ChatPreview(
        id: -1,
        name: '',
        type: 'GROUP',
        lastMessage: '',
        lastMessageAt: null,
        unreadCount: 0,
      ),
    );
    if (chat.id == -1 || !chat.isGroup) {
      return false;
    }

    final list = _participantsByChat.putIfAbsent(
      chatId,
      () => <ChatParticipant>[],
    );
    if (list.any((p) => p.id == user.id)) {
      return true;
    }

    list.add(
      ChatParticipant(
        id: user.id,
        name: user.name,
        email: user.email,
        role: 'MIEMBRO',
      ),
    );
    return true;
  }

  static bool leaveGroup(int chatId, {int? userId}) {
    final id = userId ?? _currentDemoUser.id;
    final list = _participantsByChat[chatId];
    if (list == null) {
      return false;
    }
    list.removeWhere((p) => p.id == id);
    return true;
  }

  static AppUser updateStatus(String status) {
    _currentDemoUser = AppUser(
      id: _currentDemoUser.id,
      name: _currentDemoUser.name,
      email: _currentDemoUser.email,
      role: _currentDemoUser.role,
      cargo: _currentDemoUser.cargo,
      sector: _currentDemoUser.sector,
      status: status,
    );
    return _currentDemoUser;
  }

  static bool updatePassword({required String current, required String next}) {
    if (current != _currentPassword) {
      return false;
    }
    _currentPassword = next;
    return true;
  }

  static AppUser currentUser() => _currentDemoUser;

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
    List<AppUser> members = const <AppUser>[],
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
    if (isGroup) {
      final participants = <ChatParticipant>[
        ChatParticipant(
          id: _currentDemoUser.id,
          name: _currentDemoUser.name,
          email: _currentDemoUser.email,
          role: 'ADMINISTRADOR',
        ),
        ...members.map(
          (m) => ChatParticipant(
            id: m.id,
            name: m.name,
            email: m.email,
            role: 'MIEMBRO',
          ),
        ),
      ];
      _participantsByChat[_idSequence] = participants;
    }
    return chat;
  }
}
