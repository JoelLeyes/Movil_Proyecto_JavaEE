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
    {'value': 'EN_REUNION', 'label': 'En reunion'},
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
        title: const Text('Cerrar sesion'),
        content: const Text('Estas seguro que quieres cerrar sesion?'),
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
      builder: (_) {
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
                    onTap: () => Navigator.of(context).pop(status['value']),
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
              final current = currentController.text;
              final next = newController.text;
              final confirm = confirmController.text;

              if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completa todos los campos.')),
                );
                return;
              }
              if (next != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contrasenas no coinciden.'),
                  ),
                );
                return;
              }
              final hasUpper = next.contains(RegExp(r'[A-Z]'));
              final hasNumber = next.contains(RegExp(r'[0-9]'));
              final hasSpecial = next.contains(RegExp(r'[^A-Za-z0-9]'));
              if (next.length < 8 || !hasUpper || !hasNumber || !hasSpecial) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Minimo 8, mayuscula, numero y especial.'),
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
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Contrasena actualizada.')),
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
              }
            }

            return AlertDialog(
              title: const Text('Cambiar contrasena'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Contrasena actual',
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
                        labelText: 'Nueva contrasena',
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
                        labelText: 'Confirmar nueva contrasena',
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

  String _statusLabel(String? value) {
    final found = _statuses.where((s) => s['value'] == value).toList();
    if (found.isEmpty) {
      return 'Desconocido';
    }
    return found.first['label']!;
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
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF185FA5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFF0C447C),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        ),
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
                      Chip(label: Text(user.role)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: Text(user.email),
                        subtitle: const Text('Correo electronico'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.work_outline),
                        title: Text(user.cargo ?? user.role),
                        subtitle: const Text('Cargo'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.business_outlined),
                        title: Text(user.sector ?? 'Sin asignar'),
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
                        leading: const Icon(Icons.circle),
                        title: const Text('Estado'),
                        subtitle: Text(_statusLabel(user.status)),
                        onTap: _changeStatus,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Cambiar contrasena'),
                        onTap: _changePassword,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Notificaciones'),
                        subtitle: const Text(
                          'Configuracion basica en desarrollo',
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Proximamente')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: const Text('Privacidad'),
                        subtitle: const Text(
                          'Configuracion basica en desarrollo',
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Proximamente')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesion'),
                ),
              ],
            ),
    );
  }
}
