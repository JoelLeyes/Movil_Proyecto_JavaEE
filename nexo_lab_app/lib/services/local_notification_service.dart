import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showIncomingMessage({
    required int chatId,
    required String chatName,
    required String messagePreview,
    required int unreadCount,
  }) async {
    await initialize();

    final safePreview = messagePreview.trim().isEmpty
        ? 'Tienes un nuevo mensaje.'
        : messagePreview;

    final body = unreadCount > 1
        ? '$safePreview\n$unreadCount mensajes sin leer.'
        : safePreview;

    const androidDetails = AndroidNotificationDetails(
      'nexolab_messages',
      'Mensajes',
      channelDescription: 'Notificaciones de mensajes recibidos en NexoLab.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      chatId,
      'Nuevo mensaje en $chatName',
      body,
      details,
      payload: 'chat:$chatId',
    );
  }
}
