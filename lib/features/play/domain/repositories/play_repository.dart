import 'dart:typed_data';

import '../entities/play_session.dart';

abstract interface class PlayRepository {
  Future<PlaySessionSnapshot> resume(String sessionId);

  Future<PlaySessionSnapshot> completeStoryScene(String sessionId);

  Future<PlayOpeningMessage> openCurrentScene(String sessionId);

  Future<PlayMission?> currentMission(String sessionId);

  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes);

  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    required String characterName,
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
