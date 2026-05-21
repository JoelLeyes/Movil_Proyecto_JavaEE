import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Notificaciones deshabilitadas: omitir inicialización de Firebase y servicios asociados.

  runApp(const NexoLabApp());
}
