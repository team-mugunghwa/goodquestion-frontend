import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/util/child_age.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final DioClient _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _client.post<Map<String, dynamic>>(
    '/auth/login',
    body: <String, dynamic>{'email': email, 'password': password},
    parse: _map,
  );

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
  }) => _client.post<Map<String, dynamic>>(
    '/auth/signup',
    body: <String, dynamic>{'name': name, 'email': email, 'password': password},
    parse: _map,
  );

  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String authorizationCode,
    required String redirectUri,
  }) => _client.post<Map<String, dynamic>>(
    '/auth/social/$provider',
    body: <String, dynamic>{
      'authorizationCode': authorizationCode,
      'redirectUri': redirectUri,
    },
    parse: _map,
  );

  Future<List<Map<String, dynamic>>> children() =>
      _client.get<List<Map<String, dynamic>>>(
        '/children',
        parse: (Object? data) => (data as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );

  Future<String> createChild({required String name, required int age}) =>
      _client.post<String>(
        '/children',
        body: <String, dynamic>{
          'name': name,
          'birthYear': birthYearFromAge(age),
        },
        parse: (Object? data) => _map(data)['id'] as String? ?? '',
      );

  Future<void> saveConsent(String childId) => _client.post<void>(
    '/children/$childId/consents',
    body: <String, dynamic>{
      'consentVersion': 'v1',
      'verificationMethod': 'AUTHENTICATED_PARENT',
    },
    parse: (_) {},
  );

  /// 리프레시 토큰을 서버에서 무효화합니다. 이후로는 이 토큰으로 재발급이
  /// 안 됩니다.
  Future<void> logout(String refreshToken) => _client.post<void>(
    '/auth/logout',
    body: <String, dynamic>{'refreshToken': refreshToken},
    parse: (_) {},
  );
}

Map<String, dynamic> _map(Object? data) {
  if (data is Map<String, dynamic>) return data;
  throw const ParseException('인증 응답 형식이 올바르지 않습니다.');
}
