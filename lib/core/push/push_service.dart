import 'dart:async';

/// 푸시 알림 기기 토큰을 얻어 오는 창구.
///
/// ## 왜 인터페이스인가
///
/// 벤더를 바꿀 가능성 때문이 아닙니다. **Firebase 설정 없이도 앱이 뜨고 테스트가
/// 돌아야 하기 때문**입니다. 로컬 개발과 CI 에는 `google-services.json` 도
/// 웹 설정값도 없는데, 그 상태에서 초기화를 시도하면 앱이 시작하자마자 죽습니다.
///
/// 설정이 없으면 [NoopPushService] 가 뜨고 푸시만 나가지 않습니다. **알림 자체는
/// 서버에 쌓이므로 사용자는 알림함에서 답변을 확인할 수 있습니다.** 푸시는 알리는
/// 수단이지 전달 경로가 아닙니다.
///
/// ## 왜 FCM 인가
///
/// | 후보 | 판단 |
/// | --- | --- |
/// | FCM | 발송량 무료, Flutter 공식 플러그인이 iOS/안드로이드/웹을 덮음. **채택** |
/// | OneSignal | 콘솔은 편하지만 무료 구간에 사용자 수 제한, 안드로이드는 결국 FCM 경유 |
/// | Expo Push | Expo 로 만든 React Native 앱 전용. Flutter 에서 쓸 수 없음 |
abstract class PushService {
  /// 알림 권한을 요청하고 기기 토큰을 돌려줍니다. 거부하거나 설정이 없으면 null.
  Future<String?> obtainToken();

  /// 토큰이 갱신될 때마다 흘려보냅니다.
  ///
  /// FCM 토큰은 앱 재설치, 데이터 삭제, 장기 미사용으로 바뀝니다. 이 스트림을
  /// 구독해 서버에 다시 등록하지 않으면, 그 사용자에게는 그 뒤로 푸시가 가지 않고
  /// 서버는 그 사실을 알 방법이 없습니다.
  Stream<String> get tokenRefreshes;

  /// 알림을 눌러 앱이 열렸을 때의 이동 경로(`linkPath`).
  ///
  /// 관리자 콘솔이 알림 data 에 넣어 보냅니다. 예: `/support/{inquiryId}`
  Stream<String> get notificationTaps;
}

/// 설정이 없을 때 뜨는 구현. 아무 일도 하지 않습니다.
class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<String?> obtainToken() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();

  @override
  Stream<String> get notificationTaps => const Stream<String>.empty();
}
