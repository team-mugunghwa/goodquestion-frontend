import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../play/domain/entities/play_session.dart';
import '../../../play/domain/repositories/play_repository.dart';
import '../../../play/presentation/character/dialogue_character_manifest.dart';
import '../../../play/presentation/character/dialogue_character_state_machine.dart';
import '../../../play/presentation/voice/mission_voice_recorder.dart';
import '../../../play/presentation/voice/story_audio_player.dart';
import '../../../play/presentation/widgets/dialogue_backdrop.dart';
import '../../../play/presentation/widgets/dialogue_canvas.dart';
import '../../domain/entities/free_talk.dart';
import '../../domain/repositories/free_talk_repository.dart';
import '../widgets/free_talk_farewell.dart';

/// 후속 자유 대화 화면.
///
/// ## 학습 대화와 같은 판, 다른 규칙
///
/// 캐릭터 무대 · 말풍선 · 마이크는 [DialogueCanvas] 를 **그대로** 씁니다.
/// 아이 눈에는 같은 친구와 같은 자리에서 말하는 일이라, 화면이 갈리면 규칙을
/// 두 번 배워야 합니다. 대신 이 화면은 학습이 아니므로 아래를 **그리지
/// 않습니다**:
///
/// - 진행바·장면 번호 — 목표가 없으니 어디까지 왔다는 개념이 없습니다.
/// - 사고 요소·미션 — 자유 대화에는 판정이 없습니다.
/// - 남은 턴 수 — 세는 순간 대화가 과제가 됩니다(설계 결정).
/// - 단어 담기 — 단어장은 학습 자산이라 여기서 담게 하지 않습니다.
///
/// ## 끝나는 길은 셋입니다
///
/// 1. 서버가 [FreeTalkTurn.ended] 로 닫습니다. 그 마지막 대사가 곧 작별
///    인사라, 다 읽어 준 뒤 "또 만나자" 화면으로 넘어갑니다.
///    **`end` 를 부르지 않습니다** — 부르면 인사를 두 번 합니다.
/// 2. 아이가 "인사하고 나가기"를 고릅니다. 이때만 `end` 를 불러 인사를 받아
///    옵니다. 말없이 화면을 닫지 않는 이유는, 정 붙은 친구와 인사도 없이
///    헤어지는 경험을 남기지 않으려는 것이 이 기능의 존재 이유이기 때문입니다.
/// 3. 아이가 "바로 나가기"를 고릅니다. `leave` 로 대화를 닫기만 하고 인사
///    없이 곧장 홈으로 갑니다. 2번만 두었더니 나가려는 아이가 낭독이 끝나기를
///    기다려야 했고, 그 몇 초가 그대로 지루함이 됐습니다(2026-08-18 팀
///    피드백). **닫기 응답을 기다리지 않습니다** — 나가는 길에 서버를 세워
///    두면 아이는 아무 일도 안 일어나는 화면을 보게 되고, 실패하면 아예
///    못 나갑니다.
class FreeTalkPage extends StatefulWidget {
  const FreeTalkPage({
    required this.storyId,
    required this.characterId,
    required this.repository,
    required this.voiceRepository,
    this.initialCharacter,
    this.voiceRecorder,
    this.audioPlayer,
    super.key,
  });

  final String storyId;
  final String characterId;
  final FreeTalkRepository repository;

  /// STT·TTS 통로. 자유 대화도 `/api/stt` · `/api/tts` 를 그대로 쓰기 때문에
  /// 학습 대화의 저장소를 함께 받습니다. → [FreeTalkRepository] 문서
  final PlayRepository voiceRepository;

  /// 인물 고르기 화면이 `extra` 로 실어 보낸 인물. 시작 응답이 오기 전에도
  /// 이름을 띄울 수 있어 화면이 "이야기 친구"로 잠깐 흔들리지 않습니다.
  /// 주소로 바로 들어오면 `null` 이고, 시작 응답을 받은 뒤 이름이 채워집니다.
  final FreeTalkCharacter? initialCharacter;

