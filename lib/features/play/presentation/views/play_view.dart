import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/stt_choice_catalog.dart';
import '../../data/stt_choice_selector.dart';
import '../../domain/entities/play_session.dart';
import '../../domain/repositories/play_repository.dart';
import '../character/dialogue_character_manifest.dart';
import '../character/dialogue_character_stage.dart';
import '../character/dialogue_character_state_machine.dart';
import '../voice/mission_voice_recorder.dart';
import '../voice/story_audio_player.dart';
import '../widgets/mission_overlay.dart';
import '../widgets/stt_choice_panel.dart';

/// 모든 이야기가 공유하는 대화 장면 템플릿입니다.
///
/// 서버 연결 후에는 장면 응답으로 [backgroundAsset], [characterAsset],
/// [characterName], [question]을 채우면 됩니다. 질문과 아이 답변은 항상
/// 한 문장만 화면에 노출합니다.
class PlayPage extends StatefulWidget {
  const PlayPage({
    required this.sessionId,
    this.totalScenes,
    this.backgroundAsset,
    this.characterAsset,
    this.characterName = '이야기 친구',
    this.question = '이럴 때는 어떻게 하면 좋을까?',
    this.repository,
    this.voiceRecorder,
    this.audioPlayer,
    super.key,
  });

  final String sessionId;

  /// 이 이야기의 전체 장면 수. 상단 진행바가 "몇 번째 장면인지"를 그리는 데
  /// 씁니다.
  ///
  /// **세션 API 가 안 내려줍니다** - `SessionResumeResponse`·`SceneAdvanceResponse`
  /// 어디에도 총 장면 수가 없고, 홈의 `inProgressSession.totalScenes` 와 이야기
  /// 상세의 `sceneCount` 에만 있습니다. 그래서 화면을 여는 쪽(홈 이어하기 ·
  /// 이야기 상세 시작하기)이 값을 실어 보냅니다. 주소창으로 바로 들어오는
  /// 등 값이 없으면 `null` 이고, 진행바는 눈금 없이 빈 막대로 둡니다.
  /// → `docs/API.md` 3.6
  final int? totalScenes;
  final String? backgroundAsset;
  final String? characterAsset;
  final String characterName;
  final String question;
  final PlayRepository? repository;
  final MissionVoiceRecorder? voiceRecorder;
  final StoryAudioPlayer? audioPlayer;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

enum _DialoguePhase { characterSpeaking, listening, paused }

class _PlayPageState extends State<PlayPage> {
  _DialoguePhase _phase = _DialoguePhase.characterSpeaking;
  _DialoguePhase _phaseBeforePause = _DialoguePhase.characterSpeaking;
  Timer? _questionTimer;
  Timer? _listeningTimer;
  Timer? _storyTimer;
  late final MissionVoiceRecorder _voiceRecorder;
  late final StoryAudioPlayer _audioPlayer;
  int _listeningSeconds = 0;
  bool _soundOn = true;
  bool _loadingSession = false;
  bool _advancingScene = false;
  bool _storyPaused = false;
  int _narrationIndex = 0;
  String? _loadError;
  PlaySessionSnapshot? _snapshot;
  PlayMission? _mission;
  String? _characterReply;
  bool _submittingUtterance = false;
  bool _submittingMission = false;
  bool _missionCompleted = false;
  bool _recordingVoice = false;
  bool _transcribingVoice = false;
  List<String> _characterSentences = const <String>[];
  int _characterSentenceIndex = 0;
  int _speechToken = 0;

  /// 캐릭터 대사 루프가 아직 살아 있는지. 일시정지를 풀 때 이 값이 true 면
  /// 루프가 스스로 이어 읽으므로 대사를 다시 틀어 주지 않습니다.
  bool _speaking = false;

  /// 일시정지 동안 대사 루프를 붙잡아 두는 문. → [_awaitResume]
  Completer<void>? _pauseGate;

  /// 지금 기다리고 있는 "무음으로 읽는 시간". 일시정지·다음 대사에서
  /// 곧바로 풀어 주려고 들고 있습니다. → [_waitForSpeech] · [_waitForNarration]
  Completer<void>? _speechWait;
  Completer<void>? _narrationWait;
  String? _lastChildText;
  bool _lastSttLowConfidence = false;

  /// 이번 발화를 몇 번 다시 녹음했는지. 무음/저신뢰로 다시 말했을 때마다
  /// 늘어나고, 제출한 뒤/새 차례가 시작되면 0으로 돌아갑니다. 제출 시
  /// `sttRetryCount` 로 그대로 실어 보냅니다. → `docs/이야기_전개_가이드.md` 3.4
  int _sttRetryCount = 0;

  /// 422 STT_EMPTY_TEXT(무음/인식 실패) 나 로컬 녹음 실패일 때만 씁니다.
  /// 화면 전체를 에러로 바꾸지 않고 마이크 옆에 짧게 띄웁니다 - 아이가 자주
  /// 겪을 수 있는 흔한 상황이라 화면이 통째로 바뀌면 매번 놀랍니다.
  ///
  /// 안내 음성이 준비된 장면(3·5·7·9)에서는 이 자리를 쓰지 않습니다 -
  /// 캐릭터가 직접 다시 물어보고, 그 말이 말풍선에 뜹니다. → [_speakGuide]
  String? _sttHint;

  /// 직전 턴 응답의 진행 상황. 두 번째 턴부터는 "아직 못 채운 요소"
  /// (`progress.missingElements`)로 문장 카드를 고릅니다.
  ///
  /// **장면이 바뀌면 비웁니다**([_activateSnapshot]) - 안 비우면 새 장면의
  /// 첫 턴에서 남의 장면 요소로 카드를 고릅니다.
  PlayProgress? _lastTurnProgress;

  /// 세 번 이어서 못 알아들어 내려놓은 문장 카드. 비어 있으면 선택지 모드가
  /// 아닙니다. **빈 목록으로 판을 띄우지 않습니다.**
  List<SttChoiceSentence> _choiceCards = const <SttChoiceSentence>[];

  /// 지금 스피커로 들려주고 있는 카드.
  String? _playingChoiceId;

  /// 안내 음성이 나오는 중. 이때는 마이크를 못 누르게 막습니다 - 안 막으면
  /// 캐릭터 목소리가 그대로 녹음됩니다.
  bool _guideSpeaking = false;

  /// 아이의 확인을 기다리는 변환 결과. null 이 아니면 확인 화면이 뜨고
  /// 마이크는 잠깁니다 - "맞아요"를 눌러야 비로소 턴이 제출됩니다.
  ///
  /// 변환 결과를 받자마자 제출하면 오인식을 되돌릴 방법이 없습니다. 턴이
  /// 처리되고 캐릭터가 대답한 뒤라, 아이가 하지 않은 말이 저장되고 보호자
  /// 리포트 대표 발화 후보에도 오릅니다. 저신뢰 안내가 의미 있는 유일한
  /// 시점도 제출 전이라 여기서 한 번 끊습니다. → 백엔드
  /// `docs/트러블슈팅_STT_신뢰도_산출.md` 3절
  PlayTranscription? _pendingTranscription;
  String? _retainedStoryImageUrl;

  /// 지금 화면이 붙잡고 있는 장면. 장면이 바뀌는 순간을 [_activateSnapshot]
  /// 이 알아채고 이전 장면의 아이 발화를 지우는 데 씁니다.
  String? _activeSceneId;
  String? _resultImageUrl;
  DialogueCharacterManifest? _characterManifest;
  DialogueCharacterStateMachine? _character;

  /// 지금 보내고 있는 발화의 Idempotency-Key. 응답을 받으면(성공이든 최종
  /// 실패든) `null`로 되돌립니다 — 재시도 사이에는 같은 키를 유지하고,
  /// 다음 발화는 새 키를 받게 하기 위해서입니다. → `docs/이야기_전개_가이드.md` 3.4
  String? _pendingIdempotencyKey;

  bool get _isListening => _phase == _DialoguePhase.listening;

  /// 캐릭터가 지금 무엇을 하고 있는지. 표정과 별개로 모션만 바꾼다.
  DialogueActivity get _activity {
    if (_phase == _DialoguePhase.paused) return DialogueActivity.idle;
    if (_submittingUtterance || _transcribingVoice) {
      return DialogueActivity.thinking;
    }
    if (_phase == _DialoguePhase.listening) return DialogueActivity.listening;
    return DialogueActivity.speaking;
  }

  @override
  void initState() {
    super.initState();
    _voiceRecorder = widget.voiceRecorder ?? DeviceMissionVoiceRecorder();
    _audioPlayer = widget.audioPlayer ?? DeviceStoryAudioPlayer();
    unawaited(_loadCharacterManifest());
    if (widget.repository == null) {
      _playQuestion();
    } else {
      unawaited(_loadSession());
    }
  }

  /// 에셋 매니페스트는 없어도 화면이 죽지 않아야 한다 - 실패하면 기존 배경 한 장짜리 화면으로
  /// 굴러간다. 그래서 로드 실패를 _loadError로 올리지 않는다.
  Future<void> _loadCharacterManifest() async {
    try {
      final DialogueCharacterManifest manifest =
          await DialogueCharacterManifest.load();
      if (!mounted) return;
      setState(() => _characterManifest = manifest);
      _bindCharacterScene();
    } on Object {
      // 무시한다.
    }
  }

