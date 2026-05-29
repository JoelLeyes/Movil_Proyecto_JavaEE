import 'package:flutter/material.dart';

import 'app.dart';
import 'utils/debug_http_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  applyDebugHttpOverrides();
  // Notificaciones deshabilitadas: omitir inicialización de Firebase y servicios asociados.

  runApp(const NexoLabApp());
}
