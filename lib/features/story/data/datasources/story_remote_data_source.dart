import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/story_response_dto.dart';

class StoryRemoteDataSource {
  const StoryRemoteDataSource(this._client);

  final DioClient _client;

  Future<StoryListResponseDto> fetchCatalog() =>
      _client.get<StoryListResponseDto>(
        '/stories',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return StoryListResponseDto.fromJson(data);
          }
          throw const ParseException('이야기 목록 응답 형식이 올바르지 않습니다.');
        },
      );

  /// 없는 storyId 면 서버가 404 를 주고, [DioClient] 가 [ServerException] 으로
  /// 바꿔 던집니다. 여기서는 파싱만 하고, "없음" 판단은 리포지토리가 합니다.
  Future<StoryDetailResponseDto> fetchDetail(String storyId) =>
      _client.get<StoryDetailResponseDto>(
        '/stories/$storyId',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return StoryDetailResponseDto.fromJson(data);
          }
          throw const ParseException('이야기 상세 응답 형식이 올바르지 않습니다.');
        },
      );

  /// 이 아이가 완주한 이야기의 id 들.
  ///
  /// 목록 카드에 "끝냈어" 도장을 찍는 데 씁니다. 완주한 게 없으면 **빈
  /// 배열**이고 404 가 아닙니다 — 아직 아무것도 안 한 것은 정상입니다.
  /// (서버 판정 근거는 COMPLETED 세션이고, 후속 자유 대화의 진입 조건과
  /// 같습니다. → 백엔드 `ChildStoryController`)
  Future<List<String>> fetchCompletedStoryIds(String childId) =>
      _client.get<List<String>>(
        '/children/$childId/stories/completed',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            final Object? ids = data['storyIds'];
            if (ids is List) {
              return <String>[
                for (final Object? id in ids)
                  if (id is String && id.isNotEmpty) id,
              ];
            }
          }
          throw const ParseException('완주한 이야기 응답 형식이 올바르지 않습니다.');
        },
      );

  /// 이야기를 시작해 세션을 만듭니다. `sessionId` 만 돌려줍니다 — 첫 장면은
  /// 재생 화면(⛔ 미구현)에서 다시 받습니다.
  Future<String> startSession({
    required String childId,
    required String storyId,
  }) => _client.post<String>(
    '/children/$childId/sessions',
    body: <String, dynamic>{'storyId': storyId},
    parse: (Object? data) {
      if (data is Map<String, dynamic>) {
        final String? sessionId = data['sessionId'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) return sessionId;
      }
      throw const ParseException('세션 시작 응답 형식이 올바르지 않습니다.');
    },
  );
}
