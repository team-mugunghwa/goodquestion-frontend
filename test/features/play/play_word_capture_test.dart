import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/features/play/data/dialogue_word_capture.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

/// 고정 대사 단어 담기.
///
/// 아이가 모르는 단어를 만나는 곳이 바로 이야기 화면인데, 지금까지는 그 자리에서
/// 담을 방법이 없었다. 고정 대사(DB 원문)일 때만 단어를 눌러 단어장에 담고,
/// LLM이 만든 동적 대사는 오탈자·오인식 반영 가능성이 있어 담기지 않아야 한다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required PlayRepository repository,
    DialogueWordCapture? wordCapture,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayPage(
          sessionId: 'test-session',
          repository: repository,
          voiceRecorder: const _FakeRecorder(),
          audioPlayer: const _FakeAudioPlayer(),
          wordCapture: wordCapture,
        ),
      ),
    );
  }

  /// 첫 대사 재생이 끝나 화면이 자리 잡을 때까지. 대화 장면은 주기 타이머가
  /// 돌아 pumpAndSettle 이 정착하지 않으므로 직접 굴립니다.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('고정 대사의 단어를 누르면 확인 줄이 뜨고, 담기를 누르면 장면과 예문이 함께 간다', (
    WidgetTester tester,
  ) async {
    final _SpyWordCapture capture = _SpyWordCapture()..lemma = '기왓장';
    await pump(tester, repository: _DialogueRepository(), wordCapture: capture);
    await settle(tester);

    // 고정 대사가 단어 단위로 떠 있다. 말풍선은 지금 읽는 문장만 보여주므로
    // 오프닝을 한 문장으로 두었다 - 여러 문장이면 마지막 문장만 남는다.
    expect(find.text('기왓장이'), findsOneWidget);

    await tester.tap(find.text('기왓장이'));
    await tester.pump();
    // 구두점만 걷어내고 조사는 그대로 둔다 - "마을"의 "을"처럼 낱말 일부를
    // 조사로 오인해 훼손하는 것보다 조사째 담는 쪽이 안전하다.
    expect(find.text("'기왓장이' 단어장에 담을까요?"), findsOneWidget);

    await tester.tap(find.text('담기'));
    await tester.pump();
    await tester.pump();

    expect(capture.savedWords, <String>['기왓장이']);
    expect(capture.lastSourceSceneId, 'scene-3');
    expect(
      capture.lastExampleSentence,
      '기왓장이 들썩이면 어떻게 하면 좋을까?',
      reason: '예문은 아이가 단어를 고른 그 대사 문장이어야 합니다',
    );
    // 안내는 서버가 실제 저장한 표제어로 한다 - 단어장 화면과 같은 형태.
    expect(find.text("'기왓장' 단어장에 담았어요"), findsOneWidget);
  });

  testWidgets('그냥 둘게요를 누르면 아무것도 담기지 않는다', (WidgetTester tester) async {
    final _SpyWordCapture capture = _SpyWordCapture();
    await pump(tester, repository: _DialogueRepository(), wordCapture: capture);
    await settle(tester);

    await tester.tap(find.text('기왓장이'));
    await tester.pump();
    await tester.tap(find.text('그냥 둘게요'));
    await tester.pump();

    expect(capture.savedWords, isEmpty);
    expect(find.text("'기왓장이' 단어장에 담을까요?"), findsNothing);
  });

  testWidgets('이미 담아 둔 단어는 이미 있다고 안내한다', (WidgetTester tester) async {
    final _SpyWordCapture capture = _SpyWordCapture()
      ..result = WordCaptureResult.duplicate;
    await pump(tester, repository: _DialogueRepository(), wordCapture: capture);
    await settle(tester);

    await tester.tap(find.text('기왓장이'));
    await tester.pump();
    await tester.tap(find.text('담기'));
    await tester.pump();
    await tester.pump();

    expect(find.text("'기왓장이' 이미 담아 둔 단어예요"), findsOneWidget);
  });

  testWidgets('동적 대사(캐릭터 답변)도 단어를 담을 수 있고, 예문은 보내지 않는다', (
    WidgetTester tester,
  ) async {
    // 동적 대사의 오인식 단어는 서버 유효성 관문(INVALID_WORD)이 거른다.
    // 예문은 비워 보낸다 - 동적 문장에는 아이 발화의 오인식 인용이 섞일 수
    // 있어 서버가 사전/생성 예문으로 채우는 쪽이 안전하다.
    final _SpyWordCapture capture = _SpyWordCapture();
    await pump(tester, repository: _DialogueRepository(), wordCapture: capture);
    await settle(tester);

    // 발화를 제출하면 동적 답변으로 바뀐다.
    await tester.tap(find.byTooltip('말하기 완료'));
    await settle(tester);

    await tester.tap(find.text('지붕을'));
    await tester.pump();
    await tester.tap(find.text('담기'));
    await tester.pump();
    await tester.pump();

    expect(capture.savedWords, <String>['지붕을']);
    expect(
      capture.lastExampleSentence,
      isNull,
      reason: '동적 대사의 문장은 예문으로 보내지 않습니다',
    );
    expect(capture.lastSourceSceneId, 'scene-3');
  });

  testWidgets('서버가 실제 단어가 아니라고 하면(INVALID_WORD) 안내하고 흐름은 그대로다', (
    WidgetTester tester,
  ) async {
    final _SpyWordCapture capture = _SpyWordCapture()
      ..failure = const ServerFailure(
        message: '단어장에 담기 어려운 말입니다.',
        code: 'INVALID_WORD',
      );
    await pump(tester, repository: _DialogueRepository(), wordCapture: capture);
    await settle(tester);

    await tester.tap(find.text('기왓장이'));
    await tester.pump();
    await tester.tap(find.text('담기'));
    await tester.pump();
    await tester.pump();

    expect(find.text('이 말은 단어장에 담기 어려워요. 다른 단어를 골라 볼까?'), findsOneWidget);
    expect(find.byTooltip('나가기'), findsOneWidget, reason: '대화 화면은 그대로여야 합니다');
  });

  testWidgets('담기 통로가 없으면(wordCapture null) 고정 대사도 통짜 글로 그린다', (
    WidgetTester tester,
  ) async {
    await pump(tester, repository: _DialogueRepository());
    await settle(tester);

    expect(find.textContaining('기왓장이 들썩이면'), findsOneWidget);
    expect(find.text('기왓장이'), findsNothing);
  });
}

