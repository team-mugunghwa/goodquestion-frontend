import 'package:flutter/foundation.dart';

/// 빌드 시점에 주입되는 설정값.
///
/// **API 주소를 코드에 하드코딩하지 마세요.** 아래처럼 실행 시 넘깁니다.
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://dev.example.com/api/v1
/// ```
///
/// 여러 값을 넘길 땐 파일로 관리할 수 있습니다. (`env.json` 은 커밋하지 않음)
///
/// ```bash
/// flutter run --dart-define-from-file=env.json
/// ```
///
/// `.env` 파일 방식(flutter_dotenv)을 쓰지 않는 이유:
/// 파일이 없으면 앱이 런타임에 죽는데, 새 팀원이 가장 자주 밟는 지뢰입니다.
/// `--dart-define` 은 기본값이 있어 클론 직후에도 그냥 실행됩니다.
abstract final class AppConfig {
  static const String _rawBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// OAuth 공급자 키 없이 로그인 화면의 이동 흐름만 확인하는 개발 옵션입니다.
  /// 실제 인증이나 토큰 발급은 하지 않으므로 배포 빌드에서는 사용하면 안 됩니다.
  static const bool mockSocialLogin = bool.fromEnvironment(
    'MOCK_SOCIAL_LOGIN',
    defaultValue: false,
  );

  /// 로컬 백엔드(`localhost:8080`)를 가리키는 기본 주소.
  ///
  /// Android 에뮬레이터에서 `localhost` 는 **에뮬레이터 자신**을 가리킵니다.
  /// 호스트 PC 는 `10.0.2.2` 입니다. 이걸 몰라서 "연결이 안 돼요" 로
  /// 반나절 쓰는 경우가 많아 기본값으로 처리해 둡니다.
  ///
  /// `dart:io` 의 `Platform` 대신 `defaultTargetPlatform` 을 쓰는 이유:
  /// **web 에는 `dart:io` 가 아예 없어서** import 만 해도 빌드가 깨집니다.
  /// `defaultTargetPlatform` 은 모든 플랫폼에서 동작합니다.
  static String get _defaultBaseUrl {
    if (kIsWeb) {
      final String host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      final String apiHost = host == 'localhost' ? '127.0.0.1' : host;
      return 'http://$apiHost:8080/api';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  static String get apiBaseUrl =>
      _rawBaseUrl.isNotEmpty ? _rawBaseUrl : _defaultBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 10);

  /// `/utterances` 한 턴은 백엔드에서 LLM을 두 번 순차 호출합니다(발화 분석 ->
  /// 캐릭터 대사 생성). 백엔드의 외부 API 응답 타임아웃이 각 10초라 최악의
  /// 경우 20초에 가깝습니다 - 15초로는 정상 처리 중인데도 타임아웃으로
  /// "네트워크에 연결할 수 없습니다"가 뜨고, 이야기가 도중에 끊깁니다.
  /// → `WebClientConfig`(backend), `application.yml`의
  /// `external.http.response-timeout-ms`
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// 네트워크 로그를 콘솔에 찍을지. 릴리스 빌드에서는 자동으로 꺼집니다.
  static bool get enableNetworkLog => kDebugMode;

  static const String kakaoClientId = String.fromEnvironment('KAKAO_CLIENT_ID');
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );
  static const String _rawOauthRedirectUri = String.fromEnvironment(
    'OAUTH_REDIRECT_URI',
  );

  /// 웹은 팝업 결과를 부모 창으로 전달하는 정적 콜백 페이지를 사용합니다.
  /// 네이티브 앱은 등록된 커스텀 scheme으로 돌아옵니다.
  static String get oauthRedirectUri {
    if (_rawOauthRedirectUri.isNotEmpty) return _rawOauthRedirectUri;
    if (kIsWeb) return Uri.base.resolve('auth.html').toString();
    return 'goodquestion://oauth';
  }
}
