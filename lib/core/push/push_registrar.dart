import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/helpdesk/domain/usecases/helpdesk_use_cases.dart';
import 'push_service.dart';

/// 기기 토큰을 서버에 등록하고, 갱신될 때마다 다시 등록합니다.
///
/// 로그인한 뒤에 부릅니다 - 토큰 등록 API 가 인증을 요구하고, 서버는 토큰을
/// 보호자에 묶어 저장합니다. 로그인 전에 부르면 401 만 납니다.
class PushRegistrar {
  PushRegistrar({
    required PushService pushService,
    required RegisterDeviceUseCase registerDevice,
    required UnregisterDeviceUseCase unregisterDevice,
  }) : // 이름 있는 매개변수는 밑줄로 시작할 수 없어 초기화 형식 매개변수를 못 씁니다.
       // ignore: prefer_initializing_formals
       _pushService = pushService,
       // ignore: prefer_initializing_formals
       _registerDevice = registerDevice,
       // ignore: prefer_initializing_formals
       _unregisterDevice = unregisterDevice;

  final PushService _pushService;
  final RegisterDeviceUseCase _registerDevice;
  final UnregisterDeviceUseCase _unregisterDevice;

  StreamSubscription<String>? _refreshSubscription;
  String? _currentToken;

  /// 지금 등록된 토큰. 로그아웃할 때 이 값으로 해제합니다.
  String? get currentToken => _currentToken;

  /// 앱이 뜨고 로그인이 확인된 뒤 한 번 부릅니다.
  ///
  /// 실패해도 예외를 올리지 않습니다. 푸시 등록이 안 됐다고 앱을 못 쓰게 만들
  /// 이유가 없고, 알림은 어차피 서버에 쌓여 알림함에서 볼 수 있습니다.
  Future<void> start() async {
    try {
      final String? token = await _pushService.obtainToken();
      if (token != null) await _register(token);

      // 토큰이 바뀌면 다시 등록합니다. 이걸 놓치면 그 뒤로 푸시가 가지 않는데
      // 서버는 성공으로 알고 있습니다.
      _refreshSubscription ??= _pushService.tokenRefreshes.listen(_register);
    } catch (e) {
      debugPrint('푸시 기기 등록 실패: $e');
    }
  }

  /// 로그아웃할 때. 이 기기로는 더 이상 알림이 가지 않습니다.
  ///
  /// 하지 않으면 기기를 물려받거나 다른 계정으로 로그인한 사람에게 앞사람의
  /// 알림이 갑니다.
  Future<void> stop() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;

    final String? token = _currentToken;
    _currentToken = null;
    if (token == null) return;
    try {
      await _unregisterDevice(token);
    } catch (e) {
      debugPrint('푸시 기기 해제 실패: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _registerDevice(token: token, platform: _platform);
      _currentToken = token;
    } catch (e) {
      debugPrint('푸시 기기 등록 실패: $e');
    }
  }

  /// 서버의 `DevicePlatform` 과 값이 같아야 합니다.
  String get _platform {
    if (kIsWeb) return 'WEB';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
  }
}
