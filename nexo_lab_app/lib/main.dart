import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/firebase_messaging_service.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalNotificationService.instance.initialize();
  await LocalNotificationService.instance.requestPermissions();
  await FirebaseMessagingService().initialize();
  runApp(const NexoLabApp());
}
