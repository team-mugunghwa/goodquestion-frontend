/// data 레이어에서 던지는 예외들.
///
/// 이 예외들은 **data 레이어 밖으로 나가지 않습니다.** `RepositoryImpl` 이
/// 잡아서 `Failure` 로 번역합니다. domain / presentation 은 `Failure` 만 압니다.
library;

sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 서버가 `success: false` 를 내려주거나 4xx/5xx 를 반환한 경우.
class ServerException extends AppException {
  const ServerException({
    required String message,
    required this.code,
    this.statusCode,
  }) : super(message);

  /// 서버가 정의한 에러 코드. 예: `QUESTION_NOT_FOUND`
  ///
  /// 프론트는 HTTP 상태 코드나 message 문자열이 아니라 **이 코드로 분기**합니다.
  final String code;
  final int? statusCode;
}

/// 연결 실패 · 타임아웃 등 네트워크 자체의 문제.
class NetworkException extends AppException {
  const NetworkException([super.message = '네트워크에 연결할 수 없습니다.']);
}

/// 401. 토큰이 없거나 만료됨.
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = '로그인이 필요합니다.']);
}

/// 응답 JSON 이 예상한 모양이 아님.
///
/// 이 예외가 뜨면 대개 서버 스펙이 바뀐 것입니다. `docs/API.md` 를 확인하세요.
class ParseException extends AppException {
  const ParseException([super.message = '응답을 해석할 수 없습니다.']);
}

/// 로컬 저장소 읽기/쓰기 실패.
class CacheException extends AppException {
  const CacheException([super.message = '저장된 데이터를 읽을 수 없습니다.']);
}