  /// 현재 대화 장면에 맞는 상태머신을 붙인다. 장면이 그대로면 진행 중인 표정을 유지한다.
  void _bindCharacterScene() {
    final DialogueCharacterManifest? manifest = _characterManifest;
    final PlayScene? scene = _snapshot?.currentScene;
    if (manifest == null ||
        scene == null ||
        scene.sceneType != PlaySceneType.dialogue) {
      if (_character != null) setState(() => _character = null);
      return;
    }
    final DialogueSceneStates? states = manifest.sceneFor(
      sceneId: scene.sceneId,
      sceneOrder: scene.sceneOrder,
    );
    if (states == null) {
      if (_character != null) setState(() => _character = null);
      return;
    }
    if (_character?.scene == states) return;

    final DialogueCharacterStateMachine machine = DialogueCharacterStateMachine(
      states,
      manifest,
    );
    // 이어하기로 들어오면 앞선 턴의 누적은 "새로 충족"이 아니다.
    machine.primeAccumulated(_accumulatedFromMessages());
    setState(() => _character = machine);

    // 표정이 늦게 뜨면 턴이 끊긴 것처럼 보인다. 장면에 들어올 때 한 번에 캐시한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final String asset in states.allAssets) {
        unawaited(precacheImage(AssetImage(asset), context));
      }
    });
  }

  /// 이어하기 복원용. 서버가 누적 요소를 스냅샷으로 주지 않으므로 지금은 빈 값이고,
  /// 첫 턴 응답의 progress로 맞춰진다.
  Iterable<String> _accumulatedFromMessages() => const <String>[];

  @override
  void dispose() {
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    _storyTimer?.cancel();
    // 화면을 떠나면 기다리던 발화 루프들도 풀어 줍니다 - 안 풀면 취소된
    // 타이머·닫힌 문 앞에서 영영 매달린 채로 남습니다.
    _releaseSpeechWait();
    _releaseNarrationWait();
    _openPauseGate();
    unawaited(_voiceRecorder.dispose());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loadingSession = true;
      _loadError = null;
    });
    try {
      final PlaySessionSnapshot snapshot = await widget.repository!.resume(
        widget.sessionId,
      );
      final PlayMission? recoveredMission =
          snapshot.mission ??
          await widget.repository!.currentMission(widget.sessionId);
      final PlayMessage? recoveredChild = await _lastChildMessageOfCurrentScene(
        snapshot,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _mission = recoveredMission;
        _characterReply = null;
        _lastChildText = recoveredChild?.text;
        _lastSttLowConfidence = recoveredChild?.sttLowConfidence ?? false;
        // 복원한 발화는 이 장면의 것입니다 - 이어서 부르는
        // [_activateSnapshot] 이 "장면이 바뀌었다"로 보고 지우면 안 됩니다.
        _activeSceneId = snapshot.currentScene?.sceneId;
        _loadingSession = false;
      });
      _activateSnapshot(snapshot);
    } on Failure catch (error) {
      // resume 자체가 실패하면 다시 resume 을 부를 수 없습니다 - 여기서는
      // 자동 복구를 시도하지 않고 메시지만 보여줍니다.
      if (!mounted) return;
      setState(() {
        _loadingSession = false;
        _loadError = _describeFailure(error);
      });
    }
  }

  /// 이어하기로 들어왔을 때 화면에 되살릴 **이 장면의** 마지막 아이 발화.
  ///
  /// `resume` 의 `messages` 를 쓰면 안 됩니다 - 세션 전체 기록이라 이전
  /// 장면 발화까지 들어 있고, `MessageResponse` 에는 장면 식별자가 없어
  /// 그 목록만으로는 어디서 장면이 갈렸는지 알 수 없습니다(`turnOrder` 도
  /// 장면을 넘어 이어집니다). "마지막 캐릭터 메시지 바로 앞이면 이번 장면"
  /// 같은 어림짐작은 마무리 반응이 함께 저장되는 턴에서 틀립니다. 그래서
  /// 장면으로 걸러 주는 `sceneMessages` 를 부릅니다.
  ///
  /// 이건 복원용 곁들이라 실패해도 이어하기를 막지 않습니다 - 발화만 비운
  /// 채로 대화를 이어 갑니다.
  Future<PlayMessage?> _lastChildMessageOfCurrentScene(
    PlaySessionSnapshot snapshot,
  ) async {
    final String? sceneId = snapshot.currentScene?.sceneId;
    // 전개(STORY) 장면에는 아이 발화를 띄우는 자리가 없습니다.
    if (sceneId == null || snapshot.phase != PlayPhase.dialogue) return null;
    try {
      final List<PlayMessage> messages = await widget.repository!.sceneMessages(
        widget.sessionId,
        sceneId: sceneId,
      );
      PlayMessage? last;
      for (final PlayMessage message in messages) {
        if (message.speaker == PlaySpeaker.child) last = message;
      }
      return last;
    } on Object catch (error) {
      debugPrint('[play] sceneMessages failed, skipping restore: $error');
      return null;
    }
  }

  void _activateSnapshot(PlaySessionSnapshot snapshot) {
    _storyTimer?.cancel();
    // 장면이 바뀌면 이전 장면에서 아이가 한 말은 지웁니다 - 새 캐릭터가
    // 말을 거는데 아직 하지도 않은 대답이 떠 있으면 안 됩니다. 같은 장면을
    // 다시 활성화하는 경우(이어하기 복원)에는 그대로 둡니다.
    final String? sceneId = snapshot.currentScene?.sceneId;
    if (sceneId != _activeSceneId) {
      setState(() {
        _activeSceneId = sceneId;
        _lastChildText = null;
        _lastSttLowConfidence = false;
        _sttHint = null;
        _sttRetryCount = 0;
        // 선택지도 장면과 함께 접습니다 - 카드는 그 장면의 문장이고,
        // 진행 상황도 그 장면에서만 뜻이 있습니다.
        _closeChoicesState();
        _lastTurnProgress = null;
      });
    }
    _bindCharacterScene();
    if (snapshot.phase == PlayPhase.postActivity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.playRecapOf(widget.sessionId));
      });
      return;
    }
    if (snapshot.phase == PlayPhase.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.home);
      });
      return;
    }
    if (snapshot.phase == PlayPhase.story) {
      _retainedStoryImageUrl = snapshot.currentScene?.imageUrl;
      _narrationIndex = 0;
      _storyPaused = false;
      _scheduleCurrentNarration();
      return;
    }
    if ((snapshot.openingText ?? '').trim().isNotEmpty) {
      _characterReply = snapshot.openingText;
      unawaited(
        _playCharacterMessage(
          snapshot.openingText!,
          audioUrl: snapshot.openingAudioUrl,
          onComplete: _startListening,
        ),
      );
    } else {
      unawaited(_loadOpeningMessage());
    }
  }

  Future<void> _loadOpeningMessage() async {
    final PlayRepository? repository = widget.repository;
    if (repository == null) {
      await _playQuestion();
      return;
    }
    try {
      final PlayOpeningMessage opening = await repository.openCurrentScene(
        widget.sessionId,
      );
      if (!mounted) return;
      setState(() => _characterReply = opening.text);
      await _playCharacterMessage(
        opening.text,
        audioUrl: opening.audioUrl,
        onComplete: _startListening,
      );
    } on Failure catch (error) {
      if (!mounted) return;
      if (await _tryAutoRecover(error)) return;
      setState(() => _loadError = _describeFailure(error));
    }
  }

  String get _visibleCharacterText {
    if (_characterSentences.isNotEmpty) {
      return _characterSentences[_characterSentenceIndex.clamp(
        0,
        _characterSentences.length - 1,
      )];
    }
    return _characterReply ?? _snapshot?.openingText ?? widget.question;
  }

  /// 아이 발화 한 번을 보냅니다. 선택지에서 고른 문장도 **같은 길**로
  /// 나갑니다 - 정상 1턴으로 세어지고 미션 오버레이도 그대로 뜹니다.
  ///
  /// [sttRetryCount] 는 선택지 제출에서만 넘깁니다(항상 3). 평소 발화는
  /// 화면이 세고 있던 [_sttRetryCount] 를 그대로 씁니다.
  Future<void> _submitDialogue(
    String text, {
    String? sttRawText,
    double? sttConfidence,
    bool lowConfidence = false,
    int? sttRetryCount,
  }) async {
    final String normalized = text.trim();
    if (normalized.isEmpty ||
        _submittingUtterance ||
        widget.repository == null) {
      return;
    }
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    setState(() {
      _submittingUtterance = true;
      _phase = _DialoguePhase.characterSpeaking;
      _loadError = null;
      _sttHint = null;
      _lastChildText = normalized;
      _lastSttLowConfidence = lowConfidence;
    });
    try {
      final PlayTurnResult result = await _submitUtteranceWithRetry(
        text: normalized,
        sttRawText: sttRawText,
        sttConfidence: sttConfidence,
        sttRetryCount: sttRetryCount ?? _sttRetryCount,
      );
      if (!mounted) return;
      setState(() {
        _submittingUtterance = false;
        _transcribingVoice = false;
        _characterReply = result.characterText;
        // 말이 나갔으니 이번 발화는 끝났습니다. 3회 세기는 한 발화 단위라
        // 여기서 0으로 돌리고 선택지도 접습니다.
        _sttRetryCount = 0;
        _closeChoicesState();
      });
      await _presentTurnResult(result);
    } on Failure catch (error) {
      if (!mounted) return;
      if (await _tryAutoRecover(error)) {
        setState(() {
          _submittingUtterance = false;
          _transcribingVoice = false;
        });
        return;
      }
      setState(() {
        _submittingUtterance = false;
        _transcribingVoice = false;
        _loadError = _describeFailure(error);
      });
    }
  }

  /// [_submitDialogue]와 [_submitMission]이 공유하는 발화 제출.
  ///
  /// Idempotency-Key 는 발화 하나당 하나입니다 - 최초 생성 후 재시도 사이에는
  /// 그대로 유지하고, 응답을 받으면(성공이든 최종 실패든) 비워서 다음 발화가
  /// 새 키를 받게 합니다. `REQUEST_IN_PROGRESS`(같은 키의 요청이 아직 처리
  /// 중)만 같은 키로 재시도합니다 - 그 외 실패는 그대로 올립니다.
  /// → `docs/이야기_전개_가이드.md` 3.4
  Future<PlayTurnResult> _submitUtteranceWithRetry({
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
  }) async {
    final String key = _pendingIdempotencyKey ??= _newIdempotencyKey();
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final PlayTurnResult result = await widget.repository!.submitUtterance(
          widget.sessionId,
          text: text,
          missionId: missionId,
          sttRawText: sttRawText,
          sttConfidence: sttConfidence,
          sttRetryCount: sttRetryCount,
          idempotencyKey: key,
        );
        _pendingIdempotencyKey = null;
        return result;
      } on ServerFailure catch (error) {
        final bool canRetry =
            error.code == 'REQUEST_IN_PROGRESS' && attempt < maxAttempts;
        if (!canRetry) {
          _pendingIdempotencyKey = null;
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      } on Failure {
        _pendingIdempotencyKey = null;
        rethrow;
      }
    }
    // maxAttempts 를 넘기면 위 루프의 rethrow 로 항상 빠져나가므로 여기는 오지 않습니다.
    throw const UnknownFailure();
  }

  /// UUID v4 형태의 키. 별도 패키지 없이 `dart:math` 만으로 충분합니다 -
  /// 서버는 문자열 유일성만 보면 되고 형식을 검증하지 않습니다.
  String _newIdempotencyKey() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// 서버 에러 코드를 아이가 이해할 수 있는 말로 바꿉니다. 매핑이 없으면
  /// 서버 메시지를 그대로 씁니다. → `docs/이야기_전개_가이드.md` 6장
  String _describeFailure(Failure error) {
    if (error is ServerFailure) {
      switch (error.code) {
        case 'STT_EMPTY_TEXT':
          return '잘 못 들었어요. 다시 말해 볼까?';
        case 'AUDIO_TOO_LARGE':
          return '조금만 짧게 말해 줄래?';
        case 'MISSION_NOT_EXPOSED':
          return '미션을 다시 확인하고 있어요.';
        case 'SESSION_NOT_IN_PROGRESS':
        case 'SCENE_NOT_STORY':
        case 'SCENE_NOT_DIALOGUE':
        case 'MAX_TURNS_EXCEEDED':
        case 'CONCURRENT_TURN':
          return '화면을 다시 불러오고 있어요.';
      }
    }
    return error.message;
  }

  /// "화면 상태가 서버와 어긋난" 계열 코드는 [_loadSession]으로 phase 를
  /// 다시 확인하면 저절로 맞는 화면으로 돌아옵니다 - 아이에게 에러를 보여줄
  /// 필요 없이 조용히 복구합니다. `MISSION_NOT_EXPOSED`는 미션 오버레이
  /// 상태만 다시 읽어옵니다. 복구했으면 true, 그 외 코드는 false(호출부가
  /// 메시지를 보여줌). → `docs/이야기_전개_가이드.md` 6장
  Future<bool> _tryAutoRecover(Failure error) async {
    if (error is! ServerFailure) return false;
    switch (error.code) {
      case 'SESSION_NOT_IN_PROGRESS':
      case 'SCENE_NOT_STORY':
      case 'SCENE_NOT_DIALOGUE':
      case 'MAX_TURNS_EXCEEDED':
      case 'CONCURRENT_TURN':
        await _loadSession();
        return true;
      case 'MISSION_NOT_EXPOSED':
        await _refreshMission();
        return true;
      default:
        return false;
    }
  }

  Future<void> _refreshMission() async {
    final PlayRepository? repository = widget.repository;
    if (repository == null) return;
    try {
      final PlayMission? mission = await repository.currentMission(
        widget.sessionId,
      );
      if (!mounted) return;
      setState(() => _mission = mission);
    } on Failure {
      // 미션 재확인 자체가 실패해도 대화 화면은 그대로 둡니다.
    }
  }

  Future<String> _transcribeAudio(Uint8List wavBytes) async {
    final PlayRepository? repository = widget.repository;
    if (repository == null) {
      throw const UnknownFailure('음성 인식 연결이 필요합니다.');
    }
    return (await repository.transcribeAudio(wavBytes)).text;
  }

  Future<void> _toggleVoiceAnswer() async {
    // 안내 음성이 나오는 중에는 녹음을 시작하지 않습니다 - 캐릭터 목소리가
    // 그대로 녹음돼서 또 한 번 못 알아듣게 됩니다.
    if (!_isListening ||
        _guideSpeaking ||
        _transcribingVoice ||
        _submittingUtterance) {
      return;
    }
    // 확인을 기다리는 결과가 있으면 마이크는 움직이지 않습니다.
    // "맞아요"와 "다시 말할래요" 둘 중 하나로만 진행합니다.
    if (_pendingTranscription != null) return;
    if (!_recordingVoice) {
      // 카드 미리듣기가 나오는 중이면 소리부터 끕니다(같은 이유).
      if (_playingChoiceId != null) {
        await _audioPlayer.stop();
        if (!mounted) return;
        setState(() => _playingChoiceId = null);
      }
      try {
        final bool allowed = await _voiceRecorder.start();
        if (!mounted) return;
        if (!allowed) {
          setState(() => _loadError = '마이크 권한을 허용해 주세요.');
          return;
        }
        setState(() {
          _recordingVoice = true;
          _listeningSeconds = 0;
        });
        _listeningTimer?.cancel();
        _listeningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && _recordingVoice) {
            setState(() => _listeningSeconds++);
            // 업로드 한도에 닿기 전에 여기까지 말한 것을 보낸다. 상한을 넘겨
            // 두면 통째로 413이 나서 아이가 말한 전부를 잃는다.
            if (_listeningSeconds >= maxRecordingSeconds) {
              unawaited(_toggleVoiceAnswer());
            }
          }
        });
      } on Object {
        if (mounted) setState(() => _loadError = '마이크를 켜지 못했어요.');
      }
      return;
    }

    _listeningTimer?.cancel();
    setState(() {
      _recordingVoice = false;
      _transcribingVoice = true;
    });
    try {
      final Uint8List? audio = await _voiceRecorder.stop();
      if (audio == null || audio.isEmpty) throw StateError('empty audio');
      final PlayTranscription transcription = await widget.repository!
          .transcribeAudio(audio);
      if (!mounted) return;
      // 바로 제출하지 않습니다. 아이가 변환 결과를 보고 "맞아요"를 눌러야
      // 턴이 나갑니다 - 오인식을 되돌릴 수 있는 유일한 시점입니다.
      setState(() {
        _transcribingVoice = false;
        _pendingTranscription = transcription;
        // 선택지 판은 말풍선 자리를 대신 쓰므로, 떠 있는 채로 두면 확인
        // 화면이 그 밑에 가려집니다. 목소리로 말하는 데 성공한 참이니
        // 카드는 접습니다 - 다시 못 알아들으면 3회째에 다시 내려옵니다.
        _closeChoicesState();
      });
    } on Failure catch (error) {
      // 무음이거나 인식 실패 - 흔히 겪는 상황이라 화면을 통째로 에러로
      // 바꾸지 않고 마이크 옆에 짧게 안내한 뒤 바로 다시 녹음할 수 있게
      // 둡니다. → `docs/이야기_전개_가이드.md` 3.4, 6장
      if (error is ServerFailure && error.code == 'STT_EMPTY_TEXT') {
        _recordFailedSttAttempt('잘 못 들었어요. 다시 말해 볼까?');
        return;
      }
      // 녹음이 서버 한도를 넘은 경우(413)도 같은 자리입니다. 실서버에서
      // 확인해 보니 전면 에러 화면이 떠서 아이가 대화 중간에 통째로 튕겼는데,
      // 이건 이야기가 깨진 게 아니라 "이번에 말한 게 너무 길었다"일 뿐입니다.
      // 다시 녹음하면 그만이라 자리를 지키고 안내만 바꿉니다.
      // → `docs/이야기_전개_가이드.md` 6장
      if (error is ServerFailure && error.code == 'AUDIO_TOO_LARGE') {
        _recordFailedSttAttempt('조금만 짧게 말해 줄래?');
        return;
      }
      if (!mounted) return;
      if (await _tryAutoRecover(error)) {
        setState(() => _transcribingVoice = false);
        return;
      }
      setState(() {
        _transcribingVoice = false;
        _loadError = _describeFailure(error);
      });
    } on Object {
      // 서버까지 가지도 못한 로컬 실패(녹음이 비었거나 업로드 자체가
      // 안 됨)도 같은 종류의 문제라 같은 방식으로 안내합니다.
      _recordFailedSttAttempt('목소리를 잘 듣지 못했어요. 다시 말해 주세요.');
    }
  }

  /// STT 가 텍스트를 못 만들어 다시 녹음해야 할 때 공통으로 부릅니다.
  ///
  /// 화면을 에러로 바꾸지 않는 것은 그대로고, 재시도 횟수를 세어 뒀다가
  /// 이번 발화가 결국 제출될 때 `sttRetryCount` 로 함께 보냅니다. 여기에
  /// 더해 **캐릭터가 다시 물어봐 줍니다** - 1회는 "다시 한 번 말해 줄래?",
  /// 2회는 "조금 크게 말해 줄래?", 3회에는 문장 카드를 내려놓습니다.
  /// → `docs/이야기_전개_가이드.md` 3.4
  ///
  /// 안내 음성이 없는 장면(3·5·7·9 밖)이나 내려놓을 카드를 한 장도 만들 수
  /// 없을 때는 예전처럼 [hint] 만 답니다 - 빈 선택지 판은 띄우지 않습니다.
  void _recordFailedSttAttempt(String hint) {
    if (!mounted) return;
    final int attempt = _sttRetryCount + 1;
    final int? sceneOrder = _snapshot?.currentScene?.sceneOrder;
    final List<SttChoiceSentence> cards =
        attempt >= SttChoiceSelector.attemptsBeforeChoices
        ? SttChoiceSelector.cardsFor(
            sceneOrder: sceneOrder,
            lastProgress: _lastTurnProgress,
          )
        : const <SttChoiceSentence>[];
    final SttChoiceVoice? guide = SttChoiceSelector.voiceFor(
      sceneOrder: sceneOrder,
      attempt: attempt,
      hasCards: cards.isNotEmpty,
    );
    setState(() {
      _transcribingVoice = false;
      _sttRetryCount = attempt;
      // 들려줄 말이 있으면 자막은 캐릭터 말풍선이 맡습니다. 작은 글씨 안내를
      // 겹쳐 두면 같은 말이 두 번 뜹니다.
      _sttHint = guide == null ? hint : null;
      if (cards.isNotEmpty) _choiceCards = cards;
    });
    if (guide != null) unawaited(_speakGuide(guide));
  }

  /// 캐릭터가 다시 물어보는 한 마디. 자막은 **캐릭터 말풍선에** 올립니다 -
  /// 시스템 알림이 아니라 대화의 일부여야 합니다.
  ///
  /// 재생하는 동안 마이크를 잠그고([_guideSpeaking]) 끝나면 되살립니다.
  /// [_playCharacterMessage] 가 대사를 다 읽고 마이크를 켜 주는 것과 같은
  /// 방식입니다. 소리가 안 나도(에셋 누락 등) 자막은 남고 마이크만 풀립니다.
  Future<void> _speakGuide(SttChoiceVoice voice) async {
    final int token = ++_speechToken;
    _releaseSpeechWait();
    await _audioPlayer.stop();
    if (!mounted || token != _speechToken) return;
    setState(() {
      _characterSentences = <String>[voice.text];
      _characterSentenceIndex = 0;
      _playingChoiceId = null;
      _guideSpeaking = true;
    });
    try {
      await _audioPlayer.playUrl(voice.assetPath);
    } on Object {
      // 소리가 안 나도 흐름은 이어집니다.
    }
    if (!mounted || token != _speechToken) return;
    setState(() => _guideSpeaking = false);
  }

  /// 카드 문장을 소리로 들려줍니다. 초1~3 은 읽기가 느려서, 소리가 없으면
  /// '고르기'가 또 하나의 시험이 됩니다.
  Future<void> _playChoiceCard(SttChoiceSentence sentence) async {
    final int token = ++_speechToken;
    await _audioPlayer.stop();
    if (!mounted || token != _speechToken) return;
    setState(() => _playingChoiceId = sentence.id);
    try {
      await _audioPlayer.playUrl(sentence.assetPath);
    } on Object {
      // 무시합니다 - 카드 글자는 그대로 남아 있습니다.
    }
    if (!mounted || token != _speechToken) return;
    setState(() => _playingChoiceId = null);
  }

  /// 고른 문장을 발화로 보냅니다.
  ///
  /// `sttRawText`·`sttConfidence` 를 **비운 채로** 보냅니다. STT 를 타지 않은
  /// 말이라 비어 있는 게 사실이고, 보호자 리포트가 저신뢰 발화를 거르는
  /// 판단을 가짜 값으로 오염시키면 안 됩니다.
  Future<void> _chooseSentence(SttChoiceSentence sentence) async {
    if (_submittingUtterance) return;
    if (_playingChoiceId != null) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() => _playingChoiceId = null);
    }
    await _submitDialogue(
      sentence.text,
      sttRetryCount: SttChoiceSelector.choiceRetryCount,
    );
  }

  /// 선택지 모드를 접습니다. **[setState] 안에서 부르세요** - 값만 되돌리고
  /// 스스로 다시 그리지 않습니다.
  void _closeChoicesState() {
    _choiceCards = const <SttChoiceSentence>[];
    _playingChoiceId = null;
    _guideSpeaking = false;
  }

  /// 아이가 변환 결과를 맞다고 확인했습니다. 이제서야 턴을 보냅니다.
  Future<void> _confirmTranscription() async {
    final PlayTranscription? pending = _pendingTranscription;
    if (pending == null || _submittingUtterance) return;
    setState(() => _pendingTranscription = null);
    await _submitDialogue(
      pending.text,
      sttRawText: pending.text,
      sttConfidence: pending.confidence,
      lowConfidence: pending.lowConfidence,
    );
  }

  /// 아이가 다르게 들렸다고 했습니다. 결과를 버리고 곧바로 다시 녹음합니다 -
  /// 마이크를 한 번 더 누르게 하면 아이가 흐름을 놓칩니다. 다시 말한 횟수는
  /// [_sttRetryCount] 로 세어 뒀다가 결국 제출될 때 함께 보냅니다.
  ///
  /// 다시 말하기는 **선택지를 부르지 않습니다**. 카드는 못 알아들었을 때
  /// (`STT_EMPTY_TEXT`) 내려놓는 것이고, 여기는 알아듣긴 했는데 아이가 아니라고
  /// 한 자리라 [_recordFailedSttAttempt] 를 타지 않습니다.
  Future<void> _retryTranscription() async {
    if (_pendingTranscription == null || _submittingUtterance) return;
    setState(() {
      _pendingTranscription = null;
      _sttRetryCount++;
      _sttHint = null;
    });
    await _toggleVoiceAnswer();
  }

  /// 턴 결과로 표정을 옮긴다. 캐릭터 대사를 재생하기 **전에** 부른다 - 아이 말에 대한 반응이
  /// 대사보다 늦게 오면 무엇에 반응한 것인지 읽히지 않는다.
  Future<void> _applyCharacterState(PlayTurnResult result) async {
    final DialogueCharacterStateMachine? character = _character;
    if (character == null) return;
    final DialogueStateTransition? transition = character.apply(result);
    if (transition == null) return;

    final String? via = transition.via;
    if (via != null) {
      // 다 채운 턴은 곧바로 마무리 표정으로 넘어가지 않는다. 확정안이 "잠시 보여준 뒤 전환"으로
      // 정해 뒀다 - 아이의 마지막 말에 반응한 얼굴을 한 번 보여주고 닫는다.
      character.moveTo(via);
      setState(() {});
      await Future<void>.delayed(
        _characterManifest?.closingViaHold ??
            const Duration(milliseconds: 1200),
      );
      if (!mounted) return;
      character.moveTo(transition.state);
    }
    setState(() {});
  }

  Future<void> _presentTurnResult(PlayTurnResult result) async {
    // 다음 턴에서 못 알아들었을 때 "아직 못 채운 요소"로 카드를 고르려면
    // 이 값이 필요합니다. 장면이 바뀌면 [_activateSnapshot] 이 비웁니다.
    _lastTurnProgress = result.progress;
    await _applyCharacterState(result);
    if (!mounted) return;
    final String? reaction = result.closingReactionText;
    if (reaction != null && reaction.trim().isNotEmpty) {
      await _playCharacterMessage(
        reaction,
        audioUrl: result.closingReactionAudioUrl,
      );
    }
    final String? reply = result.characterText;
    if (reply != null && reply.trim().isNotEmpty) {
      await _playCharacterMessage(reply, audioUrl: result.characterAudioUrl);
    }
    if (!mounted) return;

    if (result.mission != null) {
      setState(() => _mission = result.mission);
      return;
    }
    final PlaySceneTransition? transition = result.sceneTransition;
    if (transition != null) {
      if ((transition.resultImageUrl ?? '').isNotEmpty) {
        setState(() => _resultImageUrl = transition.resultImageUrl);
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        if (!mounted) return;
        setState(() => _resultImageUrl = null);
      }
      await _loadSession();
      return;
    }
    _startListening();
  }

  Future<void> _submitMission(String answer) async {
    final PlayMission? mission = _mission;
    if (mission == null || _submittingMission || widget.repository == null) {
      return;
    }
    setState(() {
      _submittingMission = true;
      _loadError = null;
    });
    try {
      final PlayTurnResult result = await _submitUtteranceWithRetry(
        text: answer,
        missionId: mission.missionId,
        // 미션 답도 아이가 말한 것을 받아 적은 것이라 원문이 곧 답입니다.
        // 데이터 계층이 더는 대신 채워 주지 않으므로 여기서 실어 보냅니다.
        sttRawText: answer,
      );
      if (!mounted) return;
      setState(() {
        _submittingMission = false;
        _missionCompleted = true;
        _characterReply = result.characterText;
      });
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      setState(() {
        _mission = null;
        _missionCompleted = false;
      });
      await _presentTurnResult(result);
    } on Failure catch (error) {
      if (!mounted) return;
      if (await _tryAutoRecover(error)) {
        setState(() => _submittingMission = false);
        return;
      }
      setState(() {
        _submittingMission = false;
        _loadError = _describeFailure(error);
      });
    }
  }

  /// STORY(전개) 장면의 내레이션. 문장마다 `/api/tts`(characterName 없이 ->
  /// 내레이션 보이스)를 불러 실제로 들려줍니다. 합성이나 재생이 안 되면
  /// (소리 꺼짐, repository 없음, 네트워크 실패) 이전처럼 글자 길이로 어림한
  /// 시간만큼 기다렸다가 다음 문장으로 넘어갑니다 - 화면이 죽지 않습니다.
  /// → `docs/이야기_전개_가이드.md` 3.2
  void _scheduleCurrentNarration() {
    debugPrint(
      '[narration] schedule scene=${_snapshot?.currentScene?.sceneId} '
      'index=$_narrationIndex paused=$_storyPaused advancing=$_advancingScene',
    );
    if (_storyPaused || _advancingScene) return;
    final int token = ++_speechToken;
    unawaited(_playCurrentNarration(token));
  }

  Future<void> _playCurrentNarration(int token) async {
    final List<String> sentences =
        _snapshot?.currentScene?.narrationSentences ?? const <String>[];
    debugPrint(
      '[narration] play token=$token index=$_narrationIndex '
      'total=${sentences.length} soundOn=$_soundOn',
    );
    if (_narrationIndex >= sentences.length) {
      debugPrint('[narration] scene done, will call story-complete in 700ms');
      _storyTimer = Timer(const Duration(milliseconds: 700), () {
        unawaited(_completeStoryScene());
      });
      return;
    }
    final String sentence = sentences[_narrationIndex];
    bool played = false;
    // 소리를 꺼도 합성과 재생은 그대로 합니다 - 볼륨만 0입니다. 그래야 문장이
    // 오디오 길이에 맞춰 넘어가고, 다시 켜는 순간 되감기 없이 바로 들립니다.
    if (widget.repository != null) {
      try {
        final PlaySpeechAudio audio = await widget.repository!.synthesizeSpeech(
          text: sentence,
        );
        debugPrint('[narration] tts ok, audioUrl len=${audio.audioUrl.length}');
        if (!mounted || token != _speechToken) {
          debugPrint(
            '[narration] stale after tts (mounted=$mounted '
            'token=$token current=$_speechToken), bailing',
          );
          return;
        }
        // 합성을 기다리는 사이에 일시정지를 눌렀을 수 있습니다. 일시정지는
        // 토큰을 올리지 않으니(그래야 재생 중이던 문장을 이어 들을 수
        // 있습니다) 여기서 직접 물러납니다 - 안 그러면 멈춘 뒤에 소리가
        // 새로 나옵니다. 아직 튼 것이 없어 재개할 때 이 문장을 다시
        // 시작합니다.
        if (_storyPaused) {
          debugPrint('[narration] paused during tts, bailing');
          return;
        }
        await _audioPlayer.playUrl(audio.audioUrl);
        debugPrint('[narration] playUrl finished');
        played = true;
      } on Object catch (error, stack) {
        debugPrint('[narration] tts/play FAILED: $error\n$stack');
        played = false;
      }
    } else {
      debugPrint('[narration] skipped tts (no repository)');
    }
    if (!mounted || token != _speechToken) {
      debugPrint(
        '[narration] stale before fallback check (mounted=$mounted '
        'token=$token current=$_speechToken), bailing',
      );
      return;
    }
    // 멈춰 있는 사이에 재생 대기가 풀려 여기까지 내려올 수 있습니다(예:
    // 나가기·다시 듣기가 부르는 stop). 그대로 두면 일시정지 중인데도 무음
    // 타이머가 돌아 다음 문장으로 넘어갑니다.
    if (_storyPaused) {
      debugPrint('[narration] paused after playback, bailing');
      return;
    }
    if (!played) {
      final int milliseconds = (1400 + sentence.length * 65)
          .clamp(2400, 7500)
          .toInt();
      debugPrint(
        '[narration] falling back to silent timer (${milliseconds}ms)',
      );
      await _waitForNarration(Duration(milliseconds: milliseconds));
    }
    if (!mounted || token != _speechToken) {
      debugPrint(
        '[narration] stale after wait (mounted=$mounted '
        'token=$token current=$_speechToken), bailing',
      );
      return;
    }
    setState(() => _narrationIndex++);
    _scheduleCurrentNarration();
  }

  Future<void> _completeStoryScene() async {
    if (_advancingScene || widget.repository == null) {
      debugPrint(
        '[narration] completeStoryScene skipped '
        '(advancing=$_advancingScene, repository=${widget.repository != null})',
      );
      return;
    }
    setState(() => _advancingScene = true);
    try {
      final PlaySessionSnapshot snapshot = await widget.repository!
          .completeStoryScene(widget.sessionId);
      debugPrint(
        '[narration] story-complete ok -> phase=${snapshot.phase} '
        'scene=${snapshot.currentScene?.sceneId} '
        'sentences=${snapshot.currentScene?.narrationSentences.length}',
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _advancingScene = false;
        _narrationIndex = 0;
      });
      _activateSnapshot(snapshot);
    } on Failure catch (error) {
      debugPrint('[narration] story-complete FAILED: $error');
      if (!mounted) return;
      if (await _tryAutoRecover(error)) {
        setState(() => _advancingScene = false);
        return;
      }
      setState(() {
        _advancingScene = false;
        _loadError = _describeFailure(error);
      });
    }
  }

  /// 무음으로 한 문장을 읽는 시간만큼 기다립니다. 일시정지가 걸리면
  /// [_releaseNarrationWait] 가 이 기다림을 곧바로 풀어 줍니다 - 안 풀어 주면
  /// 타이머만 취소되고 내레이션 루프는 영영 깨어나지 못합니다.
  Future<void> _waitForNarration(Duration duration) {
    final Completer<void> completer = Completer<void>();
    _narrationWait = completer;
    _storyTimer?.cancel();
    _storyTimer = Timer(duration, _releaseNarrationWait);
    return completer.future;
  }

  void _releaseNarrationWait() {
    final Completer<void>? pending = _narrationWait;
    _narrationWait = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  /// 전개 장면의 일시정지. **멈춘 지점을 그대로 둡니다** - 다시 재생하면
  /// 문장 처음이 아니라 소리가 끊긴 바로 그 자리에서 이어집니다. 장면을
  /// 처음부터 다시 읽는 것은 "다시 듣기" 버튼의 몫입니다.
  void _toggleStoryPause() {
    _storyTimer?.cancel();
    if (!_storyPaused) {
      // 멈추는 쪽입니다. **[_speechToken] 을 올리지 않습니다** - 올리면
      // 재생을 기다리던 루프가 스스로 빠져나가 이어 들을 대상이 사라집니다.
      // 소리는 stop() 이 아니라 pause() 로 멈춥니다(stop 은 위치를 0으로
      // 되돌립니다).
      if (_narrationWait != null) {
        // 무음 타이머로 읽던 중이라 되돌릴 재생 위치가 없습니다 - 이때만
        // 예전처럼 그 문장 루프를 끝내고, 재개할 때 문장을 다시 시작합니다.
        _speechToken++;
        _releaseNarrationWait();
      }
      unawaited(_audioPlayer.pause());
      setState(() => _storyPaused = true);
      return;
    }
    setState(() => _storyPaused = false);
    // 멈춰 둔 오디오가 남아 있으면 그 지점부터, 없으면(무음 타이머·합성
    // 대기 중에 멈춘 경우) 그 문장을 처음부터 다시 시작합니다.
    if (_audioPlayer.canResume) {
      unawaited(_audioPlayer.resume());
    } else {
      _scheduleCurrentNarration();
    }
  }

  /// 소리 끄기/켜기 - **음소거입니다. 재생을 끊지 않습니다.**
  ///
  /// 예전에는 끌 때 [StoryAudioPlayer.stop] 으로 끊고 켤 때 그 문장을 다시
  /// 틀었는데, 지금 콘텐츠는 장면당 문장이 하나라 "이 문장 다시"가 곧
  /// "장면 처음부터"여서 켤 때마다 이야기가 되감겼습니다. 볼륨만 0으로
  /// 내리면 오디오가 그대로 흘러가 문장도 평소 속도로 넘어가고, 다시 켜면
  /// 그 지점부터 들립니다. 이야기를 멈추는 것은 일시정지 버튼의 몫입니다.
  void _toggleSound() {
    final bool soundOn = !_soundOn;
    setState(() => _soundOn = soundOn);
    unawaited(_audioPlayer.setMuted(!soundOn));
  }

  Future<void> _playQuestion() async {
    if (_recordingVoice) {
      await _voiceRecorder.cancel();
      if (!mounted) return;
      setState(() => _recordingVoice = false);
    }
    unawaited(
      _playCharacterMessage(
        _characterReply ?? _snapshot?.openingText ?? widget.question,
        audioUrl: _snapshot?.openingAudioUrl,
        onComplete: _startListening,
      ),
    );
  }

  /// 대사 한 덩어리를 문장 단위로 들려줍니다.
  ///
  /// 일시정지가 걸리면 루프를 **버리지 않고 문장 앞에서 재웁니다**
  /// ([_awaitResume]). 다시 재생하면 멈춘 그 문장부터 이어집니다 - 예전처럼
  /// 대사를 처음부터 다시 읽지 않습니다. 대신 문장 중간에 멈췄다면 그 문장은
  /// 처음부터 다시 읽습니다(오디오는 중간부터 이어 붙일 수 없습니다).
  Future<void> _playCharacterMessage(
    String text, {
    String? audioUrl,
    VoidCallback? onComplete,
  }) async {
    final int token = ++_speechToken;
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    _releaseSpeechWait();
    _openPauseGate();
    await _audioPlayer.stop();
    final List<String> sentences = _splitSentences(text);
    if (!mounted || sentences.isEmpty) {
      onComplete?.call();
      return;
    }
    setState(() {
      _phase = _DialoguePhase.characterSpeaking;
      _characterSentences = sentences;
      _characterSentenceIndex = 0;
      _listeningSeconds = 0;
    });

    _speaking = true;
    try {
      await _speakSentences(sentences, token: token, audioUrl: audioUrl);
    } finally {
      if (token == _speechToken) _speaking = false;
    }
    if (mounted && token == _speechToken) onComplete?.call();
  }

  Future<void> _speakSentences(
    List<String> sentences, {
    required int token,
    String? audioUrl,
  }) async {
    for (int index = 0; index < sentences.length; index++) {
      await _awaitResume(token);
      if (!mounted || token != _speechToken) return;
      setState(() => _characterSentenceIndex = index);
      bool played = false;
      // 소리를 꺼도 합성과 재생은 그대로 합니다 - 볼륨만 0입니다(→
      // [_toggleSound]). 그래야 대사가 오디오 길이에 맞춰 넘어갑니다.
      if (widget.repository != null) {
        try {
          final String source = index == 0 && sentences.length == 1
              ? (audioUrl ??
                    (await widget.repository!.synthesizeSpeech(
                      text: sentences[index],
                      characterName:
                          _snapshot?.currentScene?.characterName ??
                          widget.characterName,
                    )).audioUrl)
              : (await widget.repository!.synthesizeSpeech(
                  text: sentences[index],
                  characterName:
                      _snapshot?.currentScene?.characterName ??
                      widget.characterName,
                )).audioUrl;
          // 내레이션과 같은 규칙입니다 - 합성을 기다리는 사이에 일시정지를
          // 눌렀으면 틀지 않습니다(멈춘 뒤에 소리가 새로 나오면 안 됩니다).
          if (source.isNotEmpty && _phase != _DialoguePhase.paused) {
            final String resolvedSource = source.startsWith('/')
                ? Uri.parse(AppConfig.apiBaseUrl).resolve(source).toString()
                : source;
            await _audioPlayer.playUrl(resolvedSource);
            played = true;
          }
        } on Object {
          played = false;
        }
      }
      // 멈춰 있는 사이에 재생 대기가 풀려 못 들려준 문장으로 내려올 수
      // 있습니다(예: 나가기가 부르는 stop). 그대로 두면 일시정지 중인데
      // 무음 타이머가 돕니다 - 아래 index-- 로 표시해 두고 문 앞에서
      // 기다립니다.
      if (!played && _phase != _DialoguePhase.paused) {
        final int milliseconds = widget.repository == null
            ? 2000
            : (1200 + sentences[index].length * 55).clamp(1800, 5200).toInt();
        await _waitForSpeech(Duration(milliseconds: milliseconds));
      }
      if (!mounted || token != _speechToken) return;
      if (_phase == _DialoguePhase.paused) {
        // 이 문장을 읽는 도중에 멈췄습니다. 다시 재생하면 같은 문장을
        // 처음부터 들려줍니다 - 반쯤 들은 문장을 건너뛰면 말이 끊깁니다.
        index--;
      }
    }
  }

  /// 일시정지 중이면 여기서 잡혀 있다가 "계속 듣기"에 깨어납니다.
  /// 발화 루프를 버리지 않고 재우는 것이 이 화면의 이어 재생 방식입니다.
  Future<void> _awaitResume(int token) async {
    while (mounted &&
        token == _speechToken &&
        _phase == _DialoguePhase.paused) {
      await (_pauseGate ??= Completer<void>()).future;
    }
  }

  void _openPauseGate() {
    final Completer<void>? gate = _pauseGate;
    _pauseGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// 음성 없이 문장을 읽는 시간. [_releaseSpeechWait] 로 중간에 깨울 수
  /// 있습니다 - 타이머만 취소하면 발화 루프가 영영 깨어나지 못합니다.
  Future<void> _waitForSpeech(Duration duration) {
    final Completer<void> completer = Completer<void>();
    _speechWait = completer;
    _questionTimer?.cancel();
    _questionTimer = Timer(duration, _releaseSpeechWait);
    return completer.future;
  }

  void _releaseSpeechWait() {
    final Completer<void>? pending = _speechWait;
    _speechWait = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  List<String> _splitSentences(String text) {
    final List<String> sentences = RegExp(r'[^.!?。！？]+[.!?。！？]?')
        .allMatches(text)
        .map((match) => match.group(0)?.trim() ?? '')
        .where((sentence) => sentence.isNotEmpty)
        .toList(growable: false);
    return sentences.isEmpty ? <String>[text.trim()] : sentences;
  }

  /// 캐릭터 대사가 끝나고 아이 차례가 되는 지점.
  ///
  /// 여기서 지난 턴의 발화를 지웁니다. 캐릭터가 그 말에 답하는 동안에는
  /// 남겨 두는 게 맞지만(무엇에 대한 답인지 보여야 합니다), 새 차례가
  /// 시작됐는데도 남아 있으면 아이가 이번에 한 말로 오해합니다.
  void _startListening() {
    if (!mounted || _phase == _DialoguePhase.paused) return;
    setState(() {
      _phase = _DialoguePhase.listening;
      _listeningSeconds = 0;
      _recordingVoice = false;
      _transcribingVoice = false;
      _sttRetryCount = 0;
      _sttHint = null;
      _lastChildText = null;
      _lastSttLowConfidence = false;
      _pendingTranscription = null;
      // 새 차례에는 지난 차례의 선택지를 들고 오지 않습니다.
      _closeChoicesState();
    });
    _listeningTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phase == _DialoguePhase.listening && !_recordingVoice) {
        unawaited(_toggleVoiceAnswer());
      }
    });
  }

  /// 대화 장면의 일시정지.
  ///
  /// 멈출 때 대사 루프를 **죽이지 않습니다**. 소리는 [StoryAudioPlayer.pause]
  /// 로 그 자리에 세워 두고([StoryAudioPlayer.stop] 은 재생 위치를 0으로
  /// 되돌립니다), 무음으로 읽던 중이었다면 루프를 문 앞에 세워 뒀다가
  /// ([_awaitResume]) 다시 재생할 때 그 문장부터 이어 읽게 합니다.
  /// 전개 화면의 [_toggleStoryPause] 와 같은 방식입니다.
  void _togglePause() {
    if (_phase == _DialoguePhase.paused) {
      setState(() => _phase = _phaseBeforePause);
      _openPauseGate();
      if (_phase == _DialoguePhase.characterSpeaking) {
        // 멈춰 둔 오디오가 남아 있으면 그 지점부터 이어 갑니다. 루프는
        // playUrl 안에서 그대로 기다리고 있어 다시 부를 것이 없습니다.
        if (_audioPlayer.canResume) {
          unawaited(_audioPlayer.resume());
        } else if (!_speaking) {
          // 루프가 이미 끝난 뒤에 멈춘 경우에만 다시 들려줍니다.
          unawaited(_playQuestion());
        }
      } else if (_pendingTranscription == null) {
        _startListening();
      }
      // 확인 대기 중에 멈췄다면 결과를 지우지 않고 확인 화면으로 되돌아갑니다 -
      // _startListening 을 타면 아이가 말해 둔 답이 사라집니다.
      return;
    }

    _phaseBeforePause = _phase;
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    if (_recordingVoice) unawaited(_voiceRecorder.cancel());
    // **[_speechToken] 을 올리지 않습니다** - 올리면 재생을 기다리던 루프가
    // 스스로 빠져나가 이어 들을 대상이 사라집니다.
    unawaited(_audioPlayer.pause());
    // 무음으로 읽는 중이었다면 그 기다림을 깨워, 루프가 이 문장에서
    // 멈춰 서 있게 합니다(깨우지 않으면 타이머만 죽고 영영 안 깨어납니다).
    _releaseSpeechWait();
    setState(() {
      _recordingVoice = false;
      _transcribingVoice = false;
      _phase = _DialoguePhase.paused;
    });
  }

  /// 나가기 — **듣던 자리를 남겨 둡니다.**
  ///
  /// 세션은 IN_PROGRESS 그대로라 홈 이어하기 카드로 다시 들어옵니다. 그래서
  /// 서버에 아무것도 알리지 않습니다. `stop` 은 STOPPED 로 바꿔 이어하기
  /// 목록에서 지워 버리는, 되돌릴 수 없는 호출이라 "그만두겠다"는 명시적
  /// 행동에만 씁니다 - 화면을 벗어나는 것은 그런 행동이 아닙니다.
  /// → `docs/이야기_전개_가이드.md` 3.8 · 8장
  ///
  /// 그래도 한 번 묻습니다. 잃는 것은 없지만 화면이 통째로 바뀌는 일이라,
  /// 잘못 눌렀을 때 되돌릴 틈은 있어야 합니다.
  Future<void> _confirmExit() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('이야기에서 나갈까요?'),
        content: const Text('여기까지 들은 곳을 기억해 둘게요. 홈에서 이어 들을 수 있어요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 듣기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    // 나가기로 마음을 정한 순간 소리부터 멈춥니다 - 화면이 바뀌는 동안에도
    // 이야기가 계속 들리면 안 나가지는 것처럼 보입니다.
    _stopSpeaking();
    // **pop 이 아니라 go 입니다.** 이 화면은 홈 이어하기·이야기 상세에서
    // `context.go` 로 들어와 되돌아갈 화면이 스택에 없습니다 - maybePop 은
    // 조용히 아무 일도 안 하고, 아이는 나가기를 눌러도 그대로 남습니다.
    context.go(AppRoutes.home);
  }

  /// 지금 나오고 있는 말과 예약된 다음 문장을 모두 끊습니다.
  void _stopSpeaking() {
    _speechToken++;
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    _storyTimer?.cancel();
    _releaseSpeechWait();
    _releaseNarrationWait();
    _openPauseGate();
    unawaited(_audioPlayer.stop());
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFF183455),
        body: AppLoadingView(),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5FAF8),
        body: AppKidErrorView(
          message: _loadError!,
          onRetry: _snapshot?.phase == PlayPhase.story
              ? _completeStoryScene
              : _loadSession,
        ),
      );
    }
    if (_snapshot?.phase == PlayPhase.story) {
      final PlayScene? scene = _snapshot!.currentScene;
      if (scene != null) {
        return _StorySceneView(
          scene: scene,
          narrationIndex: _narrationIndex,
          isPaused: _storyPaused,
          isAdvancing: _advancingScene,
          soundOn: _soundOn,
          totalScenes: widget.totalScenes,
          onExit: _confirmExit,
          onPause: _toggleStoryPause,
          // "다시 듣기"는 지금처럼 장면 처음부터입니다. 이어 재생은
          // 일시정지 버튼의 몫이라 둘을 섞지 않습니다.
          onReplay: () {
            _storyTimer?.cancel();
            _speechToken++;
            _releaseNarrationWait();
            unawaited(_audioPlayer.stop());
            setState(() => _narrationIndex = 0);
            _scheduleCurrentNarration();
          },
          onSound: _toggleSound,
        );
      }
    }
    final PlayScene? dialogueScene = _snapshot?.currentScene;
    return Scaffold(
      backgroundColor: const Color(0xFF183455),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 760;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _StoryBackdrop(
                // 제작한 장면 배경이 있으면 그것이 우선이다. 서버 imageUrl은 배경과 캐릭터가
                // 합쳐진 한 장이라 캐릭터를 따로 얹으면 인물이 둘로 보인다.
                asset:
                    _character?.scene.backgroundAsset ??
                    _retainedStoryImageUrl ??
                    dialogueScene?.imageUrl ??
                    widget.backgroundAsset,
              ),
              const _BackdropShade(),
              SafeArea(
                minimum: EdgeInsets.all(compact ? 12 : 22),
                child: Column(
                  children: <Widget>[
                    _StoryControls(
                      isPaused: _phase == _DialoguePhase.paused,
                      soundOn: _soundOn,
                      sceneOrder: dialogueScene?.sceneOrder,
                      totalScenes: widget.totalScenes,
                      onExit: _confirmExit,
                      onPause: _togglePause,
                      onReplay: _playQuestion,
                      onSound: _toggleSound,
                    ),
                    Expanded(
                      child: _DialogueCanvas(
                        character: _character,
                        activity: _activity,
                        characterAsset: widget.characterAsset,
                        characterName:
                            dialogueScene?.characterName ??
                            widget.characterName,
                        question: _visibleCharacterText,
                        phase: _phase,
                        listeningSeconds: _listeningSeconds,
                        recording: _recordingVoice,
                        transcribing: _transcribingVoice,
                        compact: compact,
                        onMicTap: _isListening && _pendingTranscription == null
                            ? _toggleVoiceAnswer
                            : null,
                        guideSpeaking: _guideSpeaking,
                        pendingTranscription: _pendingTranscription,
                        onConfirmTranscription: _confirmTranscription,
                        onRetryTranscription: _retryTranscription,
                        // 한 번이라도 못 알아들은 뒤로는(선택지가 떠 있을 때
                        // 포함) 녹음을 대신 켜 주지 않습니다. 제출에 성공하면
                        // 0으로 돌아가고 다음 턴은 다시 자동으로 켜집니다.
                        micNeedsTap: _sttRetryCount > 0,
                        submitting: _submittingUtterance,
                        lastChildText: _lastChildText,
                        lastSttLowConfidence: _lastSttLowConfidence,
                        sttHint: _sttHint,
                        // 선택지 판은 캐릭터 말풍선 자리를 대신 씁니다 -
                        // 안내 문구가 판 머리에 그대로 들어가 있어서 같은
                        // 말을 두 곳에 띄울 이유가 없습니다. 마이크는 아래
                        // 제자리에 그대로 남습니다.
                        choicePanel: _choiceCards.isEmpty
                            ? null
                            : SttChoicePanel(
                                characterName:
                                    dialogueScene?.characterName ??
                                    widget.characterName,
                                introText: _visibleCharacterText,
                                cards: _choiceCards,
                                playingCardId: _playingChoiceId,
                                submitting: _submittingUtterance,
                                compact: compact,
                                onChoose: (SttChoiceSentence sentence) =>
                                    unawaited(_chooseSentence(sentence)),
                                onListen: (SttChoiceSentence sentence) =>
                                    unawaited(_playChoiceCard(sentence)),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_phase == _DialoguePhase.paused)
                _PauseOverlay(onResume: _togglePause, onExit: _confirmExit),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 430),
                reverseDuration: const Duration(milliseconds: 320),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: .9, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: _mission == null
                    ? const SizedBox.shrink(key: ValueKey<String>('no-mission'))
                    : SizedBox.expand(
                        key: ValueKey<String>(_mission!.missionId),
                        child: MissionOverlay(
                          mission: _mission!,
                          submitting: _submittingMission,
                          completed: _missionCompleted,
                          transcribeAudio: _transcribeAudio,
                          onSubmit: _submitMission,
                        ),
                      ),
              ),
              if (_resultImageUrl != null)
                _ResultSceneOverlay(imageUrl: _resultImageUrl!),
            ],
          );
        },
      ),
    );
  }
}

