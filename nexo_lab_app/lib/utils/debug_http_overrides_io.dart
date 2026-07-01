import 'dart:io';

import 'package:flutter/foundation.dart';

void applyDebugHttpOverrides() {
  if (!kDebugMode) {
    return;
  }
  HttpOverrides.global = _DebugHttpOverrides();
}

class _DebugHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      // Durante el desarrollo en debug, permitir certificados no verificados
      // para evitar errores con servidores de prueba o certificados autosignados.
      return true;
    };
    return client;
  }
}
