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
      return host == 'nexolab.cloud-ip.cc';
    };
    return client;
  }
}