class _StorySceneView extends StatelessWidget {
  const _StorySceneView({
    required this.scene,
    required this.narrationIndex,
    required this.isPaused,
    required this.isAdvancing,
    required this.soundOn,
    required this.totalScenes,
    required this.onExit,
    required this.onPause,
    required this.onReplay,
    required this.onSound,
  });

  final PlayScene scene;
  final int narrationIndex;
  final bool isPaused;
  final bool isAdvancing;
  final bool soundOn;
  final int? totalScenes;
  final VoidCallback onExit;
  final VoidCallback onPause;
  final VoidCallback onReplay;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context) {
    final List<String> sentences = scene.narrationSentences;
    final int safeNarrationIndex = narrationIndex < sentences.length
        ? narrationIndex
        : sentences.length - 1;
    final String narration = sentences.isEmpty
        ? '이야기를 들려주고 있어요.'
        : sentences[safeNarrationIndex];
    final double progress = sentences.isEmpty
        ? 1
        : (narrationIndex + 1).clamp(1, sentences.length) / sentences.length;
    return Scaffold(
      backgroundColor: const Color(0xFF183455),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _StoryBackdrop(asset: scene.imageUrl),
          const _BackdropShade(),
          SafeArea(
            minimum: const EdgeInsets.all(22),
            child: Column(
              children: <Widget>[
                _StoryControls(
                  isPaused: isPaused,
                  soundOn: soundOn,
                  sceneOrder: scene.sceneOrder,
                  totalScenes: totalScenes,
                  onExit: onExit,
                  onPause: onPause,
                  onReplay: onReplay,
                  onSound: onSound,
                ),
                const Spacer(),
                Semantics(
                  liveRegion: true,
                  label: narration,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE617304A),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0x887DE1C3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          narration,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.55,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(10),
                          backgroundColor: const Color(0x557DE1C3),
                          color: const Color(0xFFFFD56A),
                        ),
                        if (isAdvancing) ...<Widget>[
                          const SizedBox(height: 16),
                          const Text(
                            '다음 장면을 준비하고 있어요…',
                            style: TextStyle(
                              color: Color(0xFFBCEEDD),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
              ],
            ),
          ),
          if (isPaused) _PauseOverlay(onResume: onPause, onExit: onExit),
        ],
      ),
    );
  }
}

