import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';

/// `학습.wordbook` 서버 엔드포인트. → `docs/API.md` 2.12
class WordRemoteDataSource {
  const WordRemoteDataSource(this._client);

  final DioClient _client;

  /// `entryType` 을 안 보내면 전체(UNKNOWN + FAVORITE)가 옵니다.
  Future<List<Map<String, dynamic>>> getWords(String childId) =>
      _client.get<List<Map<String, dynamic>>>(
        '/children/$childId/words',
        parse: (Object? data) => (data as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );

  /// `UNKNOWN` ↔ `FAVORITE` 를 뒤집습니다. 바뀐 단어를 그대로 돌려받습니다.
  Future<Map<String, dynamic>> toggleFavorite({
    required String childId,
    required String wordId,
  }) => _client.patch<Map<String, dynamic>>(
    '/children/$childId/words/$wordId/favorite',
    parse: (Object? data) {
      if (data is Map<String, dynamic>) return data;
      throw const ParseException('단어 응답 형식이 올바르지 않습니다.');
    },
  );
}