/// 대화 장면 하나를 여는 저장소. 발화를 제출하면 동적 답변을 돌려준다.
class _DialogueRepository implements PlayRepository {
  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-3',
          sceneOrder: 3,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '기왓장이 들썩이면 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '기왓장이 들썩이면 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(
        text: '지붕을 고쳐 줘요',
        confidence: .9,
        lowConfidence: false,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://audio');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async => const PlayTurnResult(
    characterText: '멋진 생각이야 지붕을 고치면 되겠다',
    characterAudioUrl: null,
    mission: null,
    sceneTransition: null,
  );

  @override
  Future<PlayPostActivityStart> startPostActivity(String sessionId) async =>
      const PlayPostActivityStart(
        cards: <PlayPostActivityCard>[],
        attemptCount: 0,
      );

  @override
  Future<PlayCardOrderResult> submitCardOrder(
    String sessionId, {
    required List<String> submittedOrder,
  }) async => const PlayCardOrderResult(correct: true);

  @override
  Future<PlayRetellingResult> submitRetelling(
    String sessionId, {
    required String text,
    String? sttRawText,
  }) async => const PlayRetellingResult(sessionStatus: 'COMPLETED');

  @override
  Future<void> stop(String sessionId) async {}
}

class _SpyWordCapture implements DialogueWordCapture {
  WordCaptureResult result = WordCaptureResult.saved;
  Failure? failure;
  final List<String> savedWords = <String>[];
  String? lastSourceSceneId;
  String? lastExampleSentence;

  /// 서버 표제어 정규화 흉내 - 지정하면 저장 단어로 이 값을 돌려준다.
  String? lemma;

  @override
  Future<WordCaptureOutcome> save({
    required String word,
    String? sourceSceneId,
    String? exampleSentence,
  }) async {
    final Failure? pending = failure;
    if (pending != null) throw pending;
    savedWords.add(word);
    lastSourceSceneId = sourceSceneId;
    lastExampleSentence = exampleSentence;
    return WordCaptureOutcome(result, savedWord: lemma ?? word);
  }
}

class _FakeRecorder implements MissionVoiceRecorder {
  const _FakeRecorder();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}

class _FakeAudioPlayer implements StoryAudioPlayer {
  const _FakeAudioPlayer();

  @override
  Future<void> playUrl(String url) async {}

  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  @override
  bool get canResume => false;

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
