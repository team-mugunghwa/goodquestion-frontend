import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/kid_speech_bubble.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../story/domain/repositories/story_repository.dart';
import '../../data/dialogue_word_capture.dart';
import '../../data/stt_choice_catalog.dart';
import '../../data/stt_choice_selector.dart';
import '../../domain/entities/play_session.dart';
import '../../domain/repositories/play_repository.dart';
import '../character/dialogue_character_manifest.dart';
import '../character/dialogue_character_stage.dart';
import '../character/dialogue_character_state_machine.dart';
import '../voice/mission_voice_recorder.dart';
import '../voice/story_audio_player.dart';
import '../widgets/dialogue_backdrop.dart';
import '../widgets/dialogue_canvas.dart';
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
    this.storyRepository,
    this.voiceRecorder,
    this.audioPlayer,
    this.wordCapture,
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

  /// "처음부터 다시하기"가 새 세션을 만드는 통로. 세션이 생기는 **유일한
  /// 지점**이 이 저장소의 `startSession` 이라, 재생 화면도 그리로 갑니다.
  ///
  /// null 이면(미리보기·테스트) 멈춤 화면에 "처음부터 다시하기"가 뜨지
  /// 않습니다 - 누를 수 없는 버튼을 보여 주는 것보다 없는 편이 낫습니다.
  final StoryRepository? storyRepository;

  final MissionVoiceRecorder? voiceRecorder;
  final StoryAudioPlayer? audioPlayer;

  /// 고정 대사에서 아이가 고른 단어를 단어장에 담는 통로. null 이면 단어
  /// 선택 기능이 꺼집니다(미리보기·테스트).
  final DialogueWordCapture? wordCapture;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  DialoguePhase _phase = DialoguePhase.characterSpeaking;
  DialoguePhase _phaseBeforePause = DialoguePhase.characterSpeaking;
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

  /// 지금 말풍선의 대사가 DB 고정 대사인가(장면 오프닝). LLM이 만든 동적
  /// 대사는 오탈자나 오인식 반영 가능성이 있어 단어장에 담게 하지 않습니다 -
  /// 단어장은 아이가 두고두고 다시 보는 곳이라 원문 품질이 보장된 글만
  /// 들어가야 합니다.
  bool _fixedDialogue = false;

  /// 아이가 담을까 말까 고르는 중인 단어. null 이 아니면 말풍선에
  /// "담을까요?" 확인 줄이 뜹니다.
  String? _pendingWord;

  /// [_pendingWord] 를 고른 순간의 문장. 확인하는 사이 대사가 다음 문장으로
  /// 넘어가도 예문은 단어가 실제로 나온 문장이어야 합니다.
  String? _pendingWordSentence;
  bool _savingWord = false;
  String? _wordNotice;
  Timer? _wordNoticeTimer;

  /// 캐릭터 대사 루프가 아직 살아 있는지. 일시정지를 풀 때 이 값이 true 면
  /// 루프가 스스로 이어 읽으므로 대사를 다시 틀어 주지 않습니다.
  bool _speaking = false;

  /// 일시정지 동안 대사 루프를 붙잡아 두는 문. → [_awaitResume]
  Completer<void>? _pauseGate;

  /// 지금 기다리고 있는 "무음으로 읽는 시간". 일시정지·다음 대사에서
  /// 곧바로 풀어 주려고 들고 있습니다. → [_waitForSpeech] · [_waitForNarration]
  Completer<void>? _speechWait;
  Completer<void>? _narrationWait;

  /// 파일 하나로 여러 문장을 읽는 동안 자막을 넘기는 구독. **재생 위치에
  /// 묶여 있어** 일시정지하면 자막도 함께 멈춘다 — 벽시계 타이머로 만들면
  /// 멈춘 사이에도 자막이 넘어간다.
  StreamSubscription<Duration>? _timingSub;
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
  /// 마이크는 잠깁니다.
  ///
  /// 변환 결과를 받자마자 제출하면 오인식을 되돌릴 방법이 없습니다. 턴이
  /// 처리되고 캐릭터가 대답한 뒤라, 아이가 하지 않은 말이 저장되고 보호자
  /// 리포트 대표 발화 후보에도 오릅니다. 저신뢰 안내가 의미 있는 유일한
  /// 시점도 제출 전이라 여기서 한 번 끊습니다. → 백엔드
  /// `docs/트러블슈팅_STT_신뢰도_산출.md` 3절
  ///
  /// **모든 발화에** 띄웁니다. 서버 신뢰도는 아이가 실제로 무슨 말을 했는지
  /// 알지 못합니다 - 또박또박 말한 문장을 자신 있게 다른 말로 옮겨 놓는 일이
  /// 흔하고, 그런 턴일수록 확인 없이 그대로 저장됩니다. 미션 화면이 이미
  /// "말한다 → 내 말을 본다 → 보낸다"로 동작하고 있어, 대화만 다른 리듬을
  /// 쓰면 아이가 화면마다 다른 규칙을 배워야 합니다.
  PlayTranscription? _pendingTranscription;

  /// 확인 화면 무반응 시계. **저신뢰 결과에만** 겁니다 - "맞을까요?"라고
  /// 물어 놓고 아이가 답을 못 찾으면 이야기가 멈추므로, 6초 뒤 그대로
  /// 제출합니다. 잘 알아들은 턴은 시계를 걸지 않고 아이의 탭을 기다립니다.
  Timer? _confirmTimer;
  String? _retainedStoryImageUrl;

  /// 지금(또는 마지막으로) 들려준 대사 한 덩어리. **다시 듣기가 이것을 그대로
  /// 다시 재생합니다.**
  ///
  /// 예전에는 다시 듣기가 글자만 지금 대사에서 가져오고 소리는 늘 장면
  /// 오프닝(`_snapshot.openingAudioUrl`)을 가리켰습니다. 그래서
  ///
  /// - 사전 렌더 음성이 있는 고정 대사는 **실측 구간을 안 넘겨** 파일 재생
  ///   경로를 못 타고 문장마다 다시 합성됐습니다. 서버의 사전 렌더는 Gemini,
  ///   실시간 합성은 그때 설정된 벤더라 **같은 인물이 다른 목소리로** 들렸습니다.
  /// - 한 문장짜리 LLM 대사를 다시 들으면 화면엔 새 대사, 스피커에서는
  ///   **오프닝 대사**가 나왔습니다.
  ///
  /// 재생을 시작하는 곳이 [_playCharacterMessage] 하나라, 거기서 한 번만
  /// 적어 두면 다시 듣기가 같은 것을 그대로 다시 틉니다.
  _SpokenMessage? _lastSpoken;

  /// 이 화면이 살아 있는 동안의 합성 결과 캐시. 키는 `인물|문장`입니다.
  ///
  /// 같은 문장을 다시 합성하면 **같은 벤더라도 미세하게 다른 소리가 나오고
  /// 아이는 그 차이를 알아챕니다**(백엔드 `데이터베이스_설계.md` 4장). 다시
  /// 듣기·되감기가 잦은 화면이라 왕복(실측 1.5~2.6초)도 그대로 기다림이 됩니다.
  ///
  /// data URL(base64 mp3)이라 한 문장이 수십 KB입니다. 무한정 들고 있지 않고
  /// [_speechCacheLimit] 개를 넘으면 가장 오래된 것부터 버립니다 - 방금 들은
  /// 문장이 다시 듣기의 대상이라 최근 것만 남으면 충분합니다.
  final Map<String, String> _speechCache = <String, String>{};

  static const int _speechCacheLimit = 32;

  /// 멈춤 화면이 **나가기(X)로 떴는가.** 멈춤 버튼으로 뜬 것과 카드는 같고
  /// 묻는 말만 다릅니다. → [_PauseOverlay.exit]
  bool _exitPrompt = false;

  /// 멈춤 화면에서 **"처음부터 다시하기"를 눌러 한 번 더 묻는 중인가.**
  /// 되돌릴 수 없는 행동이라(듣던 세션이 STOPPED 로 끝납니다) 확인을
  /// 한 번 끼웁니다. → [_PauseOverlay.restart]
  bool _restartPrompt = false;

  /// 처음부터 다시하기를 실제로 처리하는 중인가(세션 끝내기 → 새 세션).
  /// 네트워크를 두 번 타므로 그동안 버튼을 잠급니다.
  bool _restarting = false;

  /// 처음부터 다시하기가 실패했을 때 확인 카드에 띄울 한 줄. 성공하면
  /// 화면이 통째로 바뀌므로 이 값이 남을 일이 없습니다.
  String? _restartError;

  /// 지금 화면이 붙잡고 있는 장면. 장면이 바뀌는 순간을 [_activateSnapshot]
  /// 이 알아채고 이전 장면의 아이 발화를 지우는 데 씁니다.
  String? _activeSceneId;

  /// 이 세션의 이야기. **이어하기 응답에만 실려 오고 장면 전환 응답에는
  /// 없어서**, 한 번 받으면 들고 있습니다. 안 들고 있으면 장면이 하나만
  /// 넘어가도 값이 사라져, 정작 필요한 마지막 순간(완료 화면의 후속 자유
  /// 대화 진입점)에 비어 있습니다.
  String? _storyId;

  /// 마지막으로 말을 걸었던 인물. 완료 화면 버튼이 이 이름을 부릅니다.
  /// 장면이 바뀔 때마다 갱신되므로 **끝날 때 값은 마지막 대화 상대**입니다.
  String? _lastCharacterName;
  String? _resultImageUrl;
  DialogueCharacterManifest? _characterManifest;
  DialogueCharacterStateMachine? _character;

  /// 말하기가 끝나 "같이 정리해보자" 한마디를 띄우고 있는 중인지.
  /// → [_beginRecapHandoff] · [_RecapHandoffScreen]
  bool _handingOffToRecap = false;

  /// 그 한마디를 보여 준 뒤 스스로 다음 화면으로 넘어가는 시계.
  /// 아이가 화면을 눌러 먼저 넘어가면 [_goToRecap] 이 취소합니다.
  Timer? _recapHandoffTimer;

  /// 이미 후속 활동으로 보냈는지. 스냅샷이 두 번 들어오거나, 시계와 아이의
  /// 탭이 같은 순간에 겹쳐도 `context.go` 는 **한 번만** 나갑니다.
  bool _recapHandoffDone = false;

  /// 지금 보내고 있는 발화의 Idempotency-Key. 응답을 받으면(성공이든 최종
  /// 실패든) `null`로 되돌립니다 — 재시도 사이에는 같은 키를 유지하고,
  /// 다음 발화는 새 키를 받게 하기 위해서입니다. → `docs/이야기_전개_가이드.md` 3.4
  String? _pendingIdempotencyKey;

  bool get _isListening => _phase == DialoguePhase.listening;

  /// 캐릭터가 지금 무엇을 하고 있는지. 표정과 별개로 모션만 바꾼다.
  DialogueActivity get _activity {
    if (_phase == DialoguePhase.paused) return DialogueActivity.idle;
    if (_submittingUtterance || _transcribingVoice) {
      return DialogueActivity.thinking;
    }
    if (_phase == DialoguePhase.listening) return DialogueActivity.listening;
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
    _wordNoticeTimer?.cancel();
    _confirmTimer?.cancel();
    _recapHandoffTimer?.cancel();
    // 화면을 떠나면 기다리던 발화 루프들도 풀어 줍니다 - 안 풀면 취소된
    // 타이머·닫힌 문 앞에서 영영 매달린 채로 남습니다.
    _releaseSpeechWait();
    _releaseNarrationWait();
    _openPauseGate();
    _cancelTimingFollow();
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
        _storyId ??= snapshot.storyId;
        _mission = recoveredMission;
        _characterReply = null;
        _fixedDialogue = false;
        _pendingWord = null;
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
    // 말하기가 끝났습니다. **여기서 곧바로 화면을 갈아 끼우지 않습니다** -
    // 캐릭터와 이야기하다가 예고 없이 다른 화면으로 넘어가면, 아이에게는
    // 대화하던 친구가 사라지고 다른 앱으로 튕긴 일이 됩니다. 대신 지금 화면
    // 위에 한마디를 얹고([_beginRecapHandoff]) 그 뒤에 넘깁니다.
    //
    // 아래 "장면이 바뀌었다" 정리나 [_bindCharacterScene] 보다 **먼저** 빠져
    // 나갑니다. 후속 활동 스냅샷에는 `currentScene` 이 없어서, 그대로 흘려
    // 보내면 [_character] 가 지워집니다 - 전환 화면이 그 캐릭터를 그대로
    // 이어 그리므로([_RecapHandoffScreen]), 여기서 내려보내면 말을 걸던
    // 친구가 사라진 채 글자만 남습니다.
    if (snapshot.phase == PlayPhase.postActivity) {
      _beginRecapHandoff();
      return;
    }
    // 장면이 바뀌면 이전 장면에서 아이가 한 말은 지웁니다 - 새 캐릭터가
    // 말을 거는데 아직 하지도 않은 대답이 떠 있으면 안 됩니다. 같은 장면을
    // 다시 활성화하는 경우(이어하기 복원)에는 그대로 둡니다.
    final String? sceneId = snapshot.currentScene?.sceneId;
    final String? characterName = snapshot.currentScene?.characterName;
    if (characterName != null && characterName.isNotEmpty) {
      _lastCharacterName = characterName;
    }
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
      _fixedDialogue = true;
      unawaited(
        _playCharacterMessage(
          snapshot.openingText!,
          audioUrl: snapshot.openingAudioUrl,
          audioTimings: snapshot.openingAudioTimings,
          onComplete: _startListening,
        ),
      );
    } else {
      unawaited(_loadOpeningMessage());
    }
  }

  /// 가만히 두었을 때 전환 화면이 머무는 시간.
  ///
  /// 읽을 것이 제목("말하기 후 활동")과 한마디 두 줄이고, 그 아래 `시작`
  /// 버튼까지 눈에 들어와야 합니다. 초1~3이 두 줄을 따라 읽는 데만 3초쯤
  /// 걸리므로, 말풍선 한 줄만 띄우던 시절의 2.5초로는 버튼을 보기도 전에
  /// 화면이 바뀝니다. 반대로 더 늘리면 버튼을 누를 줄 아는 아이가 기다립니다.
  static const Duration _recapHandoffDelay = Duration(milliseconds: 4500);

  /// 말하기 후 활동으로 넘어가기 전, 전환 화면을 띄웁니다.
  ///
  /// 화면은 [_RecapHandoffScreen] 이 통째로 덮지만, 뒤에서 돌던 것들은 여기서
  /// 모두 멈춰야 합니다 - 덮어 놓기만 하면 보이지 않는 곳에서 이전 장면의
  /// 대사가 계속 흘러나오고 마이크가 저 혼자 켜집니다.
  ///
  /// 후속 활동 스냅샷이 두 번 들어와도([_loadSession] 재시도 등) 두 번째부터는
  /// 아무 일도 하지 않습니다 - 시계가 두 개 걸리면 안 됩니다.
  void _beginRecapHandoff() {
    if (_handingOffToRecap || _recapHandoffDone) return;
    // 하던 말·예약된 다음 문장·오디오를 모두 끊습니다.
    _stopSpeaking();
    _confirmTimer?.cancel();
    _wordNoticeTimer?.cancel();
    if (_recordingVoice) unawaited(_voiceRecorder.cancel());
    setState(() {
      _handingOffToRecap = true;
      // 이제 말하는 쪽은 캐릭터입니다. 안 바꾸면 오버레이 뒤에서 마이크가
      // "듣는 중" 모양으로 남아, 넘어가기 직전까지 아이 차례처럼 보입니다.
      _phase = DialoguePhase.characterSpeaking;
      _recordingVoice = false;
      _transcribingVoice = false;
      _pendingTranscription = null;
      _pendingWord = null;
      _wordNotice = null;
    });
    _recapHandoffTimer = Timer(_recapHandoffDelay, _goToRecap);
  }

  /// 후속 활동으로 넘깁니다. 시계가 다 됐거나 아이가 `시작` 을 눌렀을 때.
  ///
  /// 둘 중 무엇이 먼저 오든 **한 번만** 나갑니다.
  void _goToRecap() {
    if (_recapHandoffDone || !mounted) return;
    _recapHandoffDone = true;
    _recapHandoffTimer?.cancel();
    context.go(
      AppRoutes.playRecapOf(
        widget.sessionId,
        // 완료 화면의 "○○와 더 이야기하기" 진입점이 쓰는 값. 활동 API 가
        // 이야기·인물을 안 내려줘서 여기서 실어 보냅니다.
        storyId: _storyId,
        characterName: _lastCharacterName,
      ),
    );
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
      setState(() {
        _characterReply = opening.text;
        _fixedDialogue = true;
      });
      await _playCharacterMessage(
        opening.text,
        audioUrl: opening.audioUrl,
        audioTimings: opening.audioTimings,
        onComplete: _startListening,
      );
    } on Failure catch (error) {
      if (!mounted) return;
      if (await _tryAutoRecover(error)) return;
      setState(() => _loadError = _describeFailure(error));
    }
  }

  /// 고정 대사의 단어를 아이가 눌렀다. 구두점만 걷어내고 잡아 둔다 -
  /// 조사는 떼지 않는다. 형태소 분석 없이 끝 글자를 자르면 "마을"의 "을"처럼
  /// 낱말 일부를 조사로 오인해 단어를 훼손한다. 조사째 담긴 단어도 서버 뜻
  /// 생성이 낱말 기준으로 풀어 준다.
  void _onDialogueWordTap(String token) {
    final String word = token.replaceAll(_wordTrimPattern, '').trim();
    if (word.isEmpty || _savingWord) return;
    setState(() {
      _pendingWord = word;
      // 예문은 고정 대사에서만 잡는다. 동적 대사 문장은 아이 발화의 오인식
      // 인용이 섞일 수 있어, 서버가 사전/생성 예문으로 채우게 비워 보낸다.
      _pendingWordSentence = _fixedDialogue ? _visibleCharacterText : null;
      _wordNotice = null;
    });
  }

  static final RegExp _wordTrimPattern = RegExp(
    '[.,!?"\'\u2026:;()\\[\\]~\u00b7]',
  );

  Future<void> _confirmWordSave() async {
    final DialogueWordCapture? capture = widget.wordCapture;
    final String? word = _pendingWord;
    if (capture == null || word == null || _savingWord) return;
    final String? sentence = _pendingWordSentence;
    setState(() => _savingWord = true);
    try {
      final WordCaptureOutcome outcome = await capture.save(
        word: word,
        sourceSceneId: _snapshot?.currentScene?.sceneId,
        exampleSentence: sentence,
      );
      if (!mounted) return;
      // 안내는 서버가 실제 저장한 표제어로 한다("기왓장이" -> "기왓장").
      // 아이가 단어장 화면에서 보게 될 형태와 같아야 헷갈리지 않는다.
      final String savedWord = outcome.savedWord ?? word;
      _showWordNotice(switch (outcome.result) {
        WordCaptureResult.saved => "'$savedWord' 단어장에 담았어요",
        WordCaptureResult.duplicate => "'$word' 이미 담아 둔 단어예요",
      });
    } on Failure catch (error) {
      if (!mounted) return;
      // 담기 실패로 이야기 흐름을 막지 않는다 - 안내만 하고 대화는 그대로.
      // INVALID_WORD는 실패가 아니라 판정이다 - 동적 대사의 오인식 단어를
      // 서버가 거른 것이니 문구도 그렇게 말한다.
      final bool notRealWord =
          error is ServerFailure && error.code == 'INVALID_WORD';
      _showWordNotice(
        notRealWord
            ? '이 말은 단어장에 담기 어려워요. 다른 단어를 골라 볼까?'
            : '지금은 담을 수 없어요. 나중에 다시 눌러 볼까?',
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingWord = false;
          _pendingWord = null;
          _pendingWordSentence = null;
        });
      }
    }
  }

  void _cancelWordSave() {
    if (_savingWord) return;
    setState(() {
      _pendingWord = null;
      _pendingWordSentence = null;
    });
  }

  void _showWordNotice(String message) {
    _wordNoticeTimer?.cancel();
    setState(() => _wordNotice = message);
    _wordNoticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _wordNotice = null);
    });
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
      _phase = DialoguePhase.characterSpeaking;
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
        _fixedDialogue = false;
        _pendingWord = null;
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
      // 벤더 계열 실패는 발화 제출에서도 화면을 갈아엎지 않습니다. 듣기
      // 상태로 돌려 아이가 다시 말할 수 있게 둡니다.
      final String? voiceHint = _voiceRetryHint(error);
      if (voiceHint != null) {
        setState(() {
          _submittingUtterance = false;
          _transcribingVoice = false;
          _phase = DialoguePhase.listening;
          _sttHint = voiceHint;
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
      // 목소리 관련 코드는 마이크 옆 안내와 **같은 문구를 씁니다**. 두 벌로
      // 두면 같은 상황에서 화면마다 다른 말이 떠서, 아이는 다른 일이 난 줄
      // 압니다.
      final String? voiceHint = _voiceRetryHint(error);
      if (voiceHint != null) return voiceHint;
      switch (error.code) {
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
            // 업로드 한도(10MB, 웹 48kHz 기준 109초)에 닿기 전에 여기까지
            // 말한 것을 보낸다. 상한을 넘겨 두면 통째로 413이 나서 아이가
            // 말한 전부를 잃는다.
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
      // 변환 결과는 **신뢰도와 상관없이** 아이에게 먼저 보여 줍니다. 바로
      // 제출하면 오인식을 되돌릴 방법이 없습니다 - 재발화 한 번이 오인식을
      // 정인식으로 바꾸는 가장 값싼 개입이고, 제출 전이 그럴 수 있는 유일한
      // 시점입니다. 미션 화면이 이미 이렇게 동작하고 있어 대화도 같은 리듬을
      // 씁니다(말한다 → 내 말을 본다 → 보낸다).
      setState(() {
        _transcribingVoice = false;
        _pendingTranscription = transcription;
        // 선택지 판은 말풍선 자리를 대신 쓰므로, 떠 있는 채로 두면 확인
        // 화면이 그 밑에 가려집니다. 목소리로 말하는 데 성공한 참이니
        // 카드는 접습니다 - 다시 못 알아들으면 3회째에 다시 내려옵니다.
        _closeChoicesState();
      });
      _confirmTimer?.cancel();
      // 저신뢰일 때만 무반응 시계를 겁니다. 저신뢰 화면은 "맞을까요?"라고
      // 물어 놓고 아이가 답을 못 찾으면 이야기가 멈춰 버리므로 안전망이
      // 필요합니다. 반대로 잘 알아들은 턴은 아이가 눌러야만 보냅니다 -
      // 자동으로 넘어가면 확인 화면이 "확인"이 아니라 잠깐 스쳐 가는
      // 자막이 되고, 아이는 자기 말을 고칠 기회를 사실상 못 받습니다.
      if (transcription.lowConfidence) {
        _confirmTimer = Timer(
          const Duration(seconds: 6),
          () => unawaited(_confirmTranscription()),
        );
      }
    } on Failure catch (error) {
      // 무음이거나 인식 실패 - 흔히 겪는 상황이라 화면을 통째로 에러로
      // 바꾸지 않고 마이크 옆에 짧게 안내한 뒤 바로 다시 녹음할 수 있게
      // 둡니다. → `docs/이야기_전개_가이드.md` 3.4, 6장
      // 녹음이 서버 한도를 넘은 경우(413)도 이 자리입니다. 실서버에서
      // 확인해 보니 전면 에러 화면이 떠서 아이가 대화 중간에 통째로 튕겼는데,
      // 이건 이야기가 깨진 게 아니라 "이번에 말한 게 너무 길었다"일 뿐입니다.
      // 다시 녹음하면 그만이라 자리를 지키고 안내만 바꿉니다.
      // → `docs/이야기_전개_가이드.md` 6장
      final String? voiceHint = _voiceRetryHint(error);
      if (voiceHint != null) {
        // 캐릭터가 하는 말과 **겹치지 않을 때만** 작은 글씨를 함께 남깁니다.
        // STT_EMPTY_TEXT 는 캐릭터가 이미 "다시 한 번 말해 줄래?"라고 하는
        // 자리라 같은 말을 두 번 띄우게 됩니다.
        final bool addsInstruction =
            error is ServerFailure && error.code != 'STT_EMPTY_TEXT';
        _recordFailedSttAttempt(voiceHint, codeSpecific: addsInstruction);
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

  /// 마이크 옆 안내로 처리할 실패인지 판별하고, 맞으면 아이가 읽을 문구를
  /// 돌려줍니다. 화면 전체를 에러로 바꾸지 않는 것이 요점입니다 - 아이는
  /// 대화 중이고, 이 부류는 다시 말하거나 잠시 뒤 하면 풀립니다.
  ///
  /// 안내가 갈리는 이유: `AUDIO_TOO_LARGE`는 **같은 녹음을 다시 보내면 또
  /// 실패**하므로 "짧게"라고 해야 하고, 벤더 계열은 그대로 다시 하면 되는
  /// 부류라 기다리라고 해야 합니다. 둘을 같은 문구로 묶으면 아이가 계속
  /// 막히거나 그냥 포기합니다. → 명세 1장 에러 표
  String? _voiceRetryHint(Failure error) {
    if (error is! ServerFailure) return null;
    return switch (error.code) {
      'STT_EMPTY_TEXT' => '잘 못 들었어요. 다시 말해 볼까?',
      'AUDIO_TOO_LARGE' => '조금만 짧게 말해 줄래?',
      // 서버 원문("서버 오류가 발생했습니다")은 아이가 읽을 말이 아닙니다.
      'AI_RATE_LIMITED' ||
      'AI_UPSTREAM_ERROR' ||
      'AI_UNAVAILABLE' => '지금은 잘 안 들려요. 잠시 뒤에 다시 해볼까?',
      _ => null,
    };
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
  void _recordFailedSttAttempt(String hint, {bool codeSpecific = false}) {
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
      //
      // 다만 **원인이 분명한 안내는 남깁니다**([codeSpecific]). 캐릭터가 하는
      // 말은 어느 실패에나 같은 "다시 한 번 말해 줄래?"라서, 이걸로 덮으면
      // 413에 걸린 아이가 또 길게 말해 또 413을 받습니다. 원인별로 갈라 준
      // 코드(백엔드 #68)가 화면까지 오지 못하면 갈라 준 의미가 없습니다.
      _sttHint = (guide == null || codeSpecific) ? hint : null;
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

  /// 아이가 변환 결과를 맞다고 확인했습니다(또는 6초 무반응). 이제서야 턴을
  /// 보냅니다.
  Future<void> _confirmTranscription() async {
    final PlayTranscription? pending = _pendingTranscription;
    _confirmTimer?.cancel();
    _confirmTimer = null;
    if (!mounted || pending == null || _submittingUtterance) return;
    setState(() => _pendingTranscription = null);
    await _submitDialogue(
      pending.text,
      // 화면에 보인 텍스트가 아니라 **STT 원문**을 보냅니다. 서버는 이 값으로
      // 인식 품질을 재는데, 다듬은 텍스트를 보내면 그 신호가 지워집니다.
      sttRawText: pending.rawText,
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
    _confirmTimer?.cancel();
    _confirmTimer = null;
    if (!mounted || _pendingTranscription == null || _submittingUtterance) {
      return;
    }
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
        audioTimings: result.closingReactionAudioTimings,
      );
    }
    final String? reply = result.characterText;
    if (reply != null && reply.trim().isNotEmpty) {
      await _playCharacterMessage(
        reply,
        audioUrl: result.characterAudioUrl,
        audioTimings: result.characterAudioTimings,
      );
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
        _fixedDialogue = false;
        _pendingWord = null;
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
    final PlayScene? scene = _snapshot?.currentScene;
    if (_narrationIndex == 0 &&
        scene != null &&
        scene.narrationAudioUrl != null &&
        scene.narrationTimings.isNotEmpty) {
      final bool playedFromFile = await _playNarrationFromFile(
        scene,
        sentences.length,
        token: token,
      );
      if (!mounted || token != _speechToken) return;
      if (_storyPaused) return;
      if (playedFromFile) {
        setState(() => _narrationIndex = sentences.length);
        _scheduleCurrentNarration();
        return;
      }
      // 재생 실패 - 아래 문장별 합성으로 그대로 폴백한다.
    }
    final String sentence = sentences[_narrationIndex];
    bool played = false;
    // 소리를 꺼도 합성과 재생은 그대로 합니다 - 볼륨만 0입니다. 그래야 문장이
    // 오디오 길이에 맞춰 넘어가고, 다시 켜는 순간 되감기 없이 바로 들립니다.
    if (widget.repository != null) {
      try {
        // 내레이션은 characterName 없이 부릅니다 - 서버 규칙상 그래야
        // 내레이션 보이스가 나옵니다.
        final String narrationUrl = await _synthesize(sentence);
        debugPrint('[narration] tts ok, audioUrl len=${narrationUrl.length}');
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
        await _audioPlayer.playUrl(narrationUrl);
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
    _exitPrompt = false;
    _restartPrompt = false;
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

  /// 문장 하나를 소리로 바꿉니다. **같은 문장은 화면이 사는 동안 한 번만
  /// 합성합니다** → [_speechCache].
  ///
  /// [characterName] 이 null 이면 내레이션 보이스입니다(서버 규칙).
  Future<String> _synthesize(String text, {String? characterName}) async {
    final String key = '${characterName ?? ''}|$text';
    final String? cached = _speechCache[key];
    if (cached != null) return cached;
    final PlaySpeechAudio audio = await widget.repository!.synthesizeSpeech(
      text: text,
      characterName: characterName,
    );
    if (audio.audioUrl.isNotEmpty) {
      if (_speechCache.length >= _speechCacheLimit) {
        _speechCache.remove(_speechCache.keys.first);
      }
      _speechCache[key] = audio.audioUrl;
    }
    return audio.audioUrl;
  }

  Future<void> _playQuestion() async {
    if (_recordingVoice) {
      await _voiceRecorder.cancel();
      if (!mounted) return;
      setState(() => _recordingVoice = false);
    }
    // 방금 들려준 대사를 **소리까지 통째로** 다시 틉니다. 글자·소리·실측
    // 구간을 따로 고르면 안 됩니다 - 사전 렌더가 없는 대사(LLM 대답)의 빈
    // audioUrl 자리에 오프닝 파일이 끼어들어, 화면엔 새 대사인데 스피커에선
    // 오프닝이 나오던 것이 그 때문이었습니다.
    //
    // 아직 아무것도 들려주지 않았다면(첫 재생) 지금 화면의 대사와 장면
    // 오프닝 음성입니다.
    final _SpokenMessage message =
        _lastSpoken ??
        _SpokenMessage(
          text: _characterReply ?? _snapshot?.openingText ?? widget.question,
          audioUrl: _snapshot?.openingAudioUrl,
          audioTimings:
              _snapshot?.openingAudioTimings ?? const <PlayAudioTiming>[],
        );
    unawaited(
      _playCharacterMessage(
        message.text,
        audioUrl: message.audioUrl,
        audioTimings: message.audioTimings,
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
    List<PlayAudioTiming> audioTimings = const <PlayAudioTiming>[],
    VoidCallback? onComplete,
  }) async {
    final int token = ++_speechToken;
    // 방금 토큰을 올렸으니 안내(_speakGuide)·카드(_playChoiceCard) 재생 루프의
    // 리셋이 건너뛰어진다 - 그 몫을 여기서 대신 내린다. 어차피 바로 아래
    // stop() 이 그 소리를 끊으므로 안내가 말하는 중이라는 표시는 이제 사실이
    // 아니다. 안 내리면 박제되어 다음 턴 맞장구(_playFiller)가 물러난다.
    _guideSpeaking = false;
    _playingChoiceId = null;
    // 다시 듣기가 그대로 다시 틀 수 있게 적어 둡니다 - 글자·소리·실측 구간이
    // 한 묶음이라야 같은 목소리로 다시 들립니다.
    _lastSpoken = _SpokenMessage(
      text: text,
      audioUrl: audioUrl,
      audioTimings: audioTimings,
    );
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
      _phase = DialoguePhase.characterSpeaking;
      _characterSentences = sentences;
      _characterSentenceIndex = 0;
      _listeningSeconds = 0;
    });

    _speaking = true;
    try {
      // 사전 렌더 음성이 실측 구간과 함께 오면 **문장 수와 무관하게** 그 파일
      // 하나를 재생한다. 예전에는 한 문장짜리만 썼는데, 그러면 두 문장 이상인
      // 고정 대사 4개가 매번 다시 합성됐다(왕복 비용 + 벤더가 갈리면 딴 목소리).
      bool playedFromFile = false;
      if (audioUrl != null && audioTimings.isNotEmpty) {
        playedFromFile = await _speakFromFile(
          audioUrl,
          audioTimings,
          sentences.length,
          token: token,
        );
      }
      if (!playedFromFile) {
        await _speakSentences(sentences, token: token, audioUrl: audioUrl);
      }
    } finally {
      if (token == _speechToken) _speaking = false;
    }
    if (mounted && token == _speechToken) onComplete?.call();
  }

  /// 상대 경로(`/tts/...`)를 백엔드 origin 기준 절대 URL로 바꾼다.
  /// data URL과 절대 URL은 그대로 통과한다.
  String _resolveMediaUrl(String source) => source.startsWith('/')
      ? Uri.parse(AppConfig.apiBaseUrl).resolve(source).toString()
      : source;

  /// 재생 위치가 문장 실측 구간을 지날 때마다 [apply]에 문장 인덱스를 준다.
  ///
  /// 건 구독을 돌려준다 — 뒷정리는 **자기 것만** 끊어야 하기 때문이다
  /// ([_stopFollowingTimings]).
  StreamSubscription<Duration> _followTimings(
    List<PlayAudioTiming> timings,
    int sentenceCount,
    void Function(int index) apply,
  ) {
    unawaited(_timingSub?.cancel());
    final StreamSubscription<Duration> subscription = _audioPlayer.onPosition
        .listen((Duration position) {
          final double seconds = position.inMilliseconds / 1000.0;
          int index = 0;
          for (final PlayAudioTiming timing in timings) {
            if (seconds >= timing.start) index = timing.index;
          }
          if (sentenceCount > 0 && index >= sentenceCount) {
            index = sentenceCount - 1;
          }
          apply(index);
        });
    _timingSub = subscription;
    return subscription;
  }

  /// **자기가 건 구독만** 끊는다.
  ///
  /// 다시 듣기는 앞 재생이 아직 `playUrl` 을 기다리는 동안 새 재생을 건다
  /// (`stop()` 을 기다리지 않는다). 그래서 새 구독이 먼저 걸리고, 곧이어
  /// 풀려난 앞 재생의 뒷정리가 뒤늦게 돈다 — 그때 필드를 통째로 비우면
  /// 방금 건 구독이 끊겨서 **소리는 끝까지 나오는데 자막만 첫 문장에 멈춘다.**
  void _stopFollowingTimings(StreamSubscription<Duration>? subscription) {
    unawaited(subscription?.cancel());
    if (identical(_timingSub, subscription)) _timingSub = null;
  }

  /// 지금 걸린 구독을 주인과 무관하게 끊는다. 발화를 통째로 끊거나
  /// ([_stopSpeaking]) 화면을 떠날 때만 쓴다 — 뒤이어 새 재생이 걸리는
  /// 자리에서 쓰면 위의 문제가 그대로 돌아온다.
  void _cancelTimingFollow() {
    unawaited(_timingSub?.cancel());
    _timingSub = null;
  }

  /// 사전 렌더 파일 하나로 대사 전체를 읽는다. 자막은 실측 구간을 따른다.
  ///
  /// 실패하면 false - 호출자가 문장별 합성으로 폴백한다. 토큰이 바뀌었으면
  /// true를 돌려 폴백까지 막는다(이미 다른 발화로 넘어갔다).
  Future<bool> _speakFromFile(
    String audioUrl,
    List<PlayAudioTiming> timings,
    int sentenceCount, {
    required int token,
  }) async {
    await _awaitResume(token);
    if (!mounted || token != _speechToken) return true;
    final StreamSubscription<Duration> subscription = _followTimings(
      timings,
      sentenceCount,
      (int index) {
        if (!mounted || token != _speechToken) return;
        if (_characterSentenceIndex != index) {
          setState(() => _characterSentenceIndex = index);
        }
      },
    );
    try {
      await _audioPlayer.playUrl(_resolveMediaUrl(audioUrl));
      return true;
    } on Object catch (error) {
      debugPrint('[dialogue] prerendered play FAILED: $error');
      return false;
    } finally {
      _stopFollowingTimings(subscription);
    }
  }

  /// 사전 렌더 내레이션 파일 하나로 장면 전체를 읽는다. 문장마다 /api/tts를
  /// 부르던 왕복(장면당 2~4회)이 사라지고, 화자도 사전 렌더와 같아진다.
  Future<bool> _playNarrationFromFile(
    PlayScene scene,
    int sentenceCount, {
    required int token,
  }) async {
    final String? audioUrl = scene.narrationAudioUrl;
    if (audioUrl == null) return false;
    final StreamSubscription<Duration> subscription = _followTimings(
      scene.narrationTimings,
      sentenceCount,
      (int index) {
        if (!mounted || token != _speechToken) return;
        if (_narrationIndex != index) {
          setState(() => _narrationIndex = index);
        }
      },
    );
    try {
      await _audioPlayer.playUrl(_resolveMediaUrl(audioUrl));
      return true;
    } on Object catch (error) {
      debugPrint('[narration] prerendered play FAILED: $error');
      return false;
    } finally {
      _stopFollowingTimings(subscription);
    }
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
          final String characterName =
              _snapshot?.currentScene?.characterName ?? widget.characterName;
          final String source = index == 0 && sentences.length == 1
              ? (audioUrl ??
                    await _synthesize(
                      sentences[index],
                      characterName: characterName,
                    ))
              : await _synthesize(
                  sentences[index],
                  characterName: characterName,
                );
          // 내레이션과 같은 규칙입니다 - 합성을 기다리는 사이에 일시정지를
          // 눌렀으면 틀지 않습니다(멈춘 뒤에 소리가 새로 나오면 안 됩니다).
          if (source.isNotEmpty && _phase != DialoguePhase.paused) {
            await _audioPlayer.playUrl(_resolveMediaUrl(source));
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
      if (!played && _phase != DialoguePhase.paused) {
        final int milliseconds = widget.repository == null
            ? 2000
            : (1200 + sentences[index].length * 55).clamp(1800, 5200).toInt();
        await _waitForSpeech(Duration(milliseconds: milliseconds));
      }
      if (!mounted || token != _speechToken) return;
      if (_phase == DialoguePhase.paused) {
        // 이 문장을 읽는 도중에 멈췄습니다. 다시 재생하면 같은 문장을
        // 처음부터 들려줍니다 - 반쯤 들은 문장을 건너뛰면 말이 끊깁니다.
        index--;
      }
    }
  }

  /// 일시정지 중이면 여기서 잡혀 있다가 "계속 듣기"에 깨어납니다.
  /// 발화 루프를 버리지 않고 재우는 것이 이 화면의 이어 재생 방식입니다.
  Future<void> _awaitResume(int token) async {
    while (mounted && token == _speechToken && _phase == DialoguePhase.paused) {
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
    if (!mounted || _phase == DialoguePhase.paused) return;
    setState(() {
      _phase = DialoguePhase.listening;
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
      if (mounted && _phase == DialoguePhase.listening && !_recordingVoice) {
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
    _exitPrompt = false;
    _restartPrompt = false;
    if (_phase == DialoguePhase.paused) {
      setState(() => _phase = _phaseBeforePause);
      _openPauseGate();
      if (_phase == DialoguePhase.characterSpeaking) {
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
      _phase = DialoguePhase.paused;
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
  /// 나가기(X). **확인 창을 따로 띄우지 않고 일시정지 화면을 그대로 씁니다.**
  ///
  /// 그 화면에 이미 아이가 고를 두 갈래가 있습니다 - "계속 듣기"와
  /// "이야기 나가기". 같은 물음에 생김새가 다른 창을 하나 더 두면, 아이는
  /// 나가려다 만난 화면이 방금 멈춤 버튼으로 본 화면과 왜 다른지부터
  /// 헷갈립니다. 소리도 함께 멈춰서 묻는 동안 이야기가 계속 들리지 않습니다
  /// (예전 확인 창은 뒤에서 이야기가 그대로 흘렀습니다).
  void _requestExit() {
    if (_snapshot?.phase == PlayPhase.story) {
      if (!_storyPaused) _toggleStoryPause();
    } else if (_phase != DialoguePhase.paused) {
      _togglePause();
    }
    // 멈춘 뒤에 세웁니다 - 위 토글이 이 표시를 지웁니다.
    setState(() {
      _exitPrompt = true;
      _restartPrompt = false;
    });
  }

  /// 일시정지 화면의 "이야기 나가기". **다시 묻지 않습니다** - 멈춤 화면에서
  /// 두 갈래 중 하나를 이미 고른 것이라, 여기서 또 물으면 같은 질문을 두 번
  /// 하는 셈입니다.
  ///
  /// 세션은 끝내지 않습니다(`stop` 을 부르지 않습니다) - 되돌릴 수 없는
  /// 행동에만 씁니다. 화면을 벗어나는 것은 그런 행동이 아닙니다.
  /// → `docs/이야기_전개_가이드.md` 3.8 · 8장
  void _leaveStory() {
    // 나가기로 마음을 정한 순간 소리부터 멈춥니다 - 화면이 바뀌는 동안에도
    // 이야기가 계속 들리면 안 나가지는 것처럼 보입니다.
    _stopSpeaking();
    // **pop 이 아니라 go 입니다.** 이 화면은 홈 이어하기·이야기 상세에서
    // `context.go` 로 들어와 되돌아갈 화면이 스택에 없습니다 - maybePop 은
    // 조용히 아무 일도 안 하고, 아이는 나가기를 눌러도 그대로 남습니다.
    context.go(AppRoutes.home);
  }

  /// 처음부터 다시하기를 지금 보여 줄 수 있는가.
  ///
  /// 새 세션을 만들려면 **어느 이야기인지**([_storyId])와 **만들 통로**
  /// ([PlayPage.storyRepository])가 둘 다 있어야 합니다. 미리보기처럼 둘 중
  /// 하나라도 없으면 버튼을 아예 감춥니다.
  bool get _canRestart =>
      _storyId != null &&
      widget.storyRepository != null &&
      widget.repository != null;

  /// 멈춤 화면의 "처음부터 다시하기". **여기서는 아직 아무것도 하지
  /// 않습니다** - 확인 카드로 바꿔 한 번 더 묻습니다. 듣던 이야기가 통째로
  /// 사라지는 행동이라, 잘못 눌렀을 때 되돌릴 틈이 있어야 합니다.
  void _requestRestart() {
    setState(() {
      _restartPrompt = true;
      _exitPrompt = false;
      _restartError = null;
    });
  }

  /// 확인 카드의 "네, 처음부터". 듣던 세션을 끝내고 같은 이야기로 새 세션을
  /// 만들어 그 화면으로 갑니다.
  ///
  /// 순서가 중요합니다 - **끝내기가 먼저입니다.** 새 세션부터 만들면 홈의
  /// 이어하기 카드가 방금 버린 세션을 계속 가리킬 수 있습니다(홈은 진행 중
  /// 세션을 하나만 줍니다). 다만 끝내기가 실패했다고 되돌리지는 않습니다 -
  /// 세션이 하나 더 남는 것보다, 아이가 처음부터 다시 못 하는 쪽이 나쁩니다.
  Future<void> _restartStory() async {
    final String? storyId = _storyId;
    final StoryRepository? stories = widget.storyRepository;
    if (storyId == null || stories == null || _restarting) return;
    setState(() {
      _restarting = true;
      _restartError = null;
    });
    // 새 화면이 뜰 때까지 옛 이야기가 계속 들리면 안 됩니다.
    _stopSpeaking();
    try {
      await widget.repository?.stop(widget.sessionId);
    } on Failure {
      // 무시합니다 - 위 주석대로 여기서 멈추지 않습니다.
    }
    try {
      final String sessionId = await stories.startSession(storyId);
      if (!mounted) return;
      // **pop 이 아니라 go 입니다** - [_leaveStory] 와 같은 이유입니다.
      // 전체 장면 수는 같은 이야기라 그대로 실어 보냅니다.
      context.go(AppRoutes.playOf(sessionId, totalScenes: widget.totalScenes));
    } on Failure catch (failure) {
      if (!mounted) return;
      // 멈춘 자리에 그대로 서 있습니다. "계속 듣기"로 돌아가면 듣던 곳부터
      // 이어집니다 - 아직 아무 장면도 갈아엎지 않았습니다.
      setState(() {
        _restarting = false;
        _restartError = failure.message;
      });
    }
  }

  /// 멈춤 화면에 지금 띄울 카드. 전개 화면과 대화 화면이 **같은 카드**를
  /// 쓰므로 고르는 곳도 한 군데입니다. 확인을 묻는 카드가 늘 위에 옵니다.
  Widget _pauseCard({required VoidCallback onResume}) {
    if (_restartPrompt) {
      return _PauseOverlay.restart(
        onResume: onResume,
        onConfirm: () => unawaited(_restartStory()),
        busy: _restarting,
        errorText: _restartError,
      );
    }
    if (_exitPrompt) {
      return _PauseOverlay.exit(onResume: onResume, onExit: _leaveStory);
    }
    return _PauseOverlay(
      onResume: onResume,
      onExit: _leaveStory,
      onRestart: _canRestart ? _requestRestart : null,
    );
  }

  /// 지금 나오고 있는 말과 예약된 다음 문장을 모두 끊습니다.
  void _stopSpeaking() {
    _speechToken++;
    // 말하기 표시를 여기서 직접 내린다. 재생 루프의 finally 는
    // `if (token == _speechToken)` 로 리셋을 막는데(새 재생이 세운 값을 옛
    // 재생이 덮으면 안 되니까), 방금 토큰을 올렸으니 그 리셋이 건너뛰어진다 -
    // 안 내리면 _speaking 이 true 로 박제되어 맞장구(_playFiller)가 그 뒤로
    // 계속 무음이 된다(실사고: TTS 503 으로 자막이 타이머로 기어가는 동안
    // 마이크를 눌러 끊으면 매 턴 재현됐다).
    //
    // _guideSpeaking(_speakGuide)과 _playingChoiceId(_playChoiceCard)도 같은
    // 무늬다 - 재생 뒤의 리셋이 토큰 비교 뒤에 있어, 끊기면 건너뛰어진다.
    // 셋 다 맞장구의 가드라 하나만 박제돼도 맞장구가 죽는다.
    _speaking = false;
    _guideSpeaking = false;
    _playingChoiceId = null;
    _cancelTimingFollow();
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
          onExit: _requestExit,
          onPause: _toggleStoryPause,
          pauseOverlay: _pauseCard(onResume: _toggleStoryPause),
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
              _SceneBackdrop(
                // 제작한 장면 배경이 있으면 그것이 우선이다. 서버 imageUrl은 배경과 캐릭터가
                // 합쳐진 한 장이라 캐릭터를 따로 얹으면 인물이 둘로 보인다.
                imageAsset:
                    _character?.scene.backgroundAsset ??
                    _retainedStoryImageUrl ??
                    dialogueScene?.imageUrl ??
                    widget.backgroundAsset,
                // 같은 이유로 캐릭터 무대가 떠 있으면 장면 영상도 틀지 않는다 -
                // 서버 영상은 캐릭터가 구워져 들어간 한 장이라 표정 무대와 겹치면
                // 인물이 둘이 된다. 무대가 없는 폴백 화면에서만 영상을 얹는다.
                videoUrl: _character == null ? dialogueScene?.videoUrl : null,
                loop: true,
              ),
              const DialogueBackdropShade(),
              SafeArea(
                minimum: EdgeInsets.all(compact ? 12 : 22),
                child: Column(
                  children: <Widget>[
                    _StoryControls(
                      isPaused: _phase == DialoguePhase.paused,
                      soundOn: _soundOn,
                      sceneOrder: dialogueScene?.sceneOrder,
                      totalScenes: widget.totalScenes,
                      onExit: _requestExit,
                      onPause: _togglePause,
                      onReplay: _playQuestion,
                      onSound: _toggleSound,
                    ),
                    Expanded(
                      child: DialogueCanvas(
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
                        // 담기 통로가 있으면 고정/동적 대사 모두 단어를
                        // 누를 수 있습니다. 동적 대사의 오인식 단어는 서버
                        // 유효성 관문(422 INVALID_WORD)이 걸러 줍니다.
                        onWordTap: widget.wordCapture != null
                            ? _onDialogueWordTap
                            : null,
                        pendingWord: _pendingWord,
                        savingWord: _savingWord,
                        wordNotice: _wordNotice,
                        onConfirmWord: _confirmWordSave,
                        onCancelWord: _cancelWordSave,
                      ),
                    ),
                  ],
                ),
              ),
              if (_phase == DialoguePhase.paused)
                _pauseCard(onResume: _togglePause),
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
              // 맨 위에 얹어 화면을 **불투명하게** 덮습니다. 이야기가 끝난
              // 뒤에는 아래의 어떤 것도 더 누를 것이 없고, 아래에 남은 말들은
              // (직전 대사·"질문이 끝나면 마이크가 켜져요") 전부 지난 이야기라
              // 비쳐 보이면 지금 화면과 충돌합니다.
              if (_handingOffToRecap)
                _RecapHandoffScreen(
                  character: _character,
                  characterAsset: widget.characterAsset,
                  characterName:
                      dialogueScene?.characterName ?? widget.characterName,
                  onStart: _goToRecap,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 한 번에 들려주는 대사 한 덩어리. **글자·소리·실측 구간은 한 묶음입니다** -
/// 셋 중 하나만 따로 들고 다니면 다시 듣기가 다른 소리를 냅니다.
/// → [_PlayPageState._lastSpoken]
class _SpokenMessage {
  const _SpokenMessage({
    required this.text,
    required this.audioUrl,
    required this.audioTimings,
  });

  final String text;

  /// 서버가 미리 렌더해 둔 음성. null 이면 실시간 합성으로 들려준 대사입니다.
  final String? audioUrl;

  /// 사전 렌더 음성의 문장별 실측 구간. 이것이 비면 파일 재생 경로를 못 타고
  /// 문장마다 다시 합성됩니다 - 다시 듣기에서 목소리가 바뀌던 원인입니다.
  final List<PlayAudioTiming> audioTimings;
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
    required this.pauseOverlay,
    required this.onReplay,
    required this.onSound,
  });

  final PlayScene scene;
  final int narrationIndex;
  final bool isPaused;
  final bool isAdvancing;
  final bool soundOn;
  final int? totalScenes;

  /// 상단 X. 멈춤 화면을 띄웁니다.
  final VoidCallback onExit;
  final VoidCallback onPause;

  /// 멈춰 있을 때 덮는 카드. 어떤 카드인지는 화면을 여는 쪽이 고릅니다
  /// (멈춤 · 나가기 확인 · 처음부터 확인) → [_PlayPageState._pauseCard]
  final Widget pauseOverlay;
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
          _SceneBackdrop(
            imageAsset: scene.imageUrl,
            videoUrl: scene.videoUrl,
            loop: true,
          ),
          const DialogueBackdropShade(),
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
          if (isPaused) pauseOverlay,
        ],
      ),
    );
  }
}

/// 장면 배경 한 층. [videoUrl]이 없으면 지금처럼 이미지 한 장이고, 있으면
/// 이미지를 밑에 깐 채 영상이 준비된 뒤에만 위에 얹는다 - 초기화 전·초기화
/// 실패·재생 오류 어느 경우든 밑의 이미지가 그대로 보여서 흰 화면이나
/// 깜빡임 없이 기존 배경으로 떨어진다.
/// → 팀원공유 `전달_장면영상과_추가요청.md` §1·§2-1
class _SceneBackdrop extends StatelessWidget {
  const _SceneBackdrop({this.imageAsset, this.videoUrl, this.loop = false});

  final String? imageAsset;
  final String? videoUrl;

  /// 장면 영상은 전부 반복 재생한다. 처음에는 STORY를 1회 재생 후 정지로
  /// 설계했으나, 멈춘 화면이 "영상이 끝났다/고장났다"로 읽혀 전 장면 반복으로
  /// 확정했다(2026-08-16 팀 결정). 5초 단일본 클립은 반복 시 이음매가 보일 수
  /// 있는데, 그건 프론트가 아니라 루프본 에셋(_loop)으로 푼다.
  final bool loop;

  @override
  Widget build(BuildContext context) {
    final String? url = videoUrl;
    if (url == null || url.isEmpty) {
      return DialogueBackdrop(asset: imageAsset);
    }
    return _SceneVideoBackdrop(
      videoUrl: url,
      loop: loop,
      imageAsset: imageAsset,
    );
  }
}

class _SceneVideoBackdrop extends StatefulWidget {
  const _SceneVideoBackdrop({
    required this.videoUrl,
    required this.loop,
    this.imageAsset,
  });

  final String videoUrl;
  final bool loop;
  final String? imageAsset;

  @override
  State<_SceneVideoBackdrop> createState() => _SceneVideoBackdropState();
}

class _SceneVideoBackdropState extends State<_SceneVideoBackdrop> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_SceneVideoBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      // 장면 전환 - 이전 장면 컨트롤러를 정리하고 새로 만든다.
      _disposeController();
      setState(_start);
    } else if (oldWidget.loop != widget.loop) {
      unawaited(_controller?.setLooping(widget.loop));
    }
  }

  /// 서버가 `/stories/...` 상대경로를 주므로 API base의 origin에 붙인다.
  /// base가 `/api`로 끝나도 절대경로 resolve는 path를 통째로 바꾸므로
  /// `/api`가 앞에 남지 않는다(이미지 배경과 같은 규칙).
  Uri? get _resolvedUri {
    final String raw = widget.videoUrl.startsWith('/')
        ? Uri.parse(AppConfig.apiBaseUrl).resolve(widget.videoUrl).toString()
        : widget.videoUrl;
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  void _start() {
    _ready = false;
    final Uri? uri = _resolvedUri;
    if (uri == null) return; // 이해할 수 없는 주소 - 이미지로만 간다.
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      uri,
    );
    _controller = controller;
    controller.addListener(_onControllerChanged);
    unawaited(
      controller
          .initialize()
          .then((_) async {
            if (!mounted || _controller != controller) return;
            // 영상 자체가 무음이지만(나레이션은 scene_audio가 따로 맡는다)
            // 웹 자동재생 정책이 음소거를 요구하므로 명시해 둔다.
            await controller.setVolume(0);
            await controller.setLooping(widget.loop);
            await controller.play();
            if (!mounted || _controller != controller) return;
            setState(() => _ready = true);
          })
          .catchError((Object _) {
            // 초기화·자동재생 실패 - _ready가 false로 남아 이미지가 보인다.
            if (!mounted || _controller != controller) return;
            setState(() => _ready = false);
          }),
    );
  }

  void _onControllerChanged() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !mounted) return;
    // 재생 도중 오류가 나면 영상 층을 내리고 이미지로 돌아간다.
    if (controller.value.hasError && _ready) {
      setState(() => _ready = false);
    }
  }

  void _disposeController() {
    final VideoPlayerController? controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      unawaited(controller.dispose());
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    final bool showVideo =
        _ready &&
        controller != null &&
        controller.value.isInitialized &&
        !controller.value.hasError &&
        controller.value.size.width > 0 &&
        controller.value.size.height > 0;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DialogueBackdrop(asset: widget.imageAsset),
        if (showVideo)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
      ],
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
        DialogueControlButton(
          label: '나가기',
          icon: AppIcons.close,
          onPressed: onExit,
        ),
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
        DialogueControlButton(
          label: '다시 듣기',
          icon: AppIcons.replay,
          onPressed: onReplay,
        ),
        const SizedBox(width: 8),
        DialogueControlButton(
          label: soundOn ? '소리 끄기' : '소리 켜기',
          icon: soundOn ? AppIcons.soundOn : AppIcons.soundOff,
          onPressed: onSound,
        ),
        const SizedBox(width: 8),
        DialogueControlButton(
          label: isPaused ? '계속 듣기' : '잠시 멈춤',
          icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          onPressed: onPause,
          emphasized: true,
        ),
      ],
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
              DialogueBackdrop(asset: asset)
            else
              const DialogueBackdropFallback(),
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
  final DialoguePhase phase;
  final int seconds;
  final bool recording;
  final bool transcribing;
  final bool submitting;
  final VoidCallback? onMicTap;
  final String? lastChildText;
  final bool lastSttLowConfidence;
  final bool compact;

  bool get listening => phase == DialoguePhase.listening;

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

  final DialoguePhase phase;
  final int seconds;
  final bool recording;
  final bool transcribing;
  final VoidCallback? onMicTap;
  final bool submitting;
  final bool compact;

  bool get listening => phase == DialoguePhase.listening;

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
            DialogueMicButton(
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

/// 이야기를 멈춰 세운 카드. **멈춤 버튼·나가기(X)·처음부터 다시하기가 같은
/// 카드를 씁니다** - 생김새가 다른 창을 하나 더 두면 아이가 방금 본 화면과 왜
/// 다른지부터 헷갈립니다. 다른 것은 묻는 말과 버튼 이름뿐입니다.
class _PauseOverlay extends StatelessWidget {
  /// 멈춤 버튼으로 뜬 카드. [onRestart] 가 있으면 "처음부터 다시하기"가 한 줄
  /// 더 붙습니다 - 어느 이야기인지 모르는 화면(미리보기)에서는 없습니다.
  const _PauseOverlay({
    required this.onResume,
    required VoidCallback onExit,
    this.onRestart,
  }) : icon = Icons.pause_circle_rounded,
       title = '이야기를 잠시 멈췄어요',
       message = null,
       resumeLabel = '계속 듣기',
       confirmLabel = '이야기 나가기',
       onConfirm = onExit,
       busy = false,
       errorText = null;

  /// 나가기(X)로 뜬 변형. 이야기를 멈춰 두는 것은 같고 **나갈지 묻습니다.**
  /// 듣던 자리가 남는다는 것을 함께 말해 줍니다 - 겁주는 문구로 나가기를
  /// 막지 않되, 잘못 눌렀을 때 되돌릴 틈은 있어야 합니다.
  const _PauseOverlay.exit({
    required this.onResume,
    required VoidCallback onExit,
  }) : icon = Icons.pause_circle_rounded,
       title = '이야기에서 나갈까요?',
       message = '여기까지 들은 곳을 기억해 둘게요. 홈에서 이어 들을 수 있어요.',
       resumeLabel = '계속 듣기',
       confirmLabel = '나가기',
       onConfirm = onExit,
       onRestart = null,
       busy = false,
       errorText = null;

  /// "처음부터 다시하기"를 누른 뒤 한 번 더 묻는 변형.
  ///
  /// **여기만 되돌릴 수 없습니다** - 듣던 세션이 끝나고 첫 장면부터 새로
  /// 시작합니다. 그래서 큰 버튼은 안전한 쪽("계속 들을래요")에 두고, 처음부터
  /// 가는 길은 아래 작은 버튼에 둡니다. 잃는 것을 말로도 한 줄 알려 줍니다.
  const _PauseOverlay.restart({
    required this.onResume,
    required this.onConfirm,
    required this.busy,
    required this.errorText,
  }) : icon = Icons.replay_circle_filled_rounded,
       title = '처음부터 다시 할까요?',
       message = '지금까지 들은 이야기는 사라지고, 첫 장면부터 새로 시작해요.',
       resumeLabel = '아니요, 계속 들을래요',
       confirmLabel = '네, 처음부터',
       onRestart = null;

  final IconData icon;
  final String title;

  /// 제목 아래 한 줄. 멈춤에는 없습니다 - 멈춘 것만으로는 덧붙일 말이 없습니다.
  final String? message;

  /// 큰 버튼. **늘 이야기로 돌아가는 쪽입니다** - 아무 생각 없이 큰 버튼을
  /// 눌러도 잃는 것이 없어야 합니다.
  final String resumeLabel;
  final VoidCallback onResume;

  /// 아래 작은 버튼(나가기 · 네, 처음부터).
  final String confirmLabel;
  final VoidCallback onConfirm;

  /// 가운데 한 줄로 붙는 "처음부터 다시하기". null 이면 안 그립니다.
  final VoidCallback? onRestart;

  /// 처음부터 다시하기를 처리하는 중. 버튼을 잠그고 기다린다고 말해 줍니다 -
  /// 세션을 끝내고 새로 만드는 사이에 두 번 눌리면 세션이 두 개 생깁니다.
  final bool busy;

  /// 실패했을 때 버튼 위에 뜨는 한 줄.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xD10C1C2F),
      child: Center(
        // 카드 폭을 여기서 묶어 둡니다. 버튼 테마가
        // `minimumSize: Size.fromHeight(...)` 라 폭을 무한대로 요구해서,
        // 상자를 안 씌우면 카드가 화면 폭을 전부 차지합니다.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, color: const Color(0xFF4B8EC2), size: 48),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (message != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF5A6B7C),
                      ),
                    ),
                  ],
                  if (errorText != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC2453F),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: busy ? null : onResume,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(resumeLabel),
                  ),
                  if (onRestart != null) ...<Widget>[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.replay_rounded, size: 20),
                      label: const Text('처음부터 다시하기'),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: busy ? null : onConfirm,
                    child: busy
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('처음부터 준비하고 있어요…'),
                            ],
                          )
                        : Text(confirmLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 말하기가 끝나고 "말하기 후 활동"으로 넘어가기 직전에 한 번 끼는 전환 화면.
///
/// **뒤가 비치지 않는 한 장의 화면입니다.** 대화 화면 위에 반투명 막을 덮던
/// 예전 방식은 아래 셋이 그대로 읽혀서 못 씁니다.
///
/// 1. 직전 캐릭터 대사("이럴 때는 어떻게 하면 좋을까?")가 새 말풍선 바로 위에
///    겹쳐 남아, 지금 누가 무슨 말을 하는지 헷갈립니다.
/// 2. 하단 마이크 패널이 "질문이 끝나면 마이크가 켜져요"라고 말합니다 —
///    이야기가 이미 끝난 시점이라 사실이 아닙니다.
/// 3. 상단 컨트롤(닫기·되감기·소리·일시정지)이 밝게 살아 있는데 막이 탭을
///    먹어서 눌러도 반응하지 않습니다.
///
/// 바탕은 [AppCanvas.day] 입니다 — 다음 화면(`play_recap_view.dart`)과 같은
/// 바탕이라, 이 화면이 활동의 표지처럼 이어집니다.
///
/// ## 이 화면이 하지 않는 것
///
/// - **소리를 내지 않습니다.** 지금은 글자로만 보여 줍니다.
/// - **숨은 탭 영역을 두지 않습니다.** 넘어가는 길은 `시작` 버튼과 시계
///   둘뿐입니다. 화면 아무 데나 눌러 넘어가던 예전 방식은 누를 자리가 눈에
///   보이지 않아 아이가 화면을 더듬게 만들었습니다.
/// - **확인 관문을 세우지 않습니다.** 버튼을 안 눌러도 [_recapHandoffDelay]
///   뒤에 저절로 넘어갑니다 — 글을 못 읽는 아이 앞에서 이야기가 멈추면 안 됩니다.
/// - **다음 활동의 내용은 한 글자도 비추지 않습니다.** 바로 다음이 장면 그림을
///   이야기 순서대로 놓는 활동이라, 장면 그림·제목·낱말이 여기 새어 나오면
///   그게 곧 정답입니다. (`play_recap_view.dart` 의 `RecapSceneCard.title`)
class _RecapHandoffScreen extends StatelessWidget {
  const _RecapHandoffScreen({
    required this.character,
    required this.characterAsset,
    required this.characterName,
    required this.onStart,
  });

  /// 방금까지 말을 걸던 캐릭터. 표정 에셋이 있는 장면에서만 값이 있습니다.
  /// 화면이 바뀌어도 같은 친구가 이어서 말한다는 걸 이 그림 하나가 지탱합니다.
  final DialogueCharacterStateMachine? character;

  /// [character] 가 없는 장면에서 쓰는 캐릭터 한 장.
  final String? characterAsset;
  final String characterName;

  /// `시작` 버튼. 시계가 먼저 다 되면 화면 밖에서 같은 곳으로 갑니다.
  final VoidCallback onStart;

  /// 넓은 화면에서 캐릭터가 가져가는 가로 몫. 스케치의 "세로로 긴 자리"입니다.
  ///
  /// 남은 폭을 말풍선에 다 주지 않습니다 - 한 줄짜리 말풍선은 제 글만큼만
  /// 넓어져서, 남는 폭이 전부 오른쪽 여백으로 몰리면 인물만 왼쪽 구석에
  /// 붙어 보입니다. 대신 인물과 말을 한 덩어리로 묶어 가운데에 놓습니다.
  ///
  /// 태블릿(1280×720)에서 이 값이면 인물이 세로를 거의 다 씁니다. 더 키우면
  /// 세로가 먼저 차서 그림이 가운데로 오그라들고, 그만큼 좌우 투명 여백이
  /// 늘어나 [_characterArtInset] 이 도로 어긋납니다.
  static const double _characterWidthFactor = .32;

  /// 캐릭터 그림 좌우에 들어 있는 **투명 여백**의 몫.
  ///
  /// 대화 캐릭터 에셋은 1200×1600 프레임 한가운데에 인물을 세워 둔 그림이라
  /// 좌우 20% 안팎이 빈 픽셀입니다. [BoxFit.contain] 은 그 빈 픽셀까지 그림으로
  /// 치기 때문에, 캐릭터 자리의 폭을 그대로 두면 말풍선이 **보이지도 않는
  /// 여백만큼** 밀려나 인물과 145px 가까이 벌어집니다 - 그러면 꼬리가 허공을
  /// 가리켜서 누가 하는 말인지 읽히지 않습니다.
  ///
  /// 그래서 **자리 폭에서는 이 몫을 빼고, 그림은 원래 폭 그대로** 그립니다.
  /// 넘치는 쪽은 어차피 투명이라 말풍선을 가리지 않습니다.
  static const double _characterArtInset = .22;

  /// 이 아래로는 "세로가 짧은 화면"입니다. 폰 가로(390 안팎)가 여기 들어옵니다.
  ///
  /// 짧으면 두 가지가 달라집니다.
  /// - **캐릭터를 뺍니다.** 제목·말풍선·버튼 셋은 이 화면의 뜻 그 자체라
  ///   무엇도 접을 수 없고, 넷을 다 욱여넣으면 잘립니다.
  /// - **간격을 [AppSpacing.md] 로 좁힙니다.** [ScreenMetrics.sectionGap] 은
  ///   태블릿 세로를 기준으로 한 값이라, 그대로 쓰면 `시작` 버튼이 화면 밖으로
  ///   밀려납니다.
  static const double _shortHeight = 460;

  /// 등장 순서 — 제목 → 인물 → 말(+버튼). 한 번씩만 들어오고 그 뒤로는
  /// 잔잔합니다. **4.5초 만에 사라지는 화면**이라 계속 움직이는 장식을 깔면
  /// 아이가 볼 것을 고르지 못하고 피곤해집니다.
  static const Duration _characterDelay = Duration(milliseconds: 140);
  static const Duration _speechDelay = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: respect(context, AppDurations.normal),
      curve: AppCurves.standard,
      builder: (BuildContext context, double t, Widget? child) =>
          Opacity(opacity: t, child: child),
      // 이 화면은 대화 화면 **위에** 얹힙니다. 색만 칠하면 빈 자리를 누를 때
      // 아래에 그대로 남아 있는 마이크·닫기 버튼이 눌립니다 - 보이지도 않는
      // 버튼이 반응하지 않도록 여기서 포인터를 끊습니다.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: AppCanvas.day(
          child: Stack(
            children: <Widget>[
              // 낮 바탕에 깊이를 더하는 장식. 홈의 `HomeBackdrop` 과 같은
              // 어휘(빛·말풍선 모티프·낮은 언덕)를 쓰되, 여기서는 인물과 말이
              // 주인공이라 한 단계 더 옅게 깝니다.
              const Positioned.fill(child: _HandoffBackdrop()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final ScreenMetrics metrics = ScreenMetrics.of(
                      constraints.maxWidth,
                    );
                    final bool short = constraints.maxHeight < _shortHeight;
                    final bool hasCharacter =
                        (character != null || characterAsset != null) && !short;
                    final double gap = short
                        ? AppSpacing.md
                        : metrics.sectionGap;
                    return _body(
                      context,
                      metrics,
                      gap,
                      hasCharacter,
                      constraints.maxWidth,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 제목 → 본문. 폭에 따라 본문만 갈아 끼웁니다.
  Widget _body(
    BuildContext context,
    ScreenMetrics metrics,
    double gap,
    bool hasCharacter,
    double maxWidth,
  ) {
    return Semantics(
      container: true,
      liveRegion: true,
      // 제목과 한마디를 한 번에 읽어 줍니다. 아래에서 두 글을
      // [ExcludeSemantics] 로 덮었으므로 두 번 읽히지 않습니다.
      label: '${PlayStrings.toRecapTitle}. ${PlayStrings.toRecap}',
      // `시작` 버튼은 제 노드를 그대로 갖습니다 — 이 화면에서 유일하게
      // 누를 수 있는 것이라 라벨 안에 묻으면 안 됩니다.
      explicitChildNodes: true,
      child: Padding(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: Column(
          children: <Widget>[
            // 제목은 맨 먼저, 위에서 살짝 내려앉습니다.
            _Appear(
              delay: Duration.zero,
              rise: -AppSpacing.md,
              child: ExcludeSemantics(
                child: _HandoffTitleBadge(metrics: metrics),
              ),
            ),
            SizedBox(height: gap),
            Expanded(
              child: metrics.isWide
                  ? _wideBody(context, metrics, hasCharacter, maxWidth)
                  : _narrowBody(context, metrics, hasCharacter),
            ),
          ],
        ),
      ),
    );
  }

  /// 가로 화면 — 캐릭터는 왼쪽에 서고, 말풍선과 버튼은 오른쪽에 쌓입니다.
  /// 대화 화면과 같은 구도라 아이가 화면이 바뀐 것을 "자리 이동"으로 읽습니다.
  Widget _wideBody(
    BuildContext context,
    ScreenMetrics metrics,
    bool hasCharacter,
    double maxWidth,
  ) {
    final double characterWidth = maxWidth * _characterWidthFactor;
    // 말풍선 자리에 남는 폭. 말풍선이 제 최대 폭까지 커져도 남을 만큼
    // 넉넉할 때만 가로 제약을 풀어 줍니다 - 빠듯한 폭에서 풀면 말풍선이
    // 줄바꿈을 못 하고 화면 밖으로 삐져나갑니다.
    final double speechWidth =
        maxWidth -
        metrics.screenPadding * 2 -
        (hasCharacter
            ? characterWidth * (1 - _characterArtInset) + AppSpacing.sm
            : 0);
    return Row(
      // 인물과 말이 한 덩어리로 가운데에 모여야 한 장면으로 읽힙니다.
      mainAxisAlignment: MainAxisAlignment.center,
      // 캐릭터는 바닥에 서야 하므로 세로를 다 씁니다. 말풍선 쪽은 자기 Column
      // 안에서 가운데로 모입니다.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasCharacter) ...<Widget>[
          _Appear(
            delay: _characterDelay,
            child: SizedBox(
              // 자리는 투명 여백을 뺀 폭만 차지하고([_characterArtInset]),
              // 그림은 원래 폭으로 그립니다. 넘치는 오른쪽은 투명이라
              // 말풍선을 가리지 않으면서 그만큼 말이 인물 쪽으로 붙습니다.
              width: characterWidth * (1 - _characterArtInset),
              child: OverflowBox(
                alignment: Alignment.bottomLeft,
                minWidth: characterWidth,
                maxWidth: characterWidth,
                child: _character(),
              ),
            ),
          ),
          // 인물 바로 옆에서 말이 시작되어야 꼬리가 인물을 가리킵니다.
          const SizedBox(width: AppSpacing.sm),
        ],
        // 말풍선이 제 글만큼만 차지하도록 [Flexible] 입니다 - [Expanded] 로
        // 남은 폭을 다 주면 그 폭이 오른쪽 여백이 되어 버립니다.
        Flexible(
          child: _speech(
            context,
            metrics,
            shrinkWrap: speechWidth >= AppSizes.bubbleMaxWidth,
          ),
        ),
      ],
    );
  }

  /// 폰 세로 — 좌우로 놓을 폭이 없으므로 위에서 아래로 쌓습니다.
  /// 캐릭터 → 말풍선 → 버튼 순서는 "누가 말했나 → 무슨 말인가 → 뭘 하나"입니다.
  Widget _narrowBody(
    BuildContext context,
    ScreenMetrics metrics,
    bool hasCharacter,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (hasCharacter) ...<Widget>[
          // 남은 세로만 가져갑니다 - 말풍선과 버튼이 먼저 자리를 잡습니다.
          Flexible(
            child: _Appear(delay: _characterDelay, child: _character()),
          ),
          // 인물과 말 사이는 [AppSpacing.md] 만 둡니다. 여기서 섹션 간격만큼
          // 벌리면 말이 인물이 아니라 버튼에 붙어 보입니다.
          const SizedBox(height: AppSpacing.md),
        ],
        // 좁은 화면의 말풍선은 폭을 꽉 채우고 줄바꿈으로 버팁니다.
        _speech(context, metrics, shrinkWrap: false),
      ],
    );
  }

  /// 캐릭터 + 인물 뒤의 광 + 발밑 그림자.
  ///
  /// 그림 한 장만 놓으면 파스텔 바탕 위에 인물이 오려 붙인 것처럼 떠 보입니다.
  /// 뒤에 옅은 광을 깔고 발밑에 그림자를 두면 같은 그림이 **바닥에 선** 것으로
  /// 읽힙니다.
  Widget _character() {
    final DialogueCharacterStateMachine? machine = character;
    final Widget art = machine != null
        ? ExcludeSemantics(
            child: DialogueCharacterStage(
              scene: machine.scene,
              state: machine.current,
              // 방금 이 한마디를 한 참입니다. 말하는 모션을 그대로 이어 갑니다.
              activity: DialogueActivity.speaking,
            ),
          )
        : Semantics(
            image: true,
            label: '$characterName 캐릭터',
            child: Image.asset(
              characterAsset!,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          );
    return CustomPaint(painter: const _CharacterStandPainter(), child: art);
  }

  /// 말풍선 + `시작` 버튼. 둘은 한 덩어리로 등장합니다 — 말을 먼저 띄우고
  /// 버튼을 나중에 얹으면, 버튼이 뜨기 전에 누르려던 손이 허공을 짚습니다.
  Widget _speech(
    BuildContext context,
    ScreenMetrics metrics, {
    required bool shrinkWrap,
  }) {
    return _Appear(
      delay: _speechDelay,
      // 차례가 바뀌는 순간이라 [AppDurations.turn] 입니다. 아이가 "어, 뭔가
      // 바뀌었네"를 알아채야 하는 변화는 일부러 느리게 둡니다.
      duration: AppDurations.turn,
      scaleFrom: .92,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.bubbleMaxWidth),
        // 폭이 넉넉하면 **말풍선이 제 글만큼만** 넓어지게 두고, 그 폭을
        // 덩어리 전체의 폭으로 삼습니다. 남은 폭까지 덩어리로 치면 버튼이
        // 말풍선이 아니라 빈 여백까지 포함한 가운데에 서서 말과 따로 놉니다.
        child: _maybeShrinkWrap(
          shrinkWrap,
          Column(
            // 넓은 화면에서는 세로가 꽉 차게 들어오므로(캐릭터가 바닥에 서야
            // 해서 행 전체가 늘어납니다) 가운데로 모읍니다. 좁은 화면에서는
            // 제 높이만큼만 차지하고 이 정렬은 아무 일도 하지 않습니다.
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: KidSpeechBubble(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.isWide ? AppSpacing.xl : AppSpacing.lg,
                    vertical: metrics.isWide ? AppSpacing.lg : AppSpacing.md,
                  ),
                  child: Text(
                    PlayStrings.toRecap,
                    style: metrics.text(AppTypography.kidBody),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              KidPrimaryButton(
                icon: AppIcons.play,
                label: PlayStrings.toRecapStart,
                labelStyle: metrics.text(AppTypography.kidButton),
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [shrink] 이면 가로 제약을 풀어 내용 폭에 맞춥니다.
  ///
  /// [IntrinsicWidth] 를 쓰지 않는 이유가 있습니다 — 웹(CanvasKit)에서 한글
  /// 문장의 최대 고유 폭이 실제 한 줄 폭보다 작게 나와, 말풍선이 제풀에
  /// 좁아지며 글이 석 줄로 접혔습니다.
  Widget _maybeShrinkWrap(bool shrink, Widget child) => shrink
      ? UnconstrainedBox(constrainedAxis: Axis.vertical, child: child)
      : child;
}

/// 전환 화면의 제목 받침.
///
/// 맨 위에 글자만 덩그러니 놓으면 화면 위쪽 1/3이 통째로 빕니다. 다음 화면
/// (`play_recap_view.dart`)의 단계 칩과 **같은 어휘**(흰 면 · [AppRadius.pill] ·
/// [AppShadows] · [AppColors.brandBlueDeep] 아이콘)를 써서, 이 화면이 그 활동의
/// 표지처럼 이어지게 합니다.
///
/// 글자는 새로 붙이지 않습니다 — 아이콘은 제목 옆의 그림일 뿐이고, 읽어야 할
/// 것은 여전히 `말하기 후 활동` 하나입니다.
class _HandoffTitleBadge extends StatelessWidget {
  const _HandoffTitleBadge({required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.lift,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            AppIcons.characterSpeaking,
            size: AppSizes.iconChild,
            color: AppColors.brandBlueDeep,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              PlayStrings.toRecapTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metrics.text(AppTypography.kidTitle),
            ),
          ),
        ],
      ),
    );
  }
}

/// 등장 순서를 만드는 도우미. 뜰 때 한 번만 재생하고 그대로 멈춥니다.
///
/// **4.5초 만에 사라지는 화면**이라 무한 반복 애니메이션을 깔지 않습니다.
/// 계속 움직이는 장식이 있으면 아이의 눈이 캐릭터가 아니라 장식을 따라갑니다.
/// (`docs/DESIGN_SYSTEM.md` 1장 — "캐릭터가 아닌 곳에서의 과한 애니메이션")
class _Appear extends StatelessWidget {
  const _Appear({
    required this.delay,
    required this.child,
    this.duration = AppDurations.normal,
    this.rise = AppSpacing.md,
    this.scaleFrom = 1,
  });

  /// 화면이 뜨고 이만큼 기다렸다 들어옵니다.
  final Duration delay;

  final Duration duration;

  /// 들어오면서 밀려 올라오는 거리. 음수면 위에서 내려앉습니다.
  final double rise;

  /// 시작 크기. 1이면 크기 변화 없이 밀려 올라오기만 합니다.
  final double scaleFrom;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Duration total = delay + duration;
    // 지연을 곡선의 앞부분으로 표현합니다 - 화면이 4.5초 만에 사라지므로
    // 타이머를 하나 더 들고 있을 이유가 없습니다.
    final double start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      // 모션 줄이기 설정에서는 0이 되어 그냥 제자리에 놓입니다.
      duration: respect(context, total),
      curve: Interval(start, 1, curve: AppCurves.playful),
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          // playful(easeOutBack)은 1을 잠깐 넘겼다 돌아옵니다. 크기·이동은 그
          // 튐이 살아야 장난감처럼 보이고, 투명도는 넘치면 안 됩니다.
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, rise * (1 - t)),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 인물 뒤의 광과 발밑 그림자.
///
/// 노란빛(별가루)은 쓰지 않습니다 — 이 앱에서 따뜻한 색은 보상 전용입니다.
/// 광은 [AppColors.brandMint], 그림자는 [AppColors.ink900] 을 옅게 깐 것으로
/// [AppShadows] 와 같은 톤을 유지합니다.
class _CharacterStandPainter extends CustomPainter {
  const _CharacterStandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 인물의 상반신 뒤에 둡니다. 배 높이에 두면 불투명한 몸에 다 가려서
    // 아무것도 보이지 않습니다.
    final Offset center = Offset(size.width * .5, size.height * .38);
    final double radius = size.width * .55;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.brandMint.withValues(alpha: .5),
            AppColors.brandMint.withValues(alpha: 0),
          ],
          stops: const <double>[.18, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 발밑 그림자. 그림 아래쪽 3~4%는 투명 여백이라 바닥에서 살짝 띄웁니다.
    // **인물보다 넓게** 깝니다 - 딱 맞게 그리면 치마에 다 가려서 안 보입니다.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .955),
        width: size.width * .78,
        height: size.width * .13,
      ),
      Paint()
        ..color = AppColors.ink900.withValues(alpha: .13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(_CharacterStandPainter oldDelegate) => false;
}

/// 전환 화면의 바탕 장식.
///
/// 홈의 `HomeBackdrop` 과 **같은 어휘**입니다 — 빛, 흰 구름, 이 앱의 서명인
/// 말풍선 모티프, 바닥의 낮은 언덕. 다만 여기서는 두 가지가 다릅니다.
///
/// - **더 옅습니다.** 홈은 오래 머무는 화면이라 또렷해도 되지만, 여기서는
///   4.5초 동안 인물과 한마디에 눈이 가야 합니다.
/// - **다음 활동을 한 조각도 그리지 않습니다.** 장면 그림 비슷한 것을 깔면
///   그게 곧 다음 활동(장면 순서 맞추기)의 정답입니다. 그래서 뜻이 없는
///   순수 도형만 씁니다.
///
/// 순수 장식이라 [IgnorePointer] 로 터치를 통과시키고, [RepaintBoundary] 로
/// 본문과 리페인트를 분리합니다. **정적입니다(모션 없음).**
class _HandoffBackdrop extends StatelessWidget {
  const _HandoffBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _HandoffBackdropPainter(),
        ),
      ),
    );
  }
}

class _HandoffBackdropPainter extends CustomPainter {
  const _HandoffBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    _paintLightGlow(canvas, w, h);
    _paintClouds(canvas, w, h);
    _paintBubbleMotifs(canvas, w, h);
    _paintHills(canvas, w, h);
  }

  /// 좌상단 민트 햇살 + 우상단 옅은 파랑. 비어 보이던 화면 위쪽 1/3을
  /// 색으로 채웁니다.
  void _paintLightGlow(Canvas canvas, double w, double h) {
    final Rect full = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      full,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                AppColors.brandMint.withValues(alpha: .38),
                AppColors.brandMint.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * .10, -h * .10),
                radius: w * .58,
              ),
            ),
    );
    canvas.drawRect(
      full,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                AppColors.brandBlue.withValues(alpha: .24),
                AppColors.brandBlue.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(w * 1.02, 0), radius: w * .46),
            ),
    );
  }

  /// 흰 구름 두 무리. 위쪽 좌우 구석에만 둡니다 - 가운데는 인물과 말의 자리입니다.
  void _paintClouds(Canvas canvas, double w, double h) {
    final Paint cloud = Paint()
      ..color = AppColors.surface.withValues(alpha: .78)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    _cloud(canvas, cloud, Offset(w * .13, h * .17), w * .05);
    _cloud(canvas, cloud, Offset(w * .85, h * .12), w * .042);
  }

  void _cloud(Canvas canvas, Paint paint, Offset c, double r) {
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c.translate(r * 1.1, r * .25), r * .78, paint);
    canvas.drawCircle(c.translate(-r * 1.05, r * .30), r * .70, paint);
    canvas.drawCircle(c.translate(r * .1, r * .55), r * .90, paint);
  }

  /// 이 앱의 서명인 말풍선을 배경에 옅게 반복합니다. 채운 원 + 왼쪽 아래 꼬리로
  /// 로고 Q 와 같은 형태를 암시합니다.
  void _paintBubbleMotifs(Canvas canvas, double w, double h) {
    _bubble(
      canvas,
      Offset(w * .82, h * .70),
      w * .045,
      AppColors.surface.withValues(alpha: .45),
    );
    _bubble(
      canvas,
      Offset(w * .08, h * .58),
      w * .034,
      AppColors.brandBlue.withValues(alpha: .18),
    );
    // 제목 배지 옆은 비워 둡니다 - 배지 바로 옆에 두면 배지에 딸린 표시처럼
    // 보입니다.
    _bubble(
      canvas,
      Offset(w * .92, h * .30),
      w * .026,
      AppColors.brandGreen.withValues(alpha: .22),
    );
  }

  void _bubble(Canvas canvas, Offset c, double r, Color color) {
    final Paint p = Paint()..color = color;
    canvas.drawCircle(c, r, p);
    final Path tail = Path()
      ..moveTo(c.dx - r * .55, c.dy + r * .45)
      ..lineTo(c.dx - r * .95, c.dy + r * 1.05)
      ..lineTo(c.dx - r * .10, c.dy + r * .80)
      ..close();
    canvas.drawPath(tail, p);
  }

  /// 화면 바닥의 낮은 언덕 두 겹. 인물이 딛고 설 땅이 되어 주고, 비어 있던
  /// 오른쪽 아래를 메웁니다.
  void _paintHills(Canvas canvas, double w, double h) {
    final Path back = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * .88)
      ..quadraticBezierTo(w * .30, h * .80, w * .58, h * .875)
      ..quadraticBezierTo(w * .82, h * .94, w, h * .855)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      back,
      Paint()..color = AppColors.brandMint.withValues(alpha: .26),
    );

    final Path front = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * .945)
      ..quadraticBezierTo(w * .34, h * .90, w * .64, h * .95)
      ..quadraticBezierTo(w * .86, h * .99, w, h * .925)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()..color = AppColors.brandGreen.withValues(alpha: .32),
    );
  }

  @override
  bool shouldRepaint(_HandoffBackdropPainter oldDelegate) => false;
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
                  child: DialogueBackdrop(asset: imageUrl),
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