  final MissionVoiceRecorder? voiceRecorder;
  final StoryAudioPlayer? audioPlayer;

  @override
  State<FreeTalkPage> createState() => _FreeTalkPageState();
}

class _FreeTalkPageState extends State<FreeTalkPage> {
  late final MissionVoiceRecorder _voiceRecorder;
  late final StoryAudioPlayer _audioPlayer;

  DialoguePhase _phase = DialoguePhase.characterSpeaking;
  DialogueCharacterManifest? _manifest;
  DialogueCharacterStateMachine? _character;

  FreeTalkSession? _session;
  FreeTalkCharacter? _characterInfo;

  bool _starting = true;
  String? _startError;

  /// 지금 말풍선에 떠 있는 문장들과 그중 몇 번째를 읽고 있는지.
  List<String> _characterSentences = const <String>[];
  int _characterSentenceIndex = 0;

  /// 방금 들려준 대사. "다시 듣기"가 **같은 음성 파일을** 다시 틀게 하려고
  /// 들고 있습니다 - 화면 글자만 모아 다시 부르면 사전 합성 음성을 버리고
  /// `/api/tts` 를 새로 태워, 같은 말인데 목소리가 미묘하게 달라집니다.
  FreeTalkSpeech? _lastSpeech;

  /// 지금 나오고 있는 대사를 식별하는 표. 새 대사가 시작되면 올라가고,
  /// 그 순간 이전 재생 루프는 스스로 빠져나갑니다. (`play_view.dart` 와 같은 방식)
  int _speechToken = 0;

  bool _soundOn = true;
  int _listeningSeconds = 0;
  Timer? _listeningTimer;
  Timer? _speechTimer;
  Completer<void>? _speechWait;

  bool _recordingVoice = false;
  bool _transcribingVoice = false;
  bool _submitting = false;

  PlayTranscription? _pendingTranscription;
  Timer? _confirmTimer;
  String? _lastChildText;
  bool _lastSttLowConfidence = false;
  String? _sttHint;
  int _sttRetryCount = 0;

  /// 보내는 중인 발화의 Idempotency-Key. 재시도 사이에는 유지하고 응답을
  /// 받으면 비웁니다. → `docs/이야기_전개_가이드.md` 3.4
  String? _pendingIdempotencyKey;

  /// 나가기를 눌러 "그만할까?"를 묻고 있는 중.
  bool _exitPrompt = false;

  /// 마무리 인사. 값이 있으면 "또 만나자" 화면이 화면을 통째로 덮습니다.
  FreeTalkSpeech? _farewell;

  /// 인사를 받아 오는 중("인사하고 나가기" 경로). 두 번 누르는 것을 막습니다.
  bool _ending = false;

  /// 인사 없이 떠나는 중("바로 나가기" 경로).
  ///
  /// [_ending] 과 달리 화면에 그리는 것이 없어 [setState] 를 걸지 않습니다 —
  /// 이 값이 서는 순간 화면 자체가 사라지기 때문입니다. 두 번 눌러 닫기
  /// 요청이 두 번 나가는 것만 막습니다.
  bool _leaving = false;

  bool get _isListening => _phase == DialoguePhase.listening;

  DialogueActivity get _activity {
    if (_submitting || _transcribingVoice) return DialogueActivity.thinking;
    if (_phase == DialoguePhase.listening) return DialogueActivity.listening;
    return DialogueActivity.speaking;
  }

  String get _characterName =>
      _characterInfo?.name ?? widget.initialCharacter?.name ?? '이야기 친구';

  String get _visibleCharacterText {
    if (_characterSentences.isEmpty) return '';
    return _characterSentences[_characterSentenceIndex.clamp(
      0,
      _characterSentences.length - 1,
    )];
  }

