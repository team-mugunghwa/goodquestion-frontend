import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/my_page_dto.dart';

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

  /// 활동 요약. 완주 편수와 별가루 잔액을 **한 번에** 줍니다 - 예전에는
  /// 별가루 지갑(`/children/{id}/stardust`)을 따로 불렀고 완주 편수는 아예
  /// 못 채웠습니다. 남의 아이면 403 입니다.
  Future<ChildActivityDto> getActivity(String childId) =>
      _client.get<ChildActivityDto>(
        '/children/$childId/activity',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return ChildActivityDto.fromJson(data);
          }
          throw const ParseException('활동 요약 응답 형식이 올바르지 않습니다.');
        },
      );

  /// 아이 프로필 수정. 두 필드 모두 선택이라 **보낼 것만** 실어 보냅니다.
  /// (`birthYear` 는 서버가 2000~2100 으로 검증합니다)
  Future<Map<String, dynamic>> updateChild(
    String childId, {
    String? name,
    int? birthYear,
  }) => _client.patch<Map<String, dynamic>>(
    '/children/$childId',
    body: <String, dynamic>{
      if (name != null) 'name': name,
      if (birthYear != null) 'birthYear': birthYear,
    },
    parse: (Object? data) {
      if (data is Map<String, dynamic>) return data;
      throw const ParseException('아이 정보 응답 형식이 올바르지 않습니다.');
    },
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
