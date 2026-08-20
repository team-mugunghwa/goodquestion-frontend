import '../../../../core/network/dio_client.dart';
import '../../domain/entities/free_talk.dart';
import '../dtos/free_talk_dto.dart';

/// 자유 대화 엔드포인트 다섯 개.
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

  /// 인사 없이 대화만 닫습니다("바로 나가기"). 본문 없이 **204** 가 옵니다.
  ///
  /// [end] 와 굳이 갈라 둔 이유는 [end] 가 작별 대사를 **지어서** 옵니다 —
  /// 모델 왕복이 붙고 값도 나갑니다. 그냥 나가려는 아이에게는 그 문장이
  /// 필요 없으니, 여기서는 서버가 `ended_at` 만 찍으면 됩니다.
  ///
  /// 경로·상태코드는 백엔드 `FreeTalkController.leave` 와 대조해 확인했습니다.
  Future<void> leave(String freeTalkId) =>
      _client.post<void>('/free-talk/$freeTalkId/leave', parse: (_) {});
}
