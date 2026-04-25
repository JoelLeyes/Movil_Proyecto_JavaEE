import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_notification_service.dart';
import '../../utils/formatters.dart';
import '../auth/welcome_page.dart';
import '../profile/profile_page.dart';
import 'chat_detail_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  late final ApiService _apiService;
  List<ChatPreview> _allChats = const <ChatPreview>[];
  bool _loading = true;
  bool _isDemoMode = false;
  String _search = '';
  String _tab = 'all';
  String? _error;
  AppUser? _user;
  Timer? _refreshTimer;
  Map<int, ChatPreview> _chatSnapshot = <int, ChatPreview>{};

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    _bootstrap();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadChats(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _user = await widget.authService.getCurrentUser();
    _isDemoMode = await widget.authService.isDemoSession();
    await LocalNotificationService.instance.requestPermissions();
    await _loadChats();
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final chats = await _apiService.getChats();
      if (!mounted) {
        return;
      }

      await _notifyIncomingMessages(chats);

      setState(() {
        _allChats = chats;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
        });
      }
      if (mounted && silent) {
        setState(() {});
      }
    }
  }

  Future<void> _notifyIncomingMessages(List<ChatPreview> chats) async {
    final nextSnapshot = <int, ChatPreview>{
      for (final chat in chats) chat.id: chat,
    };

    if (_isDemoMode || _chatSnapshot.isEmpty) {
      _chatSnapshot = nextSnapshot;
      return;
    }

    for (final chat in chats) {
      final previous = _chatSnapshot[chat.id];
      if (previous == null) {
        continue;
      }

      final unreadIncreased = chat.unreadCount > previous.unreadCount;
      final previousTime =
          previous.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final currentTime = chat.lastMessageAt;
      final hasNewerTimestamp =
          currentTime != null && currentTime.isAfter(previousTime);
      final textChanged = chat.lastMessage != previous.lastMessage;

      if (unreadIncreased || (hasNewerTimestamp && textChanged)) {
        await LocalNotificationService.instance.showIncomingMessage(
          chatId: chat.id,
          chatName: chat.name,
          messagePreview: chat.lastMessage,
          unreadCount: chat.unreadCount,
        );
      }
    }

    _chatSnapshot = nextSnapshot;
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WelcomePage(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  Future<void> _openCreateOptions() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Nueva conversacion privada'),
                onTap: () => Navigator.of(context).pop('private'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Nuevo grupo'),
                onTap: () => Navigator.of(context).pop('group'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (value == 'private') {
      await _openCreatePrivateChatDialog();
      return;
    }
    if (value == 'group') {
      await _openCreateGroupDialog();
    }
  }

  Future<void> _openCreatePrivateChatDialog() async {
    final searchController = TextEditingController();
    List<AppUser> searchResults = const <AppUser>[];
    bool searching = false;
    int activeSearchId = 0;

    final created = await showDialog<ChatPreview>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runSearch(String raw) async {
              final query = raw.trim();
              activeSearchId += 1;
              final searchId = activeSearchId;

              if (query.length < 2) {
                setModalState(() {
                  searching = false;
                  searchResults = const <AppUser>[];
                });
                return;
              }

              setModalState(() {
                searching = true;
              });

              final results = await _apiService.searchUsers(query);
              if (!context.mounted || searchId != activeSearchId) {
                return;
              }

              setModalState(() {
                searching = false;
                searchResults = results;
              });
            }

            return AlertDialog(
              title: const Text('Nueva conversacion'),
              content: SizedBox(
                width: 420,
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
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      )
                    else if (searchController.text.trim().length < 2)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Escribe al menos 2 caracteres.'),
                      )
                    else if (searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No se encontraron usuarios.'),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text(user.initials)),
                              title: Text(user.name),
                              subtitle: Text(user.email),
                              onTap: () async {
                                final chat = await _apiService
                                    .createPrivateChat(otherUser: user);
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(context).pop(chat);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
    searchController.dispose();

    if (created == null || !mounted) {
      return;
    }

    await _loadChats();
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          apiService: _apiService,
          authService: widget.authService,
          chat: created,
        ),
      ),
    );
  }

  Future<void> _openCreateGroupDialog() async {
    final nameController = TextEditingController();
    final searchController = TextEditingController();
    final selected = <AppUser>[];
    List<AppUser> searchResults = const <AppUser>[];
    bool searching = false;
    int step = 1;

    final created = await showDialog<ChatPreview>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runSearch(String raw) async {
              final query = raw.trim();
              if (query.length < 2) {
                setModalState(() {
                  searchResults = const <AppUser>[];
                  searching = false;
                });
                return;
              }
              setModalState(() => searching = true);
              final results = await _apiService.searchUsers(query);
              if (!context.mounted) {
                return;
              }
              setModalState(() {
                searching = false;
                searchResults = results
                    .where((u) => !selected.any((s) => s.id == u.id))
                    .toList();
              });
            }

            return AlertDialog(
              title: const Text('Nuevo grupo'),
              content: SizedBox(
                width: 460,
                child: step == 1
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del grupo',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                if (nameController.text.trim().length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'El nombre debe tener al menos 2 caracteres.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => step = 2);
                              },
                              child: const Text('Siguiente'),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Miembros seleccionados: ${selected.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (selected.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selected
                                  .map(
                                    (u) => Chip(
                                      label: Text(u.name),
                                      onDeleted: () {
                                        setModalState(() {
                                          selected.removeWhere(
                                            (s) => s.id == u.id,
                                          );
                                          searchResults = searchResults
                                              .where(
                                                (r) => !selected.any(
                                                  (s) => s.id == r.id,
                                                ),
                                              )
                                              .toList();
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            )
                          else
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No agregaste miembros aun.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: searchController,
                            onChanged: runSearch,
                            decoration: const InputDecoration(
                              labelText: 'Buscar usuarios',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (searching)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: searchResults.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        child: Text(
                                          'Escribe para buscar miembros.',
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: searchResults.length,
                                      itemBuilder: (context, index) {
                                        final user = searchResults[index];
                                        return ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            child: Text(user.initials),
                                          ),
                                          title: Text(user.name),
                                          subtitle: Text(user.email),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            onPressed: () {
                                              setModalState(() {
                                                selected.add(user);
                                                searchResults.removeWhere(
                                                  (r) => r.id == user.id,
                                                );
                                              });
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
                if (step == 2)
                  TextButton(
                    onPressed: () => setModalState(() => step = 1),
                    child: const Text('Atras'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                if (step == 2)
                  FilledButton(
                    onPressed: () async {
                      final chat = await _apiService.createGroupChat(
                        name: nameController.text.trim(),
                        memberIds: selected.map((u) => u.id).toList(),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pop(chat);
                    },
                    child: const Text('Crear grupo'),
                  ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    searchController.dispose();

    if (created == null || !mounted) {
      return;
    }

    await _loadChats();
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          apiService: _apiService,
          authService: widget.authService,
          chat: created,
        ),
      ),
    );
  }

  List<ChatPreview> get _filteredChats {
    return _allChats.where((chat) {
      final search = _search.toLowerCase();
      final matchesSearch =
          chat.name.toLowerCase().contains(search) ||
          chat.lastMessage.toLowerCase().contains(search);
      final matchesTab =
          _tab == 'all' ||
          (_tab == 'group' && chat.isGroup) ||
          (_tab == 'private' && !chat.isGroup);
      return matchesSearch && matchesTab;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NexoLab'),
        actions: [
          if (_user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: CircleAvatar(
                  radius: 16,
                  child: Text(
                    _user!.initials,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfilePage(authService: widget.authService),
                    ),
                  )
                  .then((_) => _bootstrap());
            },
            icon: const Icon(Icons.person),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          if (_isDemoMode)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3CD),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(
                'Modo demo activo: viendo datos simulados. Cuando el servidor este encendido, inicia sesion de nuevo para usar datos reales.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Buscar conversaciones...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Todos')),
                ButtonSegment(value: 'group', label: Text('Grupos')),
                ButtonSegment(value: 'private', label: Text('Directos')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadChats,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredChats.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Sin conversaciones aun')),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _filteredChats.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final chat = _filteredChats[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(initials(chat.name)),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(chat.name)),
                              if (chat.isGroup)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Chip(
                                    label: Text(
                                      'grupo',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(chat.lastMessage),
                          trailing: chat.unreadCount > 0
                              ? CircleAvatar(
                                  radius: 12,
                                  child: Text(
                                    chat.unreadCount.toString(),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                )
                              : Text(formatChatTime(chat.lastMessageAt)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatDetailPage(
                                  apiService: _apiService,
                                  authService: widget.authService,
                                  chat: chat,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.orange.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}
