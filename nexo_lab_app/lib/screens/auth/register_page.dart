import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _step = 0;
  bool _loading = false;
  bool _accepted = false;
  bool _notificationsEnabled = true;
  bool _obscure1 = true;
  bool _obscure2 = true;
  int _selectedAvatar = 0;
  String? _error;
  String? _registerMessage;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  static const List<Color> _avatarBg = <Color>[
    Color(0xFFE6F1FB),
    Color(0xFFEEEDFE),
    Color(0xFFE1F5EE),
    Color(0xFFFAEEDA),
    Color(0xFFFBEAF0),
  ];

  static const List<Color> _avatarFg = <Color>[
    Color(0xFF0C447C),
    Color(0xFF3C3489),
    Color(0xFF085041),
    Color(0xFF633806),
    Color(0xFF72243E),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_accepted) {
      setState(() {
        _error = 'Debes aceptar terminos y condiciones.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final message = await widget.authService.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _registerMessage = message;
      _step = 3;
    });
  }

  String get _avatarInitials {
    final name = _nameController.text.trim();
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) {
      return name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase();
    }
    return 'NL';
  }

  int get _passwordScore {
    final text = _passwordController.text;
    var score = 0;
    if (text.length >= 8) {
      score += 1;
    }
    if (text.contains(RegExp(r'[A-Z]'))) {
      score += 1;
    }
    if (text.contains(RegExp(r'[0-9]'))) {
      score += 1;
    }
    if (text.contains(RegExp(r'[^A-Za-z0-9]'))) {
      score += 1;
    }
    return score;
  }

  String get _passwordLabel {
    const labels = <String>[
      'Ingresa una contrasena',
      'Muy debil',
      'Debil',
      'Buena',
      'Excelente',
    ];
    return labels[_passwordScore];
  }

  Color get _passwordColor {
    const colors = <Color>[
      Color(0xFF9CA3AF),
      Color(0xFFDC3545),
      Color(0xFFFD7E14),
      Color(0xFF20C997),
      Color(0xFF198754),
    ];
    return colors[_passwordScore];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stepper(
                  currentStep: _step,
                  controlsBuilder: (context, details) =>
                      const SizedBox.shrink(),
                  onStepTapped: (value) {
                    if (value <= _step) {
                      setState(() => _step = value);
                    }
                  },
                  steps: [
                    Step(
                      title: const Text('Datos'),
                      isActive: _step >= 0,
                      content: Form(
                        key: _formKey1,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final parts = (value ?? '').trim().split(
                                  RegExp(r'\s+'),
                                );
                                if (parts.length < 2) {
                                  return 'Ingresa nombre y apellido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Correo empresarial',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty || !text.contains('@')) {
                                  return 'Ingresa un correo valido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefono (opcional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  if (_formKey1.currentState!.validate()) {
                                    setState(() => _step = 1);
                                  }
                                },
                                child: const Text('Continuar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('Seguridad'),
                      isActive: _step >= 1,
                      content: Form(
                        key: _formKey2,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure1,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Contrasena',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure1 = !_obscure1),
                                  icon: Icon(
                                    _obscure1
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final text = value ?? '';
                                final hasUpper = text.contains(
                                  RegExp(r'[A-Z]'),
                                );
                                final hasNumber = text.contains(
                                  RegExp(r'[0-9]'),
                                );
                                final hasSpecial = text.contains(
                                  RegExp(r'[^A-Za-z0-9]'),
                                );
                                if (text.length < 8 ||
                                    !hasUpper ||
                                    !hasNumber ||
                                    !hasSpecial) {
                                  return 'Minimo 8, mayuscula, numero y especial';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _passwordScore / 4,
                              minHeight: 6,
                              color: _passwordColor,
                              backgroundColor: const Color(0xFFE9ECEF),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _passwordLabel,
                                style: TextStyle(
                                  color: _passwordColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _PasswordRule(
                                    ok: _passwordController.text.length >= 8,
                                    text: 'Minimo 8 caracteres',
                                  ),
                                  _PasswordRule(
                                    ok: _passwordController.text.contains(
                                      RegExp(r'[A-Z]'),
                                    ),
                                    text: 'Al menos una mayuscula',
                                  ),
                                  _PasswordRule(
                                    ok: _passwordController.text.contains(
                                      RegExp(r'[0-9]'),
                                    ),
                                    text: 'Al menos un numero',
                                  ),
                                  _PasswordRule(
                                    ok: _passwordController.text.contains(
                                      RegExp(r'[^A-Za-z0-9]'),
                                    ),
                                    text:
                                        'Al menos un caracter especial (!@#\$)',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _confirmController,
                              obscureText: _obscure2,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Confirmar contrasena',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure2 = !_obscure2),
                                  icon: Icon(
                                    _obscure2
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Las contrasenas no coinciden';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(() => _step = 0),
                                  child: const Text('Atras'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () {
                                      if (_formKey2.currentState!.validate()) {
                                        setState(() => _step = 2);
                                      }
                                    },
                                    child: const Text('Continuar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('Perfil'),
                      isActive: _step >= 2,
                      content: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Color de avatar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: List<Widget>.generate(_avatarBg.length, (
                              index,
                            ) {
                              final selected = _selectedAvatar == index;
                              return InkWell(
                                onTap: () =>
                                    setState(() => _selectedAvatar = index),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  decoration: selected
                                      ? BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF185FA5),
                                            width: 2,
                                          ),
                                        )
                                      : null,
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: _avatarBg[index],
                                    child: Text(
                                      _avatarInitials,
                                      style: TextStyle(
                                        color: _avatarFg[index],
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _notificationsEnabled,
                            onChanged: (v) => setState(
                              () => _notificationsEnabled = v ?? false,
                            ),
                            title: const Text(
                              'Recibir notificaciones por email',
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _accepted,
                            onChanged: (v) =>
                                setState(() => _accepted = v ?? false),
                            title: const Text(
                              'Acepto terminos y politica de privacidad',
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => setState(() => _step = 1),
                                child: const Text('Atras'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _loading ? null : _finish,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Crear cuenta'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('Listo'),
                      isActive: _step >= 3,
                      content: Column(
                        children: [
                          const CircleAvatar(
                            radius: 34,
                            backgroundColor: Color(0xFFD1FAE5),
                            child: Icon(
                              Icons.check,
                              color: Color(0xFF198754),
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Cuenta creada con exito',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _registerMessage ??
                                'Revisa tu correo para verificar la cuenta.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => LoginPage(
                                      authService: widget.authService,
                                    ),
                                  ),
                                  (_) => false,
                                );
                              },
                              child: const Text('Ir al login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: ok ? const Color(0xFF198754) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: ok ? const Color(0xFF198754) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
