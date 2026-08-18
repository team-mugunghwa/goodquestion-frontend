import '../../../../core/network/dio_client.dart';
import '../../domain/entities/free_talk.dart';
import '../dtos/free_talk_dto.dart';

/// 자유 대화 엔드포인트 네 개.
///
/// 인물 목록·시작은 아이 아래(`/children/{childId}/...`)에 있고, 대화가
/// 시작된 뒤에는 `freeTalkId` 하나로 식별합니다 — 서버가 그 대화의 주인을
/// 이미 알고 있어서 아이 식별자를 다시 실을 이유가 없습니다.
class FreeTalkRemoteDataSource {
  const FreeTalkRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<FreeTalkCharacter>> characters({
    required String childId,
    required String storyId,
  }) => _client.get<List<FreeTalkCharacter>>(
    '/children/$childId/stories/$storyId/free-talk/characters',
    parse: FreeTalkDto.characters,
  );

  Future<FreeTalkSession> start({
    required String childId,
    required String storyId,
    required String characterId,
    FreeTalkCharacter? requested,
  }) => _client.post<FreeTalkSession>(
    '/children/$childId/free-talk',
    body: <String, Object?>{'storyId': storyId, 'characterId': characterId},
    parse: (Object? data) => FreeTalkDto.session(data, requested: requested),
  );

  /// 같은 말이 두 번 저장되지 않게 [idempotencyKey] 를 헤더로 싣습니다.
  /// 학습 대화의 발화 제출과 같은 규칙입니다.
  Future<FreeTalkTurn> sendMessage(
    String freeTalkId, {
    required String text,
    String? idempotencyKey,
  }) => _client.post<FreeTalkTurn>(
    '/free-talk/$freeTalkId/messages',
    body: <String, Object?>{'text': text},
    headers: idempotencyKey != null
        ? <String, dynamic>{'Idempotency-Key': idempotencyKey}
        : null,
    parse: FreeTalkDto.turn,
  );

  Future<FreeTalkSpeech> end(String freeTalkId) => _client.post<FreeTalkSpeech>(
    '/free-talk/$freeTalkId/end',
    parse: FreeTalkDto.closing,
  );
}
