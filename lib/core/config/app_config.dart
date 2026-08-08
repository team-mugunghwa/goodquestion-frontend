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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  static String get apiBaseUrl =>
      _rawBaseUrl.isNotEmpty ? _rawBaseUrl : _defaultBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// 네트워크 로그를 콘솔에 찍을지. 릴리스 빌드에서는 자동으로 꺼집니다.
  static bool get enableNetworkLog => kDebugMode;
}