  @override
  void initState() {
    super.initState();
    _characterInfo = widget.initialCharacter;
    _voiceRecorder = widget.voiceRecorder ?? DeviceMissionVoiceRecorder();
    _audioPlayer = widget.audioPlayer ?? DeviceStoryAudioPlayer();
    unawaited(_loadManifest());
    unawaited(_start());
  }

  @override
  void dispose() {
    _listeningTimer?.cancel();
    _speechTimer?.cancel();
    _confirmTimer?.cancel();
    _releaseSpeechWait();
    unawaited(_voiceRecorder.dispose());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  /// 표정 에셋. **실패해도 대화는 굴러갑니다** — 무대 없이 말풍선만 남습니다.
  Future<void> _loadManifest() async {
    try {
      final DialogueCharacterManifest manifest =
          await DialogueCharacterManifest.load();
      if (!mounted) return;
      setState(() => _manifest = manifest);
      _bindCharacter();
    } on Object {
      // 무시한다.
    }
  }

  /// 인물에 맞는 표정 무대를 붙입니다. 장면이 아니라 **인물**로 찾습니다.
  void _bindCharacter() {
    final DialogueCharacterManifest? manifest = _manifest;
    if (manifest == null || _character != null) return;
    final DialogueSceneStates? states = manifest.sceneForCharacter(
      characterId: widget.characterId,
      name: _characterInfo?.name ?? widget.initialCharacter?.name,
    );
    if (states == null) return;
    setState(
      () => _character = DialogueCharacterStateMachine(states, manifest),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final String asset in states.allAssets) {
        unawaited(precacheImage(AssetImage(asset), context));
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final FreeTalkSession session = await widget.repository.start(
        storyId: widget.storyId,
        characterId: widget.characterId,
      );
      if (!mounted) return;
      setState(() {
        _starting = false;
        _session = session;
        _characterInfo = session.character;
      });
      _bindCharacter();
      await _speak(session.opening, onComplete: _startListening);
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = _describe(error, fallback: FreeTalkStrings.startFailed);
      });
    }
  }

  // ─────────────────────────────────────────────────────────
  // 캐릭터 대사
  // ─────────────────────────────────────────────────────────

  /// 대사 한 덩어리를 들려줍니다.
  ///
  /// 사전 합성 음성이 있으면 **문장을 쪼개지 않고 통째로** 띄웁니다. 서버가
  /// 문장별 실측 구간(`audioTimings`)을 주지 않아서, 쪼개 놓으면 자막이 소리와
  /// 어긋난 채 넘어갑니다 — 글자수로 어림한 시계는 반드시 틀립니다.
  /// (→ `play_view.dart` 의 `_speakFromFile` 은 실측 구간이 있을 때만 씁니다)
  ///
  /// 음성이 없으면 문장별로 합성해 읽고 자막도 그 단위로 넘깁니다.
  Future<void> _speak(FreeTalkSpeech speech, {VoidCallback? onComplete}) async {
    final int token = ++_speechToken;
    _speechTimer?.cancel();
    _listeningTimer?.cancel();
    _releaseSpeechWait();
    await _audioPlayer.stop();
    if (!mounted || token != _speechToken) return;

    _applyEmotion(speech.emotion);
    _lastSpeech = speech;
    final bool prerendered = speech.audioUrl != null;
    final List<String> sentences = prerendered
        ? <String>[speech.text]
        : _splitSentences(speech.text);
    setState(() {
      _phase = DialoguePhase.characterSpeaking;
      _characterSentences = sentences;
      _characterSentenceIndex = 0;
      _listeningSeconds = 0;
    });

    if (prerendered) {
      await _playOrWait(speech.audioUrl!, speech.text, token: token);
    } else {
      for (int index = 0; index < sentences.length; index++) {
        if (!mounted || token != _speechToken) return;
        setState(() => _characterSentenceIndex = index);
        final String? url = await _synthesize(sentences[index]);
        if (!mounted || token != _speechToken) return;
        await _playOrWait(url, sentences[index], token: token);
      }
    }
    if (!mounted || token != _speechToken) return;
    onComplete?.call();
  }

  /// 소리를 들려주고, 못 들려주면 읽을 시간만큼 기다립니다.
  ///
  /// 소리가 안 나는 것과 대사가 없는 것은 다릅니다 — 기다리지 않고 넘기면
  /// 캐릭터 말이 한 프레임 스치고 사라져 아이가 읽지 못합니다.
  Future<void> _playOrWait(
    String? url,
    String text, {
    required int token,
  }) async {
    if (url != null && url.isNotEmpty) {
      try {
        await _audioPlayer.playUrl(_resolveMediaUrl(url));
        return;
      } on Object {
        // 소리가 안 나도 흐름은 이어집니다.
      }
    }
    if (!mounted || token != _speechToken) return;
    await _waitForSpeech(
      Duration(milliseconds: (1200 + text.length * 55).clamp(1800, 5200)),
    );
  }

  Future<String?> _synthesize(String text) async {
    try {
      final PlaySpeechAudio audio = await widget.voiceRepository
          .synthesizeSpeech(text: text, characterName: _characterName);
      return audio.audioUrl;
    } on Object {
      return null;
    }
  }

  /// 서버가 준 감정을 표정으로 옮깁니다.
  ///
  /// **매니페스트에 없는 감정은 무시합니다.** 모르는 값에 아무 표정이나
  /// 고르면 아이가 한 말과 무관한 얼굴이 나옵니다 — 표정을 안 바꾸는 쪽이
  /// 틀린 표정을 짓는 것보다 낫습니다.
  void _applyEmotion(String? emotion) {
    final DialogueCharacterStateMachine? character = _character;
    if (character == null || emotion == null) return;
    if (!character.scene.states.containsKey(emotion)) return;
    if (character.current == emotion) return;
    setState(() => character.moveTo(emotion));
  }

  List<String> _splitSentences(String text) {
    final List<String> sentences = RegExp(r'[^.!?。！？]+[.!?。！？]?')
        .allMatches(text)
        .map((RegExpMatch match) => match.group(0)?.trim() ?? '')
        .where((String sentence) => sentence.isNotEmpty)
        .toList(growable: false);
    return sentences.isEmpty ? <String>[text.trim()] : sentences;
  }

  /// 상대 경로(`/tts/...`)를 백엔드 origin 기준 절대 URL로 바꿉니다.
  String _resolveMediaUrl(String source) => source.startsWith('/')
      ? Uri.parse(AppConfig.apiBaseUrl).resolve(source).toString()
      : source;

  Future<void> _waitForSpeech(Duration duration) {
    final Completer<void> completer = Completer<void>();
    _speechWait = completer;
    _speechTimer?.cancel();
    _speechTimer = Timer(duration, _releaseSpeechWait);
    return completer.future;
  }

  void _releaseSpeechWait() {
    final Completer<void>? pending = _speechWait;
    _speechWait = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  // ─────────────────────────────────────────────────────────
  // 아이 차례
  // ─────────────────────────────────────────────────────────

  /// 캐릭터 말이 끝나 아이 차례가 되는 지점. 지난 차례의 발화를 지웁니다 —
  /// 새 차례에 남아 있으면 아이가 이번에 한 말로 오해합니다.
  void _startListening() {
    if (!mounted || _farewell != null) return;
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
    });
    _listeningTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phase == DialoguePhase.listening && !_recordingVoice) {
        unawaited(_toggleVoice());
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (!_isListening || _transcribingVoice || _submitting) return;
    if (_pendingTranscription != null) return;
    if (!_recordingVoice) {
      await _beginRecording();
      return;
    }
    await _finishRecording();
  }

  Future<void> _beginRecording() async {
    try {
      final bool allowed = await _voiceRecorder.start();
      if (!mounted) return;
      if (!allowed) {
        setState(() => _sttHint = '마이크를 쓰게 해 줄래?');
        return;
      }
      setState(() {
        _recordingVoice = true;
        _listeningSeconds = 0;
      });
      _listeningTimer?.cancel();
      _listeningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recordingVoice) return;
        setState(() => _listeningSeconds++);
        // 업로드 한도에 닿기 전에 여기까지 말한 것을 보냅니다.
        // (`mission_voice_recorder.dart` 의 maxRecordingSeconds)
        if (_listeningSeconds >= maxRecordingSeconds) {
          unawaited(_toggleVoice());
        }
      });
    } on Object {
      if (mounted) setState(() => _sttHint = '마이크를 켜지 못했어. 다시 눌러 볼까?');
    }
  }

  Future<void> _finishRecording() async {
    _listeningTimer?.cancel();
    setState(() {
      _recordingVoice = false;
      _transcribingVoice = true;
    });
    try {
      final Uint8List? audio = await _voiceRecorder.stop();
      if (audio == null || audio.isEmpty) throw StateError('empty audio');
      final PlayTranscription transcription = await widget.voiceRepository
          .transcribeAudio(audio);
      if (!mounted) return;
      // 학습 대화와 같은 리듬입니다 — 말한다 → 내 말을 본다 → 보낸다.
      // 오인식을 되돌릴 수 있는 유일한 시점이 제출 전입니다.
      setState(() {
        _transcribingVoice = false;
        _pendingTranscription = transcription;
      });
      _confirmTimer?.cancel();
      // 저신뢰에만 무반응 시계를 겁니다. "맞을까요?"라고 물어 놓고 아이가
      // 답을 못 찾으면 대화가 멈춥니다. 잘 알아들은 턴은 탭을 기다립니다.
      if (transcription.lowConfidence) {
        _confirmTimer = Timer(
          const Duration(seconds: 6),
          () => unawaited(_confirm()),
        );
      }
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _transcribingVoice = false;
        _sttRetryCount++;
        _sttHint = _voiceRetryHint(error) ?? '목소리를 잘 듣지 못했어. 다시 말해 볼까?';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _transcribingVoice = false;
        _sttRetryCount++;
        _sttHint = '목소리를 잘 듣지 못했어. 다시 말해 볼까?';
      });
    }
  }

  /// 마이크 옆 안내로 처리할 실패인지. (`play_view.dart` 와 같은 표)
  String? _voiceRetryHint(Failure error) {
    if (error is! ServerFailure) return null;
    return switch (error.code) {
      'STT_EMPTY_TEXT' => '잘 못 들었어요. 다시 말해 볼까?',
      'AUDIO_TOO_LARGE' => '조금만 짧게 말해 줄래?',
      'AI_RATE_LIMITED' ||
      'AI_UPSTREAM_ERROR' ||
      'AI_UNAVAILABLE' => '지금은 잘 안 들려요. 잠시 뒤에 다시 해볼까?',
      _ => null,
    };
  }

  Future<void> _confirm() async {
    final PlayTranscription? pending = _pendingTranscription;
    _confirmTimer?.cancel();
    _confirmTimer = null;
    if (!mounted || pending == null || _submitting) return;
    setState(() => _pendingTranscription = null);
    await _send(pending);
  }

  /// 다르게 들렸다고 했습니다. 결과를 버리고 곧바로 다시 녹음합니다 —
  /// 마이크를 한 번 더 누르게 하면 아이가 흐름을 놓칩니다.
  Future<void> _retry() async {
    _confirmTimer?.cancel();
    _confirmTimer = null;
    if (!mounted || _pendingTranscription == null || _submitting) return;
    setState(() {
      _pendingTranscription = null;
      _sttRetryCount++;
      _sttHint = null;
    });
    await _toggleVoice();
  }

  // ─────────────────────────────────────────────────────────
  // 발화 제출
  // ─────────────────────────────────────────────────────────

  Future<void> _send(PlayTranscription transcription) async {
    final FreeTalkSession? session = _session;
    final String text = transcription.text.trim();
    if (session == null || text.isEmpty || _submitting) return;
    _listeningTimer?.cancel();
    setState(() {
      _submitting = true;
      _phase = DialoguePhase.characterSpeaking;
      _sttHint = null;
      _lastChildText = text;
      _lastSttLowConfidence = transcription.lowConfidence;
    });
    try {
      final FreeTalkTurn turn = await _sendWithRetry(session.freeTalkId, text);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sttRetryCount = 0;
      });
      // 서버가 닫은 대화면 이 대사가 곧 작별 인사입니다. 다 읽어 준 뒤에
      // 화면을 넘깁니다 — 말이 끝나기 전에 넘기면 인사가 잘립니다.
      await _speak(
        turn.characterMessage,
        onComplete: turn.ended
            ? () => _showFarewell(turn.characterMessage)
            : _startListening,
      );
    } on Failure catch (error) {
      if (!mounted) return;
      // 대화 중 실패로 화면을 갈아엎지 않습니다. 듣기 상태로 돌려 아이가
      // 다시 말할 수 있게 둡니다.
      setState(() {
        _submitting = false;
        _phase = DialoguePhase.listening;
        _sttHint = _voiceRetryHint(error) ?? '지금은 대답을 못 받았어. 다시 말해 볼까?';
      });
    }
  }

  /// `REQUEST_IN_PROGRESS`(같은 키의 요청이 아직 처리 중)만 같은 키로
  /// 재시도합니다. 그 외 실패는 그대로 올립니다.
  Future<FreeTalkTurn> _sendWithRetry(String freeTalkId, String text) async {
    final String key = _pendingIdempotencyKey ??= _newIdempotencyKey();
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final FreeTalkTurn turn = await widget.repository.sendMessage(
          freeTalkId,
          text: text,
          idempotencyKey: key,
        );
        _pendingIdempotencyKey = null;
        return turn;
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
    throw const UnknownFailure();
  }

  /// UUID v4 형태의 키. (`play_view.dart` 와 같은 방식)
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

  String _describe(Failure error, {required String fallback}) =>
      error is ServerFailure ? fallback : error.message;

  // ─────────────────────────────────────────────────────────
  // 마무리
  // ─────────────────────────────────────────────────────────

  void _requestExit() {
    if (_farewell != null || _ending) return;
    setState(() => _exitPrompt = true);
  }

  /// 아이가 "인사하고 나가기"를 골랐습니다. 서버에서 마무리 인사를 받아
  /// 들려준 뒤 "또 만나자" 화면으로 넘어갑니다.
  ///
  /// 인사를 못 받아 와도 **화면은 넘어갑니다.** 나가려는 아이를 에러 화면에
  /// 붙잡아 두는 것이 더 나쁩니다 — 그때는 기본 인사말로 대신합니다.
  Future<void> _endTalk() async {
    final FreeTalkSession? session = _session;
    if (_ending) return;
    setState(() {
      _ending = true;
      _exitPrompt = false;
    });
    _speechToken++;
    _listeningTimer?.cancel();
    _confirmTimer?.cancel();
    _releaseSpeechWait();
    if (_recordingVoice) await _voiceRecorder.cancel();
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _recordingVoice = false;
      _transcribingVoice = false;
      _pendingTranscription = null;
    });

    FreeTalkSpeech closing = const FreeTalkSpeech(text: '오늘 이야기 즐거웠어. 또 만나자!');
    if (session != null) {
      try {
        closing = await widget.repository.end(session.freeTalkId);
      } on Failure {
        // 기본 인사말로 갑니다.
      }
    }
    // **여기서 _ending 을 내리지 않습니다.** 인사를 읽는 동안 나가기를 다시
    // 누르면 확인 카드가 인사 위에 또 뜹니다. [_showFarewell] 이 내립니다.
    await _speak(closing);
    if (!mounted) return;
    _showFarewell(closing);
  }

  /// 아이가 "바로 나가기"를 골랐습니다. 인사 없이 즉시 홈으로 갑니다.
  ///
  /// **`await` 가 하나도 없습니다.** 닫기 요청을 띄워만 놓고 같은 프레임에
  /// 화면을 떠납니다 — 기다리면 나가려는 아이를 서버 왕복만큼 붙잡아 두게
  /// 되고, 그게 이 갈래를 만든 이유(기다리기 싫다)를 그대로 되돌립니다.
  /// 요청이 실패해도 아이는 이미 나갔고, 실패는 화면에 뜨지 않습니다.
  ///
  /// 그래도 요청을 보내는 이유는 안 보내면 그 대화가 `ended_at` 없이 열린
  /// 채 남기 때문입니다. 녹음기·타이머를 여기서 직접 끄는 것도 같은 이유로,
  /// [dispose] 의 `recorder.dispose()` 는 `cancel()` 과 달라 켜져 있던 마이크
  /// 스트림 구독을 정리하지 않습니다.
  void _leaveNow() {
    final FreeTalkSession? session = _session;
    _speechToken++;
    _listeningTimer?.cancel();
    _speechTimer?.cancel();
    _confirmTimer?.cancel();
    _releaseSpeechWait();
    if (_recordingVoice) unawaited(_voiceRecorder.cancel());
    // 한 번만 막는 것은 **닫기 요청**이고, 화면을 떠나는 시도는 누를 때마다
    // 다시 합니다. [_leave] 에는 라우터가 없어 제자리에 남는 길이 있어서,
    // 함수 전체를 막으면 그 자리에서 버튼이 죽습니다.
    if (session != null && !_leaving) {
      _leaving = true;
      // 저장소를 **먼저 붙잡습니다.** 아래 [_goHome] 이 이 위젯을 걷어내므로,
      // 그 뒤에 `widget` 을 다시 읽는 코드는 남기지 않습니다.
      final FreeTalkRepository repository = widget.repository;
      unawaited(_closeQuietly(repository, session.freeTalkId));
    }
    _goHome();
  }

  /// 대화를 닫기만 하고 결과를 버립니다.
  ///
  /// 화면이 이미 사라진 뒤에 끝나는 요청이라 [State] 를 건드리지 않습니다.
  /// 실패를 삼키는 것이 이 함수의 일입니다 — 아이가 홈에 도착한 뒤에 뜨는
  /// 에러는 아이가 할 수 있는 것이 없는 에러입니다.
  static Future<void> _closeQuietly(
    FreeTalkRepository repository,
    String freeTalkId,
  ) async {
    try {
      await repository.leave(freeTalkId);
    } on Object {
      // 나가는 길을 막지 않습니다.
    }
  }

  void _showFarewell(FreeTalkSpeech closing) {
    if (!mounted || _farewell != null) return;
    _listeningTimer?.cancel();
    _confirmTimer?.cancel();
    setState(() {
      _farewell = closing;
      _ending = false;
      _phase = DialoguePhase.characterSpeaking;
      _recordingVoice = false;
      _transcribingVoice = false;
      _pendingTranscription = null;
      _exitPrompt = false;
    });
  }

  void _goHome() => _leave(AppRoutes.home);

  void _goStory() => _leave(AppRoutes.storyDetailOf(widget.storyId));

  void _leave(String location) {
    _speechToken++;
    unawaited(_audioPlayer.stop());
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
      return;
    }
    router.go(location);
  }

  void _toggleSound() {
    setState(() => _soundOn = !_soundOn);
    unawaited(_audioPlayer.setMuted(!_soundOn));
  }

  /// 다시 듣기 — 방금 한 대사를 처음부터 다시 들려줍니다.
  ///
  /// 말하던 중이었다면 다 읽은 뒤 아이 차례로 넘기고, 이미 아이 차례였다면
  /// 소리만 다시 틀고 차례를 뺏지 않습니다 - 다시 들으려고 눌렀는데 마이크가
  /// 새로 켜지면 아이가 하던 말을 잃습니다.
  void _replay() {
    final FreeTalkSpeech? last = _lastSpeech;
    // 인사를 받아 오는 중에는 받지 않습니다. 여기서 [_speak] 를 새로 걸면
    // `_speechToken` 이 올라가 [_endTalk] 가 기다리던 낭독이 조용히 취소되고,
    // 그 뒤의 [_showFarewell] 이 곧바로 불려 **작별 인사가 중간에 잘린 채**
    // 엔드카드가 떠 버립니다. (화면이 멈추지는 않습니다 - `_speak` 첫머리의
    // `_audioPlayer.stop()` 이 기다리던 completer 를 풀어 주기 때문입니다.)
    if (last == null || _farewell != null || _ending) return;
    final bool wasListening = _isListening;
    unawaited(_speak(last, onComplete: wasListening ? null : _startListening));
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return const Scaffold(
        backgroundColor: Color(0xFF183455),
        body: AppLoadingView(),
      );
    }
    final String? startError = _startError;
    if (startError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5FAF8),
        body: AppKidErrorView(
          message: startError,
          onRetry: () => unawaited(_start()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF183455),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 760;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DialogueBackdrop(asset: _character?.scene.backgroundAsset),
              const DialogueBackdropShade(),
              SafeArea(
                minimum: EdgeInsets.all(compact ? 12 : 22),
                child: Column(
                  children: <Widget>[
                    // 진행바가 있던 자리를 비워 둡니다 — 자유 대화에는 "어디까지
                    // 왔다"가 없습니다. 나가는 문과 소리만 남깁니다.
                    Row(
                      children: <Widget>[
                        DialogueControlButton(
                          label: '나가기',
                          icon: AppIcons.close,
                          onPressed: _requestExit,
                        ),
                        const Spacer(),
                        DialogueControlButton(
                          label: '다시 듣기',
                          icon: AppIcons.replay,
                          onPressed: _replay,
                        ),
                        const SizedBox(width: 8),
                        DialogueControlButton(
                          label: _soundOn ? '소리 끄기' : '소리 켜기',
                          icon: _soundOn ? AppIcons.soundOn : AppIcons.soundOff,
                          onPressed: _toggleSound,
                        ),
                      ],
                    ),
                    Expanded(
                      child: DialogueCanvas(
                        character: _character,
                        activity: _activity,
                        characterAsset: null,
                        characterName: _characterName,
                        question: _visibleCharacterText,
                        phase: _phase,
                        listeningSeconds: _listeningSeconds,
                        recording: _recordingVoice,
                        transcribing: _transcribingVoice,
                        compact: compact,
                        onMicTap: _isListening && _pendingTranscription == null
                            ? () => unawaited(_toggleVoice())
                            : null,
                        micNeedsTap: _sttRetryCount > 0,
                        submitting: _submitting,
                        lastChildText: _lastChildText,
                        lastSttLowConfidence: _lastSttLowConfidence,
                        sttHint: _sttHint,
                        pendingTranscription: _pendingTranscription,
                        onConfirmTranscription: () => unawaited(_confirm()),
                        onRetryTranscription: () => unawaited(_retry()),
                      ),
                    ),
                  ],
                ),
              ),
              if (_exitPrompt)
                FreeTalkExitPrompt(
                  onKeep: () => setState(() => _exitPrompt = false),
                  onFarewell: () => unawaited(_endTalk()),
                  onLeaveNow: _leaveNow,
                ),
              // 맨 위에서 화면을 **불투명하게** 덮습니다. 대화가 끝난 뒤에는
              // 아래에 더 누를 것이 없고, 남아 있는 마이크 안내("이제 말할
              // 차례예요")는 사실이 아닙니다.
              if (_farewell != null)
                FreeTalkFarewellScreen(
                  characterName: _characterName,
                  closingText: _farewell!.text,
                  character: _character,
                  onHome: _goHome,
                  onStory: _goStory,
                ),
            ],
          );
        },
      ),
    );
  }
}
