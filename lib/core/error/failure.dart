import 'exceptions.dart';

/// domain / presentation 이 다루는 실패 타입.
///
/// `Exception` 과 나누는 이유: domain 레이어가 Dio·HTTP 같은 바깥 기술을
/// 몰라야 하기 때문입니다. data 레이어가 [Failure.fromException] 으로 번역합니다.
///
/// `sealed` 라서 switch 문에서 모든 경우를 처리했는지 컴파일러가 검사해 줍니다.
sealed class Failure {
  const Failure(this.message);

  /// 사용자에게 그대로 보여줄 수 있는 메시지.
  final String message;

  /// data 레이어의 예외를 domain 의 실패로 번역합니다.
  factory Failure.fromException(Object error) {
    return switch (error) {
      UnauthorizedException(:final String message) => UnauthorizedFailure(message),
      NetworkException(:final message) => NetworkFailure(message),
      ServerException(:final message, :final code) => ServerFailure(
        message: message,
        code: code,
      ),
      ParseException(:final message) => UnknownFailure(message),
      CacheException(:final message) => CacheFailure(message),
      _ => const UnknownFailure(),
    };
  }
}

/// 서버가 명시적으로 거절함. [code] 로 분기합니다.
class ServerFailure extends Failure {
  const ServerFailure({required String message, required this.code})
    : super(message);

  final String code;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = '네트워크에 연결할 수 없습니다.']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = '로그인이 필요합니다.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = '저장된 데이터를 읽을 수 없습니다.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = '알 수 없는 오류가 발생했습니다.']);
}
