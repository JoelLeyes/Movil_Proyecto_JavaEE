import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../models/chat_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
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
  String _search = '';
  String _tab = 'all';
  String? _error;
  AppUser? _user;
  Map<int, ChatPreview> _chatSnapshot = <int, ChatPreview>{};

  Widget _buildAvatar({
    required String name,
    String? photoUrl,
    double radius = 24,
  }) {
    return buildProfileAvatar(
      name: name,
      photoUrl: photoUrl,
      radius: radius,
    );
  }

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    unawaited(_bootstrap());
    _registerMessageHandlers();
  }

  Future<void> _bootstrap() async {
    _user = await widget.authService.getCurrentUser();
    unawaited(widget.authService.syncDevicePushToken());
    await _loadChats();
  }

  void _registerMessageHandlers() {
    FirebaseMessaging.onMessage.listen((message) {
      NotificationService.showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (!mounted) {
        return;
      }

      final chatId = message.data['chatId'];
      if (chatId != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            apiService: _apiService,
            authService: widget.authService,
            chat: ChatPreview(
              id: int.tryParse(chatId.toString()) ?? 0,
              name: message.data['chatName']?.toString() ?? 'Chat',
              type: message.data['isGroup'] == 'true' ? 'GROUP' : 'PRIVATE',
              lastMessage: message.notification?.body ?? '',
              lastMessageAt: DateTime.now(),
              unreadCount: 0,
            ),
          ),
        ));
      }
    });
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

    if (_chatSnapshot.isEmpty) {
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
        // Notificaciones locales deshabilitadas temporalmente.
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
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Nueva conversacion privada'),
                onTap: () => Navigator.of(sheetContext).pop('private'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Nuevo grupo'),
                onTap: () => Navigator.of(sheetContext).pop('group'),
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
    final pageContext = context;
    String searchQuery = '';
    List<AppUser> searchResults = const <AppUser>[];
    bool searching = false;
    String? searchError;
    Timer? searchDebounce;
    var dialogOpen = true;

    final created = await showDialog<ChatPreview>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            void closeDialog([ChatPreview? result]) {
              if (!dialogOpen) {
                return;
              }
              dialogOpen = false;
              searchDebounce?.cancel();
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(dialogContext).pop(result);
            }

            Future<void> runSearch(String raw) async {
              searchQuery = raw;
              final query = raw.trim();
              searchDebounce?.cancel();

              if (query.length < 2) {
                setModalState(() {
                  searching = false;
                  searchResults = const <AppUser>[];
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
                  final results = await _apiService.searchUsers(query);
                  if (!modalContext.mounted || !dialogOpen) {
                    return;
                  }

                  final currentUserId = _user?.id;
                  final available = results
                      .where((user) {
                        if (currentUserId != null && user.id == currentUserId) {
                          return false;
                        }
                        return true;
                      })
                      .toList();

                  setModalState(() {
                    searching = false;
                    searchResults = available;
                    searchError = null;
                  });
                } catch (e) {
                  if (!modalContext.mounted || !dialogOpen) {
                    return;
                  }
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
              title: const Text('Nueva conversacion'),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: searchQuery,
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
                    else if (searchError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          searchError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    else if (searchQuery.trim().length < 2)
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
                                              leading: _buildAvatar(
                                                name: user.name,
                                                photoUrl: user.fotoPerfilUrl,
                                                radius: 20,
                                              ),
                              title: Text(user.name),
                              subtitle: Text(user.email),
                              onTap: () async {
                                try {
                                  final chat = await _apiService.createPrivateChat(
                                    otherUser: user,
                                  );
                                  if (!modalContext.mounted || !dialogOpen) {
                                    return;
                                  }
                                  closeDialog(chat);
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
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    await Future<void>.delayed(Duration.zero);
    searchDebounce?.cancel();

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
    final pageContext = context;
    String groupName = '';
    String searchQuery = '';
    final selected = <AppUser>[];
    UploadFilePayload? groupPhoto;
    List<AppUser> searchResults = const <AppUser>[];
    bool searching = false;
    String? searchError;
    int step = 1;
    Timer? searchDebounce;
    var dialogOpen = true;

    void closeDialog([ChatPreview? result]) {
      if (!dialogOpen) {
        return;
      }
      dialogOpen = false;
      searchDebounce?.cancel();
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(pageContext, rootNavigator: true).pop(result);
    }

    final created = await showDialog<ChatPreview>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> pickGroupPhoto(StateSetter setModalState) async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                type: FileType.image,
                withData: true,
              );

              if (!dialogOpen || result == null || result.files.isEmpty) {
                return;
              }

              final file = result.files.single;
              final bytes = file.bytes;
              if (bytes == null || bytes.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo leer la foto seleccionada.')),
                  );
                }
                return;
              }

              setModalState(() {
                groupPhoto = UploadFilePayload(
                  fileName: file.name,
                  bytes: bytes,
                  mimeType: file.extension == null ? null : 'image/${file.extension}',
                );
              });
            }

            void clearGroupPhoto(StateSetter setModalState) {
              setModalState(() {
                groupPhoto = null;
              });
            }


            Future<void> runSearch(String raw) async {
              searchQuery = raw;
              final query = raw.trim();
              searchDebounce?.cancel();

              if (query.length < 2) {
                setModalState(() {
                  searching = false;
                  searchResults = const <AppUser>[];
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
                  final results = await _apiService.searchUsers(query);
                  if (!modalContext.mounted || !dialogOpen) {
                    return;
                  }

                  final currentUserId = _user?.id;
                  final available = results.where((user) {
                    if (currentUserId != null && user.id == currentUserId) {
                      return false;
                    }
                    return !selected.any((picked) => picked.id == user.id);
                  }).toList();

                  setModalState(() {
                    searching = false;
                    searchResults = available;
                    searchError = null;
                  });
                } catch (e) {
                  if (!modalContext.mounted || !dialogOpen) {
                    return;
                  }
                  setModalState(() {
                    searching = false;
                    searchResults = const <AppUser>[];
                    searchError = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              });
            }

            Widget buildStep1() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: groupName,
                    onChanged: (value) => setModalState(() {
                      groupName = value;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del grupo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: groupName.trim().length < 2
                        ? null
                        : () {
                            setModalState(() {
                              step = 2;
                            });
                          },
                    child: const Text('Siguiente'),
                  ),
                ],
              );
            }

            Widget buildStep2() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Miembros seleccionados: ${selected.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (selected.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selected.map((user) {
                        return Chip(
                          label: Text(user.name),
                          onDeleted: () {
                            setModalState(() {
                              selected.removeWhere(
                                (picked) => picked.id == user.id,
                              );
                            });
                          },
                        );
                      }).toList(),
                    )
                  else
                    const Text(
                      'No agregaste miembros aun.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: searchQuery,
                    onChanged: runSearch,
                    decoration: const InputDecoration(
                      labelText: 'Buscar usuarios',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (searching) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (searchError != null) {
                          return Center(
                            child: Text(
                              searchError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (searchQuery.trim().length < 2) {
                          return const Center(
                            child: Text('Escribe al menos 2 caracteres para buscar.'),
                          );
                        }
                        if (searchResults.isEmpty) {
                          return const Center(
                            child: Text('No se encontraron usuarios.'),
                          );
                        }

                        return ListView.separated(
                          itemCount: searchResults.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: _buildAvatar(
                                name: user.name,
                                photoUrl: user.fotoPerfilUrl,
                                radius: 20,
                              ),
                              title: Text(user.name),
                              subtitle: Text(user.email),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  setModalState(() {
                                    if (!selected.any((picked) => picked.id == user.id)) {
                                      selected.add(user);
                                    }
                                    searchResults.removeWhere(
                                      (result) => result.id == user.id,
                                    );
                                    searchError = null;
                                  });
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            final screenSize = MediaQuery.of(modalContext).size;
            final dialogWidth = (screenSize.width - 32).clamp(280.0, 460.0).toDouble();
            final dialogHeight = (screenSize.height * 0.78).clamp(360.0, 620.0).toDouble();

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  return;
                }
                closeDialog();
              },
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: SizedBox(
                  width: dialogWidth,
                  height: dialogHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Nuevo grupo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: closeDialog,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => pickGroupPhoto(setModalState),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(16),
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  foregroundImage: groupPhoto != null
                                      ? MemoryImage(Uint8List.fromList(groupPhoto!.bytes))
                                      : null,
                                  child: groupPhoto == null ? const Icon(Icons.image_outlined) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Foto del grupo',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        groupPhoto != null
                                            ? groupPhoto!.fileName
                                            : 'Opcional. Elegí una imagen para identificar el grupo.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => groupPhoto != null
                                      ? clearGroupPhoto(setModalState)
                                      : pickGroupPhoto(setModalState),
                                  child: Text(groupPhoto != null ? 'Quitar' : 'Elegir foto'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step == 1 ? 'Paso 1 de 2' : 'Paso 2 de 2',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: step == 1 ? buildStep1() : buildStep2(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (step == 2)
                              TextButton(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setModalState(() {
                                    step = 1;
                                    searchResults = const <AppUser>[];
                                    searching = false;
                                    searchError = null;
                                  });
                                },
                                child: const Text('Atrás'),
                              ),
                            TextButton(
                              onPressed: () => closeDialog(),
                              child: const Text('Cancelar'),
                            ),
                            if (step == 2)
                              FilledButton(
                                onPressed: selected.isEmpty
                                    ? null
                                    : () async {
                                        FocusManager.instance.primaryFocus?.unfocus();
                                        try {
                                          final chat = await _apiService.createGroupChat(
                                            name: groupName.trim(),
                                            memberIds: selected.map((user) => user.id).toList(),
                                          );
                                          ChatPreview createdChat = chat;
                                          if (groupPhoto != null) {
                                            try {
                                              final photoUrl = await _apiService.uploadGroupPhoto(
                                                chatId: chat.id,
                                                photo: groupPhoto!,
                                              );
                                              if (photoUrl.isNotEmpty) {
                                                createdChat = chat.copyWith(
                                                  fotoGrupoUrl: photoUrl,
                                                );
                                              }
                                            } catch (_) {
                                              // El grupo ya quedó creado; la foto se puede cambiar después.
                                            }
                                          }
                                          if (!modalContext.mounted || !dialogOpen) {
                                            return;
                                          }
                                          closeDialog(createdChat);
                                        } catch (e) {
                                          if (!mounted) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(pageContext).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst('Exception: ', ''),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                child: const Text('Crear grupo'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    await Future<void>.delayed(Duration.zero);
    searchDebounce?.cancel();

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
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfilePage(authService: widget.authService),
                        ),
                      )
                      .then((_) => _bootstrap());
                },
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: buildProfileAvatar(
                    name: _user!.name,
                    photoUrl: _user!.fotoPerfilUrl,
                    radius: 16,
                    initialsStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
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
                          leading: _buildAvatar(
                            name: chat.name,
                            photoUrl: chat.avatarUrl,
                            radius: 24,
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
                            ).then((_) {
                              if (mounted) {
                                unawaited(_loadChats(silent: true));
                              }
                            });
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
