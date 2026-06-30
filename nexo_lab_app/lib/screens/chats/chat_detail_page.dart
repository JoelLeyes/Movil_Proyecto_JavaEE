import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/chat_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/formatters.dart';
import 'chats_page.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.apiService,
    required this.authService,
    required this.chat,
  });

  final ApiService apiService;
  final AuthService authService;
  final ChatPreview chat;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _pollTimer;
  Timer? _typingTimer;
  Timer? _searchDebounce;
  bool _pollingInFlight = false;
  bool _loading = true;
  bool _sending = false;
  bool _showTyping = false;
  bool _searchVisible = false;
  String? _error;
  AppUser? _me;
  List<ChatMessage> _messages = const <ChatMessage>[];
  ChatMessage? _replyToMessage;
  late String _chatName;

  List<String> _searchMatchIds = const <String>[];
  int _searchIndex = -1;

  List<ChatParticipant> _participants = const <ChatParticipant>[];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _chatName = widget.chat.name;
    _loadInitial();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _searchDebounce?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollMessages();
    });
  }

  Future<void> _loadInitial() async {
    _me = await widget.authService.getCurrentUser();
    if (widget.chat.isGroup) {
      await _loadParticipants();
    }
    await _loadMessages();
  }

  Future<void> _loadParticipants() async {
    final list = await widget.apiService.getParticipants(
      chatId: widget.chat.id,
    );
    if (!mounted) {
      return;
    }
    final myId = _me?.id;
    final mine = list.where((p) => p.id == myId).toList();
    setState(() {
      _participants = list;
      _isAdmin = mine.isNotEmpty && mine.first.isAdmin;
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messages = await widget.apiService.getMessages(
        chatId: widget.chat.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pollMessages() async {
    if (_loading || _sending || _pollingInFlight) {
      return;
    }

    _pollingInFlight = true;
    try {
      final last = _messages.isNotEmpty ? _messages.last.timestamp : null;
      final sinceIso = last == null ? null : toBackendLocalIso(last);
      final incoming = await widget.apiService.getMessages(
        chatId: widget.chat.id,
        sinceIso: sinceIso,
      );
      if (!mounted || incoming.isEmpty) {
        return;
      }

      final merged = _mergeMessages(_messages, incoming);
      if (merged.length == _messages.length) {
        return;
      }

      final shouldStickToBottom = _isNearBottom();
      setState(() {
        _messages = merged;
      });

      if (shouldStickToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    } catch (_) {
      // Polling silencioso.
    } finally {
      _pollingInFlight = false;
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    return _scrollController.position.extentAfter < 120;
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    final merged = <ChatMessage>[...current];
    final keys = current.map((m) => m.id).toSet();
    for (final message in incoming) {
      if (keys.add(message.id)) {
        merged.add(message);
      }
    }
    return merged;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await widget.apiService.sendMessage(
        chatId: widget.chat.id,
        content: content,
        replyToMessageId: _replyToMessage?.id,
      );
      _messageController.clear();
      _replyToMessage = null;
      await _loadMessages();
      _simulateTyping();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_sending) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final attachments = result.files
        .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
        .map(
          (file) => UploadFilePayload(
            fileName: file.name,
            bytes: file.bytes!,
          ),
        )
        .toList();

    if (attachments.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await widget.apiService.sendMessage(
        chatId: widget.chat.id,
        content: _messageController.text.trim(),
        attachmentFiles: attachments,
        replyToMessageId: _replyToMessage?.id,
      );
      _messageController.clear();
      _replyToMessage = null;
      await _loadMessages();
      _simulateTyping();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _reactToMessage(ChatMessage message) async {
    const emojis = <String>['👍', '🔥', '✅', '🎉', '😊', '🙌'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emojis
                  .map(
                    (value) => ActionChip(
                      label: Text(value, style: const TextStyle(fontSize: 22)),
                      onPressed: () => Navigator.of(context).pop(value),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );

    if (emoji == null) {
      return;
    }

    await widget.apiService.reactToMessage(
      chatId: widget.chat.id,
      messageId: message.id,
      emoji: emoji,
    );
    await _loadMessages();
  }

  Future<void> _renameGroup() async {
    final controller = TextEditingController(text: _chatName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renombrar grupo'),
          content: TextField(
            controller: controller,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Nuevo nombre',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || result.isEmpty) {
      return;
    }

    await widget.apiService.renameGroupChat(chatId: widget.chat.id, name: result);
    if (!mounted) {
      return;
    }
    setState(() {
      _chatName = result;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grupo renombrado.')),
    );
  }

  Future<void> _openMessageActions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Responder'),
                onTap: () => Navigator.of(context).pop('reply'),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('Reaccionar'),
                onTap: () => Navigator.of(context).pop('react'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'reply') {
      setState(() {
        _replyToMessage = message;
      });
    } else if (action == 'react') {
      await _reactToMessage(message);
    }
  }

  void _openEmojiPicker() {
    const emojis = <String>['👍', '🔥', '✅', '🎉', '😊', '🙌'];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emojis
                  .map(
                    (emoji) => ActionChip(
                      label: Text(emoji, style: const TextStyle(fontSize: 22)),
                      onPressed: () {
                        _messageController.text += emoji;
                        Navigator.of(context).pop();
                        setState(() {});
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  void _simulateTyping() {
    if (!widget.chat.isGroup) {
      return;
    }
    _typingTimer?.cancel();
    setState(() {
      _showTyping = true;
    });
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showTyping = false;
      });
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
        _searchMatchIds = const <String>[];
        _searchIndex = -1;
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _searchMatchIds = const <String>[];
        _searchIndex = -1;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final result = await widget.apiService.searchMessages(
        chatId: widget.chat.id,
        query: query,
      );
      if (!mounted) {
        return;
      }
      final merged = _mergeMessages(_messages, result);
      setState(() {
        _messages = merged;
        _searchMatchIds = result.map((m) => m.id).toList();
        _searchIndex = _searchMatchIds.isEmpty ? -1 : 0;
      });
      _scrollToCurrentSearch();
    });
  }

  void _moveSearch(int direction) {
    if (_searchMatchIds.isEmpty) {
      return;
    }
    setState(() {
      _searchIndex =
          (_searchIndex + direction + _searchMatchIds.length) %
          _searchMatchIds.length;
    });
    _scrollToCurrentSearch();
  }

  void _scrollToCurrentSearch() {
    if (_searchIndex < 0 || _searchIndex >= _searchMatchIds.length) {
      return;
    }
    final id = _searchMatchIds[_searchIndex];
    final index = _messages.indexWhere((m) => m.id == id);
    if (index < 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final target = (index * 88.0).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ).toDouble();
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openParticipants() async {
    await _loadParticipants();
    if (!mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  'Participantes (${_participants.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: _participants.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _participants[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(initials(p.name))),
                        title: Text(p.name),
                        subtitle: Text(p.email),
                        trailing: p.isAdmin
                            ? const Chip(label: Text('Admin'))
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddParticipant() async {
    final searchController = TextEditingController();
    List<AppUser> searchResults = const <AppUser>[];
    bool searching = false;
    String? searchError;
    var dialogOpen = true;
    Timer? searchDebounce;

    final dialogFuture = showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> runSearch(String raw) async {
              final query = raw.trim();
              searchDebounce?.cancel();

              if (query.length < 2) {
                setModalState(() {
                  searchResults = const <AppUser>[];
                  searching = false;
                  searchError = null;
                });
                return;
              }

              setModalState(() {
                searching = true;
                searchError = null;
              });

              searchDebounce = Timer(const Duration(milliseconds: 350), () async {
                try {
                  final results = await widget.apiService.searchUsers(query);
                  if (!modalContext.mounted || !dialogOpen) return;
                  final currentIds = _participants.map((p) => p.id).toSet();
                  final available = results
                      .where((u) => !currentIds.contains(u.id))
                      .toList();
                  setModalState(() {
                    searching = false;
                    searchResults = available;
                    searchError = available.isEmpty
                        ? 'Sin usuarios disponibles para agregar.'
                        : null;
                  });
                } catch (e) {
                  if (!modalContext.mounted || !dialogOpen) return;
                  setModalState(() {
                    searching = false;
                    searchResults = const <AppUser>[];
                    searchError = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              });
            }

            final dialogWidth =
                (MediaQuery.of(modalContext).size.width - 32).clamp(
                  280.0,
                  420.0,
                ).toDouble();

            return AlertDialog(
              title: const Text('Agregar miembro'),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: runSearch,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre o email',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      )
                    else if (searchError != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          searchError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    else if (searchController.text.trim().length < 2)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Escribe al menos 2 caracteres.'),
                      )
                    else if (searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Sin usuarios disponibles para agregar.'),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          itemBuilder: (_, index) {
                            final user = searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(user.initials),
                              ),
                              title: Text(user.name),
                              subtitle: Text(user.email),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add),
                                onPressed: () async {
                                  try {
                                    await widget.apiService.addParticipant(
                                      chatId: widget.chat.id,
                                      userId: user.id,
                                    );
                                    if (!modalContext.mounted || !dialogOpen) {
                                      return;
                                    }
                                    dialogOpen = false;
                                    searchDebounce?.cancel();
                                    Navigator.of(dialogContext).pop();
                                    await _loadParticipants();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${user.name} agregado al grupo.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e.toString().replaceFirst('Exception: ', ''),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    dialogOpen = false;
                    searchDebounce?.cancel();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );

    dialogFuture.whenComplete(() {
      dialogOpen = false;
      searchDebounce?.cancel();
    });
    await dialogFuture;
    searchController.dispose();
  }

  Future<void> _leaveGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abandonar grupo'),
        content: const Text('No podras volver a ver los mensajes del grupo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }

    await widget.apiService.leaveGroup(chatId: widget.chat.id);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChatsPage(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  Text _searchCounter() {
    if (_searchController.text.trim().isEmpty) {
      return const Text('');
    }
    if (_searchMatchIds.isEmpty) {
      return const Text('Sin resultados', style: TextStyle(fontSize: 12));
    }
    return Text(
      '${_searchIndex + 1} de ${_searchMatchIds.length}',
      style: const TextStyle(fontSize: 12),
    );
  }

  bool _isCurrentSearchHit(String messageId) {
    if (_searchIndex < 0 || _searchIndex >= _searchMatchIds.length) {
      return false;
    }
    return _searchMatchIds[_searchIndex] == messageId;
  }

  Widget _buildHighlightedText(String text, bool isMine) {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      return Text(
        text,
        style: TextStyle(color: isMine ? Colors.white : Colors.black87),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(color: isMine ? Colors.white : Colors.black87),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            color: isMine ? Colors.black : Colors.black,
            backgroundColor: Colors.amberAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = index + query.length;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(color: isMine ? Colors.white : Colors.black87),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_chatName),
            Text(
              widget.chat.isGroup
                  ? '${_participants.isEmpty ? '' : '${_participants.length} participantes · '}Chat grupal'
                  : 'Chat directo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _toggleSearch, icon: const Icon(Icons.search)),
          if (widget.chat.isGroup)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'participants') {
                  await _openParticipants();
                }
                if (value == 'add') {
                  await _openAddParticipant();
                }
                if (value == 'rename') {
                  await _renameGroup();
                }
                if (value == 'leave') {
                  await _leaveGroup();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'participants',
                  child: Text('Ver participantes'),
                ),
                if (_isAdmin)
                  const PopupMenuItem(
                    value: 'add',
                    child: Text('Agregar miembro'),
                  ),
                if (_isAdmin)
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Renombrar grupo'),
                  ),
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Abandonar grupo'),
                ),
              ],
            ),
          IconButton(onPressed: _loadMessages, icon: const Icon(Icons.refresh)),
        ],
        bottom: _searchVisible
            ? PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Buscar en el chat...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _searchCounter(),
                      IconButton(
                        onPressed: _searchMatchIds.isEmpty
                            ? null
                            : () => _moveSearch(-1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        onPressed: _searchMatchIds.isEmpty
                            ? null
                            : () => _moveSearch(1),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(child: Text('No hay mensajes en este chat.'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = _me != null && message.senderId == _me!.id;
                      final isCurrent = _isCurrentSearchHit(message.id);

                      return GestureDetector(
                        onLongPress: () => _openMessageActions(message),
                        child: Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFF185FA5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: isCurrent
                                  ? Border.all(color: Colors.amber, width: 2)
                                  : (isMine
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFE0E0E0),
                                          )),
                            ),
                            child: Column(
                              crossAxisAlignment: isMine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (widget.chat.isGroup && !isMine)
                                  Text(
                                    message.senderName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF185FA5),
                                    ),
                                  ),
                                if (message.replyTo != null)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : const Color(0xFFF5F7FB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isMine
                                            ? Colors.white.withValues(alpha: 0.2)
                                            : const Color(0xFFE4E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      message.replyTo!.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMine
                                            ? Colors.white.withValues(alpha: 0.88)
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                _buildHighlightedText(message.content, isMine),
                                if (message.attachment != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : const Color(0xFFF0F4F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          message.attachment!.isImage
                                              ? Icons.image_outlined
                                              : Icons.picture_as_pdf_outlined,
                                          size: 20,
                                          color: isMine
                                              ? Colors.white
                                              : const Color(0xFF185FA5),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            message.attachment!.fileName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isMine
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (message.reactions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: message.reactions
                                          .map(
                                            (reaction) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: reaction.mine
                                                    ? const Color(0xFFDAECFF)
                                                    : const Color(0xFFF3F4F6),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: reaction.mine
                                                      ? const Color(0xFF8BB8E8)
                                                      : const Color(0xFFE5E7EB),
                                                ),
                                              ),
                                              child: Text(
                                                '${reaction.emoji} ${reaction.count}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  formatTime(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMine
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_showTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_chatName.split(' ').first} esta escribiendo...',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyToMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.reply, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _replyToMessage!.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _replyToMessage = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _sending ? null : _pickAndSendAttachment,
                        icon: const Icon(Icons.attach_file),
                      ),
                      IconButton(
                        onPressed: _openEmojiPicker,
                        icon: const Icon(Icons.emoji_emotions_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sending ? null : _sendMessage,
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
