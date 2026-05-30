import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'utils/debug_http_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  applyDebugHttpOverrides();
  await Firebase.initializeApp();
  runApp(const NexoLabApp());
}
