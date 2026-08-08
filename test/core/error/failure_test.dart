import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/exceptions.dart';
import 'package:goodquestion/core/error/failure.dart';

void main() {
  group('Failure.fromException', () {
    test('UnauthorizedException 은 UnauthorizedFailure 로 번역된다', () {
      final failure = Failure.fromException(const UnauthorizedException());
      expect(failure, isA<UnauthorizedFailure>());
    });

    test('ServerException 의 code 가 보존된다', () {
      final failure = Failure.fromException(
        const ServerException(message: '없는 질문', code: 'QUESTION_NOT_FOUND'),
      );

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).code, 'QUESTION_NOT_FOUND');
      expect(failure.message, '없는 질문');
    });

    test('모르는 예외는 UnknownFailure 로 떨어진다', () {
      final failure = Failure.fromException(const FormatException('boom'));
      expect(failure, isA<UnknownFailure>());
    });
  });
}
