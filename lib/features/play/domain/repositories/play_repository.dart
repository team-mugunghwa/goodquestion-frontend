import 'dart:typed_data';

import '../entities/play_session.dart';

abstract interface class PlayRepository {
  Future<PlaySessionSnapshot> resume(String sessionId);

  Future<PlaySessionSnapshot> completeStoryScene(String sessionId);

  Future<PlayOpeningMessage> openCurrentScene(String sessionId);

  Future<PlayMission?> currentMission(String sessionId);

  /// **한 장면의** 대화 기록. `resume` 이 주는 `messages` 는 세션 전체라
  /// 이전 장면 발화까지 섞여 있고, `MessageResponse` 에는 장면 식별자가
  /// 없어 그 목록만으로는 장면을 갈라낼 수 없습니다(`turnOrder` 도 장면이
  /// 바뀌어도 이어집니다 → `docs/API.md` MessageResponse). 그래서 장면으로
  /// 걸러 주는 이 엔드포인트를 씁니다.
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  });

  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes);

  /// [characterName] 이 있으면 캐릭터 보이스로, 없으면(null) 내레이션
  /// 보이스로 합성합니다. → `docs/이야기_전개_가이드.md` 3.2
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  });

  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  });

  /// 아이가 "그만하기"를 눌렀을 때만 부릅니다. **되돌릴 수 없습니다** — 세션이
  /// STOPPED 로 바뀌고 이어하기 목록에서도 사라집니다. 앱 이탈·백그라운드
  /// 전환에는 부르지 않습니다(그래야 이어하기가 삽니다). → `docs/이야기_전개_가이드.md` 3.8
  Future<void> stop(String sessionId);
}
