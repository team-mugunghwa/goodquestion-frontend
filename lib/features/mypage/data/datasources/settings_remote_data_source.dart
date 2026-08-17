import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';

class SettingsRemoteDataSource {
  const SettingsRemoteDataSource(this._client);

  final DioClient _client;

  Future<Map<String, dynamic>> getParent() =>
      _client.get<Map<String, dynamic>>('/parents/me', parse: _map);

  Future<Map<String, dynamic>> getChildConsent(String childId) => _client
      .get<Map<String, dynamic>>('/children/$childId/consents', parse: _map);

  /// 보호자 확인 게이트의 비밀번호 확인. 204 면 맞은 것이고, **401 은
  /// "틀렸다"** 입니다 - 세션 만료가 아니므로 로그아웃시키지 않습니다
  /// (`signOutOnUnauthorized: false`). 소셜 계정이 부르면 서버가 403 으로
  /// 거절하므로, 부르는 쪽에서 `provider` 로 먼저 걸러야 합니다.
  Future<void> verifyPassword(String password) => _client.post<void>(
    '/parents/me/verify-password',
    body: <String, dynamic>{'password': password},
    signOutOnUnauthorized: false,
    parse: (_) {},
  );
}

Map<String, dynamic> _map(Object? data) {
  if (data is Map<String, dynamic>) return data;
  throw const ParseException('설정 응답 형식이 올바르지 않습니다.');
}
