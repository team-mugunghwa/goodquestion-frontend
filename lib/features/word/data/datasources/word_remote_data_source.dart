import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/word_response_dto.dart';

/// 단어장 API. → `docs/API.md` 2.12
class WordRemoteDataSource {
  const WordRemoteDataSource(this._client);

  final DioClient _client;

  /// 담은 단어 전체. **분류로 거르지 않습니다** — `entryType` 을 넘기면
  /// 하트를 켠 단어가 목록에서 빠집니다.
  Future<List<WordResponseDto>> fetchWords(String childId) =>
      _client.get<List<WordResponseDto>>(
        '/children/$childId/words',
        parse: (Object? data) {
          if (data is! List<dynamic>) {
            throw const ParseException('단어 목록 응답 형식이 올바르지 않습니다.');
          }
          return data
              .whereType<Map<String, dynamic>>()
              .map(WordResponseDto.fromJson)
              .toList(growable: false);
        },
      );

  /// 모르는 말 ↔ 좋아하는 말. 바뀐 단어를 그대로 돌려받습니다.
  Future<WordResponseDto> toggleFavorite(String childId, String wordId) =>
      _client.patch<WordResponseDto>(
        '/children/$childId/words/$wordId/favorite',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return WordResponseDto.fromJson(data);
          }
          throw const ParseException('단어 응답 형식이 올바르지 않습니다.');
        },
      );
}
