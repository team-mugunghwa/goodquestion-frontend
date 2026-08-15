import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'push_service.dart';

/// FCM 으로 기기 토큰을 얻습니다.
///
/// **설정이 없으면 만들어지지 않습니다.** [create] 가 null 을 돌려주고 호출부가
/// [NoopPushService] 를 씁니다 — 로컬과 CI 에 Firebase 키를 두지 않기 위해서입니다.
class FcmPushService implements PushService {
  FcmPushService._(this._messaging);

  final FirebaseMessaging _messaging;

  /// Firebase 를 초기화하고 서비스를 만듭니다. 설정이 없거나 초기화가 실패하면 null.
  ///
  /// 실패를 예외로 올리지 않는 이유: 푸시가 안 된다고 앱이 안 뜨면 안 됩니다.
  /// 알림은 서버에 쌓이므로 사용자는 알림함에서 답변을 확인할 수 있습니다.
  static Future<PushService?> create() async {
    if (!AppConfig.hasFirebaseOptions) {
      debugPrint('Firebase 설정이 없어 푸시를 사용하지 않습니다. 알림은 알림함에서 확인할 수 있습니다.');
      return null;
    }
    try {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
      return FcmPushService._(FirebaseMessaging.instance);
    } catch (e) {
      debugPrint('Firebase 초기화 실패, 푸시를 사용하지 않습니다: $e');
      return null;
    }
  }

  @override
  Future<String?> obtainToken() async {
    final NotificationSettings settings = await _messaging.requestPermission();
    // 거부하면 토큰을 받아도 알림이 뜨지 않습니다. 등록하지 않는 편이
    // 서버에 죽은 토큰을 남기지 않아 깨끗합니다.
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    // 웹은 VAPID 키가 있어야 토큰이 나옵니다. 네이티브는 필요 없습니다.
    return _messaging.getToken(
      vapidKey: AppConfig.firebaseVapidKey.isEmpty
          ? null
          : AppConfig.firebaseVapidKey,
    );
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<String> get notificationTaps => FirebaseMessaging.onMessageOpenedApp
      .map((RemoteMessage message) => message.data['linkPath'] as String?)
      // 관리자 콘솔이 넣어 준 앱 안의 경로만 받습니다. 외부 주소로 열지 않습니다.
      .where((String? path) => path != null && path.startsWith('/'))
      .cast<String>();
}
