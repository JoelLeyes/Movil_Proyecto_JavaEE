import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/firebase_messaging_service.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Warning: Firebase.initializeApp() falló: $e');
  }

  try {
    await LocalNotificationService.instance.initialize();
    await LocalNotificationService.instance.requestPermissions();
  } catch (e) {
    print('Warning: LocalNotificationService init falló: $e');
  }

  try {
    await FirebaseMessagingService().initialize();
  } catch (e) {
    print('Warning: FirebaseMessagingService init falló: $e');
  }

  runApp(const NexoLabApp());
}
