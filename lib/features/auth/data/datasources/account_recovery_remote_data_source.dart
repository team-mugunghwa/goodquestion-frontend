import '../../../../core/network/dio_client.dart';

class AccountRecoveryRemoteDataSource {
  const AccountRecoveryRemoteDataSource(this._client);

  final DioClient _client;

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
