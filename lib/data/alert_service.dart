import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlertService {
  AlertService._();
  static final instance = AlertService._();
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;

  Future<void> initialize() async {
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        ),
      );
      ready = true;
    } catch (error) {
      debugPrint('Notificaciones locales no disponibles: $error');
    }
  }

  Future<void> notifyCritical(String parcelName) async {
    if (!ready) return;
    try {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Alerta crítica en $parcelName',
        body:
            'Los valores simulados requieren atención. Abre Mis cultivos para ver recomendaciones.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'terracrop_alerts',
            'Alertas de cultivos',
            channelDescription: 'Alertas críticas de las parcelas',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      debugPrint('No se pudo mostrar la alerta local: $error');
    }
  }
}
