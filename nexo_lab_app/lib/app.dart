import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/pages.dart';
import 'services/auth_service.dart';

class NexoLabApp extends StatelessWidget {
  const NexoLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexoLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185FA5)),
        scaffoldBackgroundColor: const Color(0xFFF0F4F9),
      ),
      home: const BootstrapPage(),
    );
  }
}

class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  final AuthService _authService = AuthService();
  late final Future<bool> _hasTokenFuture;

  @override
  void initState() {
    super.initState();
    _hasTokenFuture = _authService.hasToken();
    // Sincroniza el token FCM al abrir la app si ya hay sesión activa.
    unawaited(_authService.syncDevicePushToken());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasTokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) {
          return ChatsPage(authService: _authService);
        }
        return WelcomePage(authService: _authService);
      },
    );
  }
}
