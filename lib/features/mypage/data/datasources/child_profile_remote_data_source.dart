import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';

class ChildProfileRemoteDataSource {
  const ChildProfileRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<Map<String, dynamic>>> getChildren() =>
      _client.get<List<Map<String, dynamic>>>(
        '/children',
        parse: (Object? data) => (data as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );

  Future<Map<String, dynamic>> createChild({
    required String name,
    required int birthYear,
  }) => _client.post<Map<String, dynamic>>(
    '/children',
    body: <String, dynamic>{'name': name, 'birthYear': birthYear},
    parse: (Object? data) {
      if (data is Map<String, dynamic>) return data;
      throw const ParseException('아이 정보 응답 형식이 올바르지 않습니다.');
    },
  );
}
