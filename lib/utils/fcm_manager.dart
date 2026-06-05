import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FcmManager {
  static const String _tokenUrl = 'https://aerthh.newhopeindia17.com/api/fcm/token';

  static Future<void> registerToken(int customerId) async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Request Permission (especially for iOS)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FcmManager: User denied notification permissions');
        return;
      }

      // 2. Get FCM Token
      String? fcmToken = await messaging.getToken();
      if (fcmToken == null) {
        debugPrint('FcmManager: Could not fetch FCM token');
        return;
      }

      // 3. Get Device Info
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown';
      String deviceType = 'android';

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? 'web_browser';
        deviceType = 'web';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceType = 'android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_device';
        deviceType = 'ios';
      }

      // 4. Save to Backend
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "admin_id": null,
          "customer_id": customerId,
          "vendor_id": null,
          "deliver_man_id": null,
          "fcm_token": fcmToken,
          "device_id": deviceId,
          "device_type": deviceType,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('FcmManager: FCM token saved successfully.');
      } else {
        debugPrint('FcmManager: Failed to save FCM token. Status: ${response.statusCode}');
        debugPrint('FcmManager: Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('FcmManager Error: $e');
    }
  }
}