class _StoryBackdrop extends StatelessWidget {
  const _StoryBackdrop({this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      final String resolvedAsset = asset!.startsWith('/')
          ? Uri.parse(AppConfig.apiBaseUrl).resolve(asset!).toString()
          : asset!;
      final Uri? uri = Uri.tryParse(resolvedAsset);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return Image.network(
          resolvedAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _FallbackStoryBackdrop(),
        );
      }
      return Image.asset(
        resolvedAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _FallbackStoryBackdrop(),
      );
    }
    return const _FallbackStoryBackdrop();
  }
}

class _FallbackStoryBackdrop extends StatelessWidget {
  const _FallbackStoryBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF356B8A),
          Color(0xFF244A73),
          Color(0xFF172E50),
        ],
      ),
    ),
    child: CustomPaint(painter: _BackdropPainter()),
  );
}

class _BackdropShade extends StatelessWidget {
  const _BackdropShade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x33071425),
            Color(0x00071425),
            Color(0x66071425),
          ],
        ),
      ),
    );
  }
}

class _StoryControls extends StatelessWidget {
  const _StoryControls({
    required this.isPaused,
    required this.soundOn,
    required this.sceneOrder,
    required this.totalScenes,
    required this.onExit,
    required this.onPause,
    required this.onReplay,
    required this.onSound,
  });

