import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';

class SettingsRemoteDataSource {
  const SettingsRemoteDataSource(this._client);

  final DioClient _client;

  Future<Map<String, dynamic>> getParent() =>
      _client.get<Map<String, dynamic>>('/parents/me', parse: _map);

  Future<Map<String, dynamic>> getChildConsent(String childId) => _client
      .get<Map<String, dynamic>>('/children/$childId/consents', parse: _map);
}

Map<String, dynamic> _map(Object? data) {
  if (data is Map<String, dynamic>) return data;
  throw const ParseException('설정 응답 형식이 올바르지 않습니다.');
}
