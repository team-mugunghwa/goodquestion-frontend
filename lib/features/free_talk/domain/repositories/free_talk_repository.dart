import '../entities/free_talk.dart';

/// 후속 자유 대화 통로.
///
/// **음성(STT·TTS)은 여기에 없습니다.** 아이 말을 글로 바꾸는 것과 캐릭터
/// 대사를 소리로 만드는 것은 학습 대화와 완전히 같은 `/api/stt` · `/api/tts`
/// 를 쓰고, 그 통로가 이미 `PlayRepository` 에 있습니다. 같은 엔드포인트를
/// 두 인터페이스로 갈라 두면 한쪽만 고쳐지는 날이 옵니다.
/// → 후속대화 설계 문서 「API 계약」
abstract interface class FreeTalkRepository {
  /// 그 이야기에서 말을 걸 수 있는 인물 목록.
  ///
  /// 완주하지 않은 이야기면 서버가 404 로 돌려세웁니다 — 예외로 올라오고,
  /// 화면이 "아직 이야기를 다 안 들었어"로 바꿔 말합니다.
  Future<List<FreeTalkCharacter>> characters(String storyId);

  /// 대화 시작. 첫 대사까지 함께 받습니다.
  Future<FreeTalkSession> start({
    required String storyId,
    required String characterId,
  });

  /// 아이 발화 한 번.
  ///
  /// [idempotencyKey] 는 **한 발화당 하나**입니다. 재시도 사이에는 같은 키를
  /// 유지해야 같은 말이 두 번 저장되지 않습니다. (학습 대화의 발화 제출과
  /// 같은 규칙 → `docs/이야기_전개_가이드.md` 3.4)
  Future<FreeTalkTurn> sendMessage(
    String freeTalkId, {
    required String text,
    String? idempotencyKey,
  });

  /// 아이가 먼저 그만두겠다고 했을 때. 캐릭터의 마무리 인사를 받습니다.
  ///
  /// 서버가 [FreeTalkTurn.ended] 로 이미 닫은 대화에는 **부르지 않습니다** —
  /// 그때는 마지막 대사가 곧 인사라, 또 부르면 작별 인사를 두 번 합니다.
  Future<FreeTalkSpeech> end(String freeTalkId);

  /// 인사 없이 대화만 닫습니다. 아이가 "바로 나가기"를 골랐을 때.
  ///
  /// [end] 와 달리 **돌려주는 것이 없습니다** — 작별 대사를 짓지 않기
  /// 때문입니다. 화면은 이 future 를 기다리지 않고 곧장 떠나므로 실패도
  /// 아이에게 보이지 않습니다. 그런데도 굳이 부르는 이유는, 안 닫으면 그
  /// 대화가 `ended_at` 없이 영영 열린 채로 남기 때문입니다.
  Future<void> leave(String freeTalkId);
}