  final bool isPaused;
  final bool soundOn;

  /// 지금 몇 번째 장면인지(서버 `currentScene.sceneOrder`). 없으면 `null`.
  final int? sceneOrder;

  /// 이 이야기의 전체 장면 수. 진입 경로가 알려 주지 않았으면 `null` 이고,
  /// 그때는 눈금 없는 막대만 그립니다 - 틀린 비율을 그리는 것보다 낫습니다.
  final int? totalScenes;

  final VoidCallback onExit;
  final VoidCallback onPause;
  final VoidCallback onReplay;
  final VoidCallback onSound;

  /// 문장이 아니라 **장면** 진행률입니다. 문장이 넘어가는 것과 무관하고,
  /// 일시정지와도 무관합니다.
  double? get _progress {
    final int? order = sceneOrder;
    final int? total = totalScenes;
    if (order == null || total == null || total <= 0) return null;
    return (order / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ControlButton(label: '나가기', icon: AppIcons.close, onPressed: onExit),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: totalScenes == null
                ? '이야기 진행'
                : '전체 $totalScenes 장면 중 ${sceneOrder ?? 0}번째',
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .32),
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                widthFactor: _progress ?? 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD56A),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _ControlButton(
          label: '다시 듣기',
          icon: AppIcons.replay,
          onPressed: onReplay,
        ),
        const SizedBox(width: 8),
        _ControlButton(
          label: soundOn ? '소리 끄기' : '소리 켜기',
          icon: soundOn ? AppIcons.soundOn : AppIcons.soundOff,
          onPressed: onSound,
        ),
        const SizedBox(width: 8),
        _ControlButton(
          label: isPaused ? '계속 듣기' : '잠시 멈춤',
          icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          onPressed: onPause,
          emphasized: true,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: emphasized ? const Color(0xFFFFD56A) : const Color(0xCC102B48),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              size: 28,
              color: emphasized ? const Color(0xFF17314A) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogueCanvas extends StatelessWidget {
  const _DialogueCanvas({
    required this.character,
    required this.activity,
    required this.characterAsset,
    required this.characterName,
    required this.question,
    required this.phase,
    required this.listeningSeconds,
    required this.recording,
    required this.transcribing,
    required this.compact,
    required this.onMicTap,
    required this.submitting,
    required this.lastChildText,
    required this.lastSttLowConfidence,
    this.guideSpeaking = false,
    this.micNeedsTap = false,
    this.sttHint,
    this.choicePanel,
    this.pendingTranscription,
    this.onConfirmTranscription,
    this.onRetryTranscription,
  });

  /// 제작한 표정 에셋이 있는 장면에서만 값이 있다. null이면 [characterAsset] 한 장으로 그린다.
  final DialogueCharacterStateMachine? character;
  final DialogueActivity activity;
  final String? characterAsset;
  final String characterName;
  final String question;
  final _DialoguePhase phase;
  final int listeningSeconds;
  final bool recording;
  final bool transcribing;
  final bool compact;
  final VoidCallback? onMicTap;

  /// 캐릭터가 다시 물어보는 안내 음성이 나오는 중. 이때 마이크는 "준비됨"이
  /// 아니라 "듣는 중" 모양이어야 한다 - 눌러도 안 되는 버튼이 켜져 보이면
  /// 아이는 고장 났다고 여긴다.
  final bool guideSpeaking;

  /// 마이크가 저절로 켜지지 않고 아이가 눌러 줘야 하는 상태(못 알아들어서 다시
  /// 말해야 할 때·선택지가 떠 있을 때). 턴을 새로 시작할 때는 화면이 알아서
  /// 녹음을 켜지만, 다시 말하는 자리에서는 안내 음성 꼬리가 녹음되지 않도록
  /// 아이가 직접 누르게 두기 때문이다.
  final bool micNeedsTap;

  /// 아이의 확인을 기다리는 변환 결과. 값이 있으면 말풍선이 확인 화면으로 바뀐다.
  final PlayTranscription? pendingTranscription;
  final VoidCallback? onConfirmTranscription;
  final VoidCallback? onRetryTranscription;

  final bool submitting;
  final String? lastChildText;
  final bool lastSttLowConfidence;

  /// 무음/인식 실패로 다시 말해야 할 때만 값이 있다. [lastSttLowConfidence]
  /// 와 달리 화면을 안 바꾸고 마이크 옆에만 짧게 띄운다.
  final String? sttHint;

  /// 세 번 이어서 못 알아들었을 때만 값이 있다. 캐릭터 말풍선 자리를 대신
  /// 쓰고, 아이 말풍선(마이크)은 제자리에 그대로 둔다.
  final Widget? choicePanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 제작 캐릭터는 정면 전신이고 표정이 전부다. 말풍선이 얼굴을 가리면 이 화면의 의미가
        // 없어지므로 인물은 왼쪽에 세우고 말풍선은 오른쪽으로 몰아 둔다.
        final bool hasStage = character != null;
        final double stageWidth = constraints.maxWidth * (compact ? .56 : .40);

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (hasStage)
              Positioned(
                left: compact ? -constraints.maxWidth * .06 : 8,
                width: stageWidth,
                top: compact ? 120 : 4,
                bottom: 0,
                child: DialogueCharacterStage(
                  scene: character!.scene,
                  state: character!.current,
                  activity: activity,
                ),
              )
            else if (characterAsset != null && !compact)
              Positioned(
                left: 18,
                top: 30,
                bottom: 0,
                width: constraints.maxWidth * .29,
                child: Semantics(
                  image: true,
                  label: '$characterName 캐릭터',
                  child: Image.asset(
                    characterAsset!,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),
            Positioned(
              left: compact
                  ? 10
                  : (hasStage ? stageWidth + 24 : constraints.maxWidth * .23),
              right: compact ? 10 : 20,
              top: compact ? 18 : 44,
              // 선택지 판은 아이 말풍선 바로 위까지 내려와 카드 3장을 크게
              // 폅니다. 말풍선은 내용만큼만 차지하므로 bottom 을 주지 않습니다.
              bottom: choicePanel == null ? null : (compact ? 154.0 : 190.0),
              child:
                  choicePanel ??
                  _QuestionBubble(
                    characterName: characterName,
                    question: question,
                    compact: compact,
                    // 아이 말풍선(아래)과 서로 밀어내지 않도록 위아래로 나눠
                    // 씁니다. 좁은 폭에서 대사가 길어져도 잘리는 대신 이 안에서
                    // 굴러갑니다.
                    maxHeight:
                        constraints.maxHeight -
                        (compact ? 18 : 44) -
                        (compact ? 160 : 190),
                  ),
            ),
            // 이름 배지는 인물 발밑에 겹치고, 말풍선이 이미 "○○의 질문"으로 화자를 밝힌다.
            if (!compact && !hasStage)
              Positioned(
                left: 20,
                bottom: 22,
                child: _CharacterNameBadge(name: characterName),
              ),
            Positioned(
              right: compact ? 10 : 0,
              bottom: compact ? 10 : 20,
              width: compact
                  ? constraints.maxWidth - 20
                  : constraints.maxWidth * .52,
              child: _ChildVoiceBubble(
                phase: phase,
                seconds: listeningSeconds,
                recording: recording,
                transcribing: transcribing,
                submitting: submitting,
                guideSpeaking: guideSpeaking,
                micNeedsTap: micNeedsTap,
                onMicTap: onMicTap,
                lastChildText: lastChildText,
                lowConfidence: lastSttLowConfidence,
                sttHint: sttHint,
                compact: compact,
                pending: pendingTranscription,
                onConfirm: onConfirmTranscription,
                onRetry: onRetryTranscription,
                maxHeight: constraints.maxHeight * (compact ? .42 : .5),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CharacterNameBadge extends StatelessWidget {
  const _CharacterNameBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xDD173A5D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white70),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 캐릭터 대사 말풍선.
///
/// **대사는 어떤 폭에서도 잘리지 않습니다.** 아이가 글을 다 못 읽는 채로
/// 대답해야 하는 상황을 만들면 이 화면이 성립하지 않습니다. 그래서 문장이
/// 길면 (1) 글자를 한 단계씩 줄이고, (2) 그래도 넘치면 말풍선 안에서
/// 스크롤합니다 - 말줄임표로 끊지 않습니다.
class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({
    required this.characterName,
    required this.question,
    required this.compact,
    required this.maxHeight,
  });

  /// 말풍선이 차지해도 되는 최대 높이. 아이 말풍선을 밀어내지 않도록
  /// [_DialogueCanvas] 가 화면 높이에서 계산해 넘깁니다.
  final double maxHeight;

  /// 길이에 따라 한 단계씩 줄어드는 글자 크기. 자르는 대신 줄입니다.
  double get _fontSize {
    final int length = question.characters.length;
    if (compact) return length > 90 ? 21 : (length > 55 ? 24 : 27);
    return length > 90 ? 27 : (length > 55 ? 30 : 34);
  }

  final String characterName;
  final String question;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -17,
          top: 62,
          child: Transform.rotate(
            angle: .78,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF3),
                border: Border.all(color: const Color(0xFFFFD66B), width: 2),
              ),
            ),
          ),
        ),
        Container(
          constraints: BoxConstraints(
            minHeight: compact ? 138 : 176,
            maxHeight: max(maxHeight, compact ? 138.0 : 176.0),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 22 : 34,
            vertical: compact ? 19 : 25,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF3),
            borderRadius: BorderRadius.circular(compact ? 24 : 32),
            border: Border.all(color: const Color(0xFFFFD66B), width: 3),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x55081729),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            // 최대 높이가 생겼으니 min 이어야 합니다 - 기본값(max)이면 대사가
            // 짧아도 말풍선이 허용 높이까지 늘어납니다.
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4EA883),
                    size: 25,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '$characterName의 질문',
                    style: const TextStyle(
                      color: Color(0xFF496179),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 자르지 않습니다 - 줄이고, 그래도 넘치면 말풍선 안에서 굴립니다.
              Flexible(
                child: SingleChildScrollView(
                  child: Semantics(
                    liveRegion: true,
                    label: question,
                    child: Text(
                      question,
                      style: TextStyle(
                        color: const Color(0xFF172A3E),
                        fontSize: _fontSize,
                        height: 1.35,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChildVoiceBubble extends StatelessWidget {
  const _ChildVoiceBubble({
    required this.phase,
    required this.seconds,
    required this.recording,
    required this.transcribing,
    required this.submitting,
    required this.onMicTap,
    required this.lastChildText,
    required this.lowConfidence,
    required this.compact,
    required this.maxHeight,
    this.guideSpeaking = false,
    this.micNeedsTap = false,
    this.sttHint,
    this.pending,
    this.onConfirm,
    this.onRetry,
  });

  /// 말풍선이 차지해도 되는 최대 높이. 아이가 길게 말했어도 잘라내지 않고
  /// 이 안에서 굴립니다. → [_QuestionBubble]
  final double maxHeight;

  final _DialoguePhase phase;
  final int seconds;
  final bool recording;
  final bool transcribing;
  final bool submitting;
  final VoidCallback? onMicTap;
  final String? lastChildText;
  final bool lowConfidence;
  final bool compact;

  /// 캐릭터가 다시 물어보는 중. 마이크는 잠겨 있다. → [_DialogueCanvas]
  final bool guideSpeaking;

  /// 마이크를 아이가 눌러 줘야 하는 자리. → [_DialogueCanvas.micNeedsTap]
  final bool micNeedsTap;

  final String? sttHint;

  /// 아이의 확인을 기다리는 변환 결과. 값이 있으면 확인 화면을 그린다.
  final PlayTranscription? pending;
  final VoidCallback? onConfirm;
  final VoidCallback? onRetry;

  bool get listening => phase == _DialoguePhase.listening;

  /// 안내 음성이 나오는 동안에는 "말할 차례"가 아니다. 마이크를 켜진 모양으로
  /// 두면 눌렀다가 아무 일도 안 일어난다.
  bool get micReady => listening && !guideSpeaking;

  @override
  Widget build(BuildContext context) {
    if (pending != null) return _buildConfirmView();
    final String status = transcribing
        ? '목소리를 글로 바꾸고 있어요'
        : submitting
        ? '이야기 친구가 답을 준비하고 있어요'
        : recording
        ? '잘 듣고 있어요 · $seconds초'
        : guideSpeaking
        ? '이야기 친구가 다시 물어보고 있어요'
        : listening
        // 다시 말하는 자리에서는 마이크가 저절로 켜지지 않는다. "이제 말할
        // 차례예요"라고 두면 아이가 누르지 않고 기다린다.
        ? (micNeedsTap ? '다시 말할 수 있어요' : '이제 말할 차례예요')
        : '질문을 듣고 있어요';
    final String body = lastChildText?.trim().isNotEmpty == true
        ? lastChildText!.trim()
        : recording
        ? '나는 이렇게 생각해요…'
        : transcribing
        ? '말한 내용을 잠깐 확인하고 있어요.'
        : guideSpeaking
        ? '친구 말이 끝나면 말할 수 있어요.'
        : listening
        ? (micNeedsTap ? '마이크를 누르고 말해 주세요.' : '마이크가 자동으로 켜졌어요.')
        : '질문이 끝나면 마이크가 켜져요.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: BoxConstraints(
        minHeight: compact ? 128 : 154,
        maxHeight: max(maxHeight, compact ? 128.0 : 154.0),
      ),
      padding: EdgeInsets.all(compact ? 15 : 20),
      decoration: BoxDecoration(
        color: const Color(0xF2123252),
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(
          color: listening ? const Color(0xFF77E0C4) : Colors.white38,
          width: listening ? 3 : 1.5,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          _ListeningMic(
            ready: micReady,
            recording: recording,
            busy: transcribing || submitting,
            onTap: onMicTap,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: lastChildText == null ? status : '내가 한 말: $lastChildText',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    status,
                    style: const TextStyle(
                      color: Color(0xFF8DE7CF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  // 아이가 한 말도 자르지 않습니다 - 자기가 한 말이 반쯤
                  // 잘려 보이면 다시 말해야 하는지 알 수 없습니다.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        body,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 20 : 23,
                          height: 1.35,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (sttHint != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      sttHint!,
                      style: const TextStyle(
                        color: Color(0xFFFFD56A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else if (lowConfidence &&
                      lastChildText != null) ...<Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      '잘 들었는지 한 번 더 확인해 주세요.',
                      style: TextStyle(
                        color: Color(0xFFFFD56A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 변환 결과 확인 화면. "맞아요"를 눌러야 턴이 제출된다.
  ///
  /// 글을 못 읽는 아이도 있으므로 문구에만 기대지 않는다 - 버튼을 크게 두 개만
  /// 두고 색과 아이콘(체크/새로고침)으로 "보내기"와 "다시 말하기"를 구분한다.
  /// 저신뢰면 테두리와 제목을 노란색 계열로 바꿔 "확실하지 않다"는 신호를 준다.
  ///
  /// 아이가 한 말은 자르지 않는다. 길게 말했으면 [maxHeight] 안에서 굴리고,
  /// 버튼 두 개는 어떤 경우에도 화면에 남는다 - 잘린 말과 사라진 버튼은
  /// 아이에게 "여기서 뭘 해야 하는지"를 통째로 숨긴다.
  Widget _buildConfirmView() {
    final PlayTranscription result = pending!;
    final Color accent = result.lowConfidence
        ? const Color(0xFFFFD56A)
        : const Color(0xFF77E0C4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: BoxConstraints(
        minHeight: compact ? 128 : 154,
        maxHeight: maxHeight,
      ),
      padding: EdgeInsets.all(compact ? 15 : 20),
      decoration: BoxDecoration(
        color: const Color(0xF2123252),
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(color: accent, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Semantics(
        liveRegion: true,
        label: '이렇게 들었어요: ${result.text}. 맞으면 맞아요를 누르세요.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              result.lowConfidence ? '이렇게 들었는데, 맞을까요?' : '이렇게 들었어요',
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  result.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 20 : 23,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (result.lowConfidence) ...<Widget>[
              const SizedBox(height: 6),
              const Text(
                '잘 못 알아들었을 수도 있어요.',
                style: TextStyle(
                  color: Color(0xFFFFD56A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            SizedBox(height: compact ? 12 : 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: compact ? 48 : 54,
                    child: FilledButton.icon(
                      onPressed: submitting ? null : onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF72D6B7),
                        foregroundColor: const Color(0xFF10314A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 26),
                      label: const Text(
                        '맞아요',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: compact ? 48 : 54,
                    child: OutlinedButton.icon(
                      onPressed: submitting ? null : onRetry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFD56A),
                        side: const BorderSide(
                          color: Color(0xFFFFD56A),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 26),
                      label: const Text(
                        '다시 말할래요',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// TODO: Remove after downstream story branches finish migrating to the overlay UI.
// ignore: unused_element
class _CharacterSlot extends StatelessWidget {
  const _CharacterSlot({
    required this.asset,
    required this.name,
    // ignore: unused_element_parameter
    this.compact = false,
  });

  final String? asset;
  final String name;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$name 캐릭터',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 24 : 34),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (asset != null)
              _StoryBackdrop(asset: asset)
            else
              const _FallbackStoryBackdrop(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x00142C46),
                    Color(0x22142C46),
                    Color(0xD9142C46),
                  ],
                ),
              ),
            ),
            Positioned(
              left: compact ? 16 : 24,
              right: compact ? 16 : 24,
              bottom: compact ? 14 : 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '이야기 친구',
                    style: TextStyle(
                      color: Color(0xFFFFDE79),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 24 : 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TODO: Remove after downstream story branches finish migrating to the overlay UI.
// ignore: unused_element
class _DialoguePanel extends StatelessWidget {
  const _DialoguePanel({
    required this.characterName,
    required this.question,
    required this.phase,
    required this.seconds,
    required this.recording,
    required this.transcribing,
    required this.submitting,
    required this.onMicTap,
    required this.lastChildText,
    required this.lastSttLowConfidence,
    // ignore: unused_element_parameter
    this.compact = false,
  });

  final String characterName;
  final String question;
  final _DialoguePhase phase;
  final int seconds;
  final bool recording;
  final bool transcribing;
  final bool submitting;
  final VoidCallback? onMicTap;
  final String? lastChildText;
  final bool lastSttLowConfidence;
  final bool compact;

  bool get listening => phase == _DialoguePhase.listening;

  @override
  Widget build(BuildContext context) {
    final String status = transcribing
        ? '목소리를 글로 바꾸는 중'
        : submitting
        ? '$characterName 친구가 생각하는 중'
        : recording
        ? '아이가 말하는 중 · $seconds초'
        : listening
        ? '딩동! 이제 네 차례'
        : '$characterName 친구가 이야기하는 중';
    final Color accent = listening || recording
        ? const Color(0xFF1C9B75)
        : const Color(0xFF396EA8);

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3),
        borderRadius: BorderRadius.circular(compact ? 24 : 34),
        border: Border.all(color: const Color(0xFFFFD66B), width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x44081729),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  recording
                      ? Icons.graphic_eq_rounded
                      : listening
                      ? Icons.notifications_active_rounded
                      : transcribing || submitting
                      ? Icons.hourglass_top_rounded
                      : AppIcons.characterSpeaking,
                  color: accent,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: accent,
                      fontSize: compact ? 18 : 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 14 : 22),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: question,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '“$question”',
                  maxLines: compact ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF172A3E),
                    fontSize: compact ? 27 : 34,
                    height: 1.42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
              ),
            ),
          ),
          if (lastChildText != null && (submitting || !listening)) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.child_care_rounded,
                    color: Color(0xFF527267),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '내가 한 말: $lastChildText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF385448),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (lastSttLowConfidence)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        '다시 확인해도 좋아요',
                        style: TextStyle(
                          color: Color(0xFFC56636),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          _ChildBubble(
            phase: phase,
            seconds: seconds,
            recording: recording,
            transcribing: transcribing,
            onMicTap: onMicTap,
            compact: compact,
            submitting: submitting,
          ),
        ],
      ),
    );
  }
}

class _ChildBubble extends StatelessWidget {
  const _ChildBubble({
    required this.phase,
    required this.seconds,
    required this.recording,
    required this.transcribing,
    required this.onMicTap,
    required this.submitting,
    this.compact = false,
  });

  final _DialoguePhase phase;
  final int seconds;
  final bool recording;
  final bool transcribing;
  final VoidCallback? onMicTap;
  final bool submitting;
  final bool compact;

  bool get listening => phase == _DialoguePhase.listening;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _RightTailPainter(color: Color(0xFF123252)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: const BoxConstraints(minHeight: 150),
        padding: EdgeInsets.all(compact ? 16 : 20),
        decoration: BoxDecoration(
          color: const Color(0xF2123252),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: listening ? const Color(0xFF77E0C4) : Colors.white38,
            width: listening ? 3 : 1.5,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            _ListeningMic(
              ready: listening,
              recording: recording,
              busy: transcribing || submitting,
              onTap: onMicTap,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    transcribing
                        ? '목소리를 글로 바꾸고 있어요'
                        : submitting
                        ? '생각을 이야기 친구에게 전했어요'
                        : recording
                        ? '잘 듣고 있어요 · $seconds초'
                        : listening
                        ? '말할 준비가 됐어요'
                        : '질문을 듣고 있어요',
                    style: const TextStyle(
                      color: Color(0xFF8DE7CF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    recording
                        ? '나는 이렇게 생각해요!'
                        : transcribing
                        ? '잠깐만 기다려 주세요...'
                        : submitting
                        ? '대답을 준비하고 있어요. 잠시만 기다려요.'
                        : listening
                        ? '마이크를 누르고 이야기해 주세요.'
                        : '질문이 끝나면 말할 차례가 와요.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (recording) ...<Widget>[
                    const SizedBox(height: 10),
                    const Text(
                      '말을 마치면 마이크를 다시 눌러 주세요',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningMic extends StatelessWidget {
  const _ListeningMic({
    required this.ready,
    required this.recording,
    required this.busy,
    required this.onTap,
  });

  final bool ready;
  final bool recording;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: recording
          ? '마이크 켜짐'
          : ready
          ? '마이크 준비됨'
          : '마이크 준비 중',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: recording
              ? const Color(0xFFFF7B68)
              : ready
              ? const Color(0xFF77E0C4)
              : const Color(0xFF6D8094),
          shape: BoxShape.circle,
          boxShadow: recording
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x88FF7B68),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: IconButton(
          tooltip: recording
              ? '말하기 완료'
              : ready
              ? '눌러서 말하기'
              : '질문을 듣는 중이에요',
          onPressed: busy ? null : onTap,
          icon: busy
              ? const CircularProgressIndicator(strokeWidth: 3)
              : Icon(recording ? Icons.stop_rounded : AppIcons.speak),
          iconSize: 44,
          color: const Color(0xFF123252),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onExit});

  final VoidCallback onResume;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xD10C1C2F),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.pause_circle_rounded,
                color: Color(0xFF4B8EC2),
                size: 76,
              ),
              const SizedBox(height: 12),
              const Text(
                '이야기를 잠시 멈췄어요',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('계속 듣기'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onExit, child: const Text('이야기 나가기')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSceneOverlay extends StatelessWidget {
  const _ResultSceneOverlay({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xE60D2238),
      child: SafeArea(
        minimum: const EdgeInsets.all(28),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                SizedBox(
                  width: 1060,
                  height: 620,
                  child: _StoryBackdrop(asset: imageUrl),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  color: const Color(0xD9142C46),
                  child: const Text(
                    '네 생각이 이야기 속에서 펼쳐지고 있어요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RightTailPainter extends CustomPainter {
  const _RightTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 6, 38)
        ..lineTo(size.width + 24, 20)
        ..lineTo(size.width - 5, 68)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0x1677E0C4);
    canvas.drawCircle(
      Offset(size.width * .15, size.height * .22),
      size.width * .16,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .28),
      size.width * .22,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * .62, size.height * .9),
      size.width * .26,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
