import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification_service.dart';

/// Handler global para notificaciones cuando la app está cerrada
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await LocalNotificationService.instance.handleRemoteMessage(message);
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  FirebaseMessagingService._internal();

  factory FirebaseMessagingService() {
    return _instance;
  }

  /// Inicializa Firebase Messaging y configura listeners
  Future<void> initialize() async {
    // Configurar handler para notificaciones en background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Configurar listener para notificaciones en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Configurar listener para cuando se abre la app desde notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageOpenedApp(message);
    });

    // Obtener y mostrar el token de registro (útil para pruebas)
    try {
      final token = await FirebaseMessaging.instance.getToken();
      // ignore: avoid_print
      print('FCM token: $token');
    } catch (e) {
      // ignore: avoid_print
      print('No se pudo obtener FCM token: $e');
    }

    // Escuchar cambios de token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // ignore: avoid_print
      print('FCM token refrescado: $newToken');
    });
  }

  /// Maneja notificaciones cuando la app está en primer plano
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await LocalNotificationService.instance.handleRemoteMessage(message);
  }

  /// Maneja cuando el usuario toca la notificación
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    _navigateToChat(message);
  }

  /// Navega a la conversación correspondiente
  void _navigateToChat(RemoteMessage message) {
    try {
      final chatId = message.data['chatId'];
      if (chatId != null) {
        // TODO: Implementar navegación a la conversación
        // Aquí se puede usar un GlobalKey<NavigatorState> para navegar
        print('Navegar a chat: $chatId');
      }
    } catch (e) {
      print('Error al navegar: $e');
    }
  }
}
