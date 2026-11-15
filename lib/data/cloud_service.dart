import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase remains optional so the trial runs without a configured project.
class CloudService {
  CloudService._();
  static final instance = CloudService._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  User? user;
  bool get connected => user != null;

  DocumentReference<Map<String, dynamic>> get stateDoc => FirebaseFirestore
      .instance
      .collection('users')
      .doc(user!.uid)
      .collection('state')
      .doc('current');

  Future<void> initialize() async {
    if ([apiKey, appId, senderId, projectId].any((v) => v.isEmpty)) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      );
      user =
          FirebaseAuth.instance.currentUser ??
          (await FirebaseAuth.instance.signInAnonymously()).user;
      if (user != null) _registerMessaging();
    } catch (error) {
      debugPrint('Firebase no disponible: $error');
    }
  }

  Future<Map<String, dynamic>?> read() async {
    if (!connected) return null;
    try {
      final snapshot = await stateDoc.get();
      return snapshot.data()?['payload'] as Map<String, dynamic>?;
    } catch (error) {
      debugPrint('No se pudo leer la nube: $error');
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> payload) async {
    if (!connected) return;
    try {
      await stateDoc.set({
        'payload': payload,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('No se pudo sincronizar la nube: $error');
    }
  }

  Future<void> publishAlert(String parcelName) async {
    if (!connected) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('alerts')
          .add({
            'title': 'Alerta crítica en $parcelName',
            'body':
                'Los valores simulados requieren atención. Revisa Mis cultivos.',
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      debugPrint('No se pudo publicar la alerta: $error');
    }
  }

  Future<void> _registerMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // FCM token is used by the Admin SDK trigger in functions/index.js.
      // ignore: deprecated_member_use
      final token = await messaging.getToken(
        vapidKey: kIsWeb && vapidKey.isNotEmpty ? vapidKey : null,
      );
      if (token != null) await _saveToken(token);
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen(_saveToken);
    } catch (error) {
      debugPrint('Push remoto no disponible: $error');
    }
  }

  Future<void> _saveToken(String token) async {
    if (!connected) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }
}
