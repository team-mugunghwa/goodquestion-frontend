import 'dart:async';
import 'dart:typed_data';

import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';
import 'package:goodquestion/features/free_talk/domain/repositories/free_talk_repository.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

/// 백엔드가 아직 배포 전이라 화면 검증은 전부 이 가짜들로 합니다.
/// 계약 문서에 적힌 모양 그대로 돌려줍니다 — 실제 응답이 다르면 여기가
/// 먼저 어긋납니다.
class FakeFreeTalkRepository implements FreeTalkRepository {
  FakeFreeTalkRepository({
    this.charactersResult = const <FreeTalkCharacter>[],
    this.charactersError,
    this.startError,
    this.opening = const FreeTalkSpeech(
      text: '또 왔구나! 오늘은 무슨 얘기 할까?',
      audioUrl: '/tts/opening.mp3',
    ),
    this.turns = const <FreeTalkTurn>[],
    this.closing = const FreeTalkSpeech(
      text: '잘 가! 또 놀러 와.',
      audioUrl: '/tts/closing.mp3',
    ),
  });

  final List<FreeTalkCharacter> charactersResult;
  final Failure? charactersError;
  final Failure? startError;
  final FreeTalkSpeech opening;

  /// 발화 순서대로 돌려줄 응답. 다 쓰면 마지막 것을 반복합니다.
  final List<FreeTalkTurn> turns;
  final FreeTalkSpeech closing;

  int charactersCalls = 0;
  int startCalls = 0;
  int endCalls = 0;
  final List<String> sentTexts = <String>[];
  final List<String?> sentKeys = <String?>[];

  @override
  Future<List<FreeTalkCharacter>> characters(String storyId) async {
    charactersCalls++;
    final Failure? error = charactersError;
    if (error != null) throw error;
    return charactersResult;
  }

  @override
  Future<FreeTalkSession> start({
    required String storyId,
    required String characterId,
  }) async {
    startCalls++;
    final Failure? error = startError;
    if (error != null) throw error;
    return FreeTalkSession(
      freeTalkId: 'ft-1',
      character: charactersResult.isEmpty
          ? const FreeTalkCharacter(
              characterId: 'c-1',
              name: '방귀쟁이 며느리',
              characterKey: 'daughter_in_law',
            )
          : charactersResult.firstWhere(
              (FreeTalkCharacter it) => it.characterId == characterId,
              orElse: () => charactersResult.first,
            ),
      opening: opening,
      maxTurns: 10,
    );
  }

  @override
  Future<FreeTalkTurn> sendMessage(
    String freeTalkId, {
    required String text,
    String? idempotencyKey,
  }) async {
    sentTexts.add(text);
    sentKeys.add(idempotencyKey);
    if (turns.isEmpty) {
      return const FreeTalkTurn(
        characterMessage: FreeTalkSpeech(
          text: '그랬구나!',
          audioUrl: '/tts/turn.mp3',
        ),
        turnCount: 1,
        ended: false,
      );
    }
    final int index = (sentTexts.length - 1).clamp(0, turns.length - 1);
    return turns[index];
  }

  @override
  Future<FreeTalkSpeech> end(String freeTalkId) async {
    endCalls++;
    return closing;
  }
}

/// STT·TTS 만 쓰는 가짜. 자유 대화 화면은 학습 대화의 저장소를 이 둘 때문에
/// 함께 받습니다.
class FakeVoicePlayRepository implements PlayRepository {
  FakeVoicePlayRepository({
    this.transcription = const PlayTranscription(
      text: '나는 방귀가 세서 좋아!',
      confidence: 0.9,
      lowConfidence: false,
    ),
    this.transcribeError,
  });

  final PlayTranscription transcription;
  final Failure? transcribeError;

  final List<String> synthesized = <String>[];

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    final Failure? error = transcribeError;
    if (error != null) throw error;
    return transcription;
  }

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async {
    synthesized.add(text);
    return const PlaySpeechAudio(audioUrl: 'stub://audio');
  }

  // ── 아래는 자유 대화가 쓰지 않는 것들 ──

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<PlayMission?> currentMission(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) => throw UnimplementedError();

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<PlayPostActivityStart> startPostActivity(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<PlayCardOrderResult> submitCardOrder(
    String sessionId, {
    required List<String> submittedOrder,
  }) => throw UnimplementedError();

  @override
  Future<PlayRetellingResult> submitRetelling(
    String sessionId, {
    required String text,
    String? sttRawText,
  }) => throw UnimplementedError();

  @override
  Future<void> stop(String sessionId) => throw UnimplementedError();
}

class FakeVoiceRecorder implements MissionVoiceRecorder {
  const FakeVoiceRecorder();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}

class FakeAudioPlayer implements StoryAudioPlayer {
  const FakeAudioPlayer();

  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  @override
  bool get canResume => false;

  @override
  Future<void> playUrl(String url) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// 재생이 **끝나지 않고 붙잡혀 있는** 가짜.
///
/// 즉시 끝나 버리는 [FakeAudioPlayer] 로는 "대사를 다 읽은 뒤에 화면이
/// 바뀐다"를 확인할 수 없습니다 — 읽는 동안이라는 구간 자체가 없기 때문입니다.
/// 낭독이 끝나기 전에 엔드카드가 떠서 인사가 잘리는 사고는 실제로 있었습니다.
class ControlledAudioPlayer implements StoryAudioPlayer {
  Completer<void>? _pending;

  int playCalls = 0;

  /// 지금 재생 중인 대사를 끝냅니다.
  void finish() {
    final Completer<void>? pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  @override
  bool get canResume => false;

  @override
  Future<void> playUrl(String url) {
    playCalls++;
    final Completer<void> completer = Completer<void>();
    _pending = completer;
    return completer.future;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> stop() async => finish();

  @override
  Future<void> dispose() async => finish();
}
