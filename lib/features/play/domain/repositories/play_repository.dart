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
  });
}
