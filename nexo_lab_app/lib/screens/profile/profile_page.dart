import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/chat_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../auth/welcome_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? _user;
  late final ApiService _apiService;

  static const List<Map<String, String>> _statuses = [
    {'value': 'DISPONIBLE', 'label': 'Disponible'},
    {'value': 'OCUPADO', 'label': 'Ocupado'},
    {'value': 'EN_REUNION', 'label': 'En reunión'},
    {'value': 'DESCONECTADO', 'label': 'Desconectado'},
  ];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await widget.authService.getCurrentUser();
    if (!mounted) {
      return;
    }
    setState(() {
      _user = user;
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (ok == true) {
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
  }

  Future<void> _changeStatus() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _statuses
                .map(
                  (status) => ListTile(
                    title: Text(status['label']!),
                    trailing: _user?.status == status['value']
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(status['value']),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected == null || selected == _user?.status) {
      return;
    }

    try {
      final updated = await _apiService.updateMyStatus(selected);
      if (!mounted) {
        return;
      }
      setState(() {
        _user = updated;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Estado actualizado.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _changeName() async {
    final user = _user;
    if (user == null) {
      return;
    }

    final nameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);

    await showDialog<void>(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final name = nameController.text.trim();
              final lastName = lastNameController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre no puede estar vacío.')),
                );
                return;
              }

              setModalState(() {
                saving = true;
              });

              try {
                final updated = await _apiService.updateMyProfile(
                  name: name,
                  lastName: lastName,
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                if (!mounted) {
                  return;
                }
                setState(() {
                  _user = updated;
                });
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Nombre actualizado.')),
                );
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              } finally {
                if (context.mounted) {
                  setModalState(() {
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Editar nombre'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Apellido',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    lastNameController.dispose();
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(this.context);
              final current = currentController.text;
              final next = newController.text;
              final confirm = confirmController.text;

              if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Completa todos los campos.')),
                );
                return;
              }
              if (next != confirm) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas no coinciden.'),
                  ),
                );
                return;
              }
              final hasUpper = next.contains(RegExp(r'[A-Z]'));
              final hasNumber = next.contains(RegExp(r'[0-9]'));
              final hasSpecial = next.contains(RegExp(r'[^A-Za-z0-9]'));
              if (next.length < 8 || !hasUpper || !hasNumber || !hasSpecial) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Mínimo 8 caracteres, mayúscula, número y especial.'),
                  ),
                );
                return;
              }

              try {
                await _apiService.changeMyPassword(
                  currentPassword: current,
                  newPassword: next,
                );
                if (!context.mounted) {
                  return;
                }
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Contraseña actualizada.')),
                );
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Cambiar contraseña'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setModalState(
                            () => obscureCurrent = !obscureCurrent,
                          ),
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setModalState(() => obscureNew = !obscureNew),
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setModalState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
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
                FilledButton(onPressed: submit, child: const Text('Guardar')),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Future<void> _changePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      return;
    }

    try {
      final updated = await _apiService.uploadMyPhoto(
        photo: UploadFilePayload(
          fileName: file.name,
          bytes: file.bytes!,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _user = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _buildAvatar(AppUser user) {
    final url = user.fotoPerfilUrl;
    final initials = user.initials;

    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 38,
        backgroundColor: const Color(0xFF0C447C),
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
      );
    }

    if (url.startsWith('data:')) {
      final commaIndex = url.indexOf(',');
      if (commaIndex > 0) {
        final raw = url.substring(commaIndex + 1);
        try {
          return CircleAvatar(
            radius: 38,
            backgroundImage: MemoryImage(base64Decode(raw)),
          );
        } catch (_) {
          // Fallback a iniciales.
        }
      }
    }

    return CircleAvatar(
      radius: 38,
      backgroundColor: const Color(0xFF0C447C),
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontSize: 22),
      ),
    );
  }

  String _statusLabel(String? value) {
    final found = _statuses.where((s) => s['value'] == value).toList();
    if (found.isEmpty) {
      return 'Desconocido';
    }
    return found.first['label']!;
  }

  Color _statusColor(String? value) {
    switch (value) {
      case 'DISPONIBLE':
        return Colors.green;
      case 'OCUPADO':
        return Colors.red;
      case 'EN_REUNION':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatEnum(String? value) {
    if (value == null || value.isEmpty) return 'Sin asignar';
    return value
        .split('_')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GestureDetector(
                  onTap: _changePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF185FA5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _buildAvatar(user),
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: Color(0xFF185FA5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Chip(label: Text(_formatEnum(user.role))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: Text(user.email),
                        subtitle: const Text('Correo electrónico'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.work_outline),
                        title: Text(_formatEnum(user.cargo)),
                        subtitle: const Text('Cargo'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.business_outlined),
                        title: Text(_formatEnum(user.sector)),
                        subtitle: const Text('Sector'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.circle,
                          color: _statusColor(user.status),
                        ),
                        title: const Text('Estado'),
                        subtitle: Text(_statusLabel(user.status)),
                        onTap: _changeStatus,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Editar nombre'),
                        onTap: _changeName,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Cambiar contraseña'),
                        onTap: _changePassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
    );
  }
}
