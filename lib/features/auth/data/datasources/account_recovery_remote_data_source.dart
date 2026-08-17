import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';

class AccountRecoveryRemoteDataSource {
  const AccountRecoveryRemoteDataSource(this._client);

  final DioClient _client;

  /// 가입 이메일 찾기. **매치가 없어도 오류가 아니라 빈 목록**입니다
  /// (서버가 404 가 아니라 200 + `emails: []` 를 줍니다).
  ///
  /// [childName] 과 [childBirthYear] 는 스키마상 선택이지만 **둘 다 채워야**
  /// 그 아이로 좁혀서 찾습니다. 하나라도 비면 서버가 보호자 이름만으로 찾고,
  /// 그때는 **아이가 등록된 계정을 결과에서 뺍니다** - 아이 정보 없이는 남의
  /// 계정을 캐낼 수 없게 막는 조건이라, 실사용자는 사실상 늘 빈 결과를 받습니다.
  ///
  /// 이메일 마스킹(`de***@...`)은 서버가 이미 해서 옵니다. 화면에서 또
  /// 가리지 마세요.
  Future<List<String>> findEmails({
    required String parentName,
    String? childName,
    int? childBirthYear,
  }) => _client.post<List<String>>(
    '/auth/find-email',
    body: <String, dynamic>{
      'parentName': parentName,
      'childName': childName,
      'childBirthYear': childBirthYear,
    },
    parse: (Object? data) {
      if (data is Map<String, dynamic>) {
        final Object? emails = data['emails'];
        if (emails is List) {
          return emails.whereType<String>().toList(growable: false);
        }
      }
      throw const ParseException('가입 이메일 응답 형식이 올바르지 않습니다.');
    },
  );

  Future<void> requestPasswordReset(String email) => _client.post<void>(
    '/auth/password-reset/request',
    body: <String, dynamic>{'email': email},
    parse: (_) {},
  );

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) => _client.post<void>(
    '/auth/password-reset/confirm',
    body: <String, dynamic>{'token': token, 'newPassword': newPassword},
    parse: (_) {},
  );
}
