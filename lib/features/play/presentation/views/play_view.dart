import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../domain/entities/play_session.dart';
import '../../domain/repositories/play_repository.dart';
import '../voice/mission_voice_recorder.dart';
import '../voice/story_audio_player.dart';
import '../widgets/mission_overlay.dart';

/// 모든 이야기가 공유하는 대화 장면 템플릿입니다.
///
/// 서버 연결 후에는 장면 응답으로 [backgroundAsset], [characterAsset],
/// [characterName], [question]을 채우면 됩니다. 질문과 아이 답변은 항상
/// 한 문장만 화면에 노출합니다.
class PlayPage extends StatefulWidget {
  const PlayPage({
    required this.sessionId,
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
  String? _lastChildText;
  bool _lastSttLowConfidence = false;
  String? _retainedStoryImageUrl;
  String? _resultImageUrl;

  bool get _isListening => _phase == _DialoguePhase.listening;

  @override
  void initState() {
    super.initState();
    _voiceRecorder = widget.voiceRecorder ?? DeviceMissionVoiceRecorder();
    _audioPlayer = widget.audioPlayer ?? DeviceStoryAudioPlayer();
    if (widget.repository == null) {
      _playQuestion();
    } else {
      unawaited(_loadSession());
    }
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    _storyTimer?.cancel();
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
      String? recoveredChildText;
      for (final PlayMessage message in snapshot.messages) {
        if (message.speaker == PlaySpeaker.child) {
          recoveredChildText = message.text;
        }
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _mission = recoveredMission;
        _characterReply = null;
        _lastChildText = recoveredChildText;
        _loadingSession = false;
      });
      _activateSnapshot(snapshot);
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSession = false;
        _loadError = error.message;
      });
    }
  }

  void _activateSnapshot(PlaySessionSnapshot snapshot) {
    _storyTimer?.cancel();
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
      setState(() => _loadError = error.message);
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

  Future<void> _submitDialogue(
    String text, {
    String? sttRawText,
    double? sttConfidence,
    bool lowConfidence = false,
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
      _lastChildText = normalized;
      _lastSttLowConfidence = lowConfidence;
    });
    try {
      final PlayTurnResult result = await widget.repository!.submitUtterance(
        widget.sessionId,
        text: normalized,
        sttRawText: sttRawText,
        sttConfidence: sttConfidence,
      );
      if (!mounted) return;
      setState(() {
        _submittingUtterance = false;
        _transcribingVoice = false;
        _characterReply = result.characterText;
      });
      await _presentTurnResult(result);
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _submittingUtterance = false;
        _transcribingVoice = false;
        _loadError = error.message;
      });
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
    if (!_isListening || _transcribingVoice || _submittingUtterance) return;
    if (!_recordingVoice) {
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
      await _submitDialogue(
        transcription.text,
        sttRawText: transcription.text,
        sttConfidence: transcription.confidence,
        lowConfidence: transcription.lowConfidence,
      );
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _transcribingVoice = false;
        _loadError = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _transcribingVoice = false;
        _loadError = '목소리를 잘 듣지 못했어요. 다시 말해 주세요.';
      });
    }
  }

  Future<void> _presentTurnResult(PlayTurnResult result) async {
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
      final PlayTurnResult result = await widget.repository!.submitUtterance(
        widget.sessionId,
        text: answer,
        missionId: mission.missionId,
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
      setState(() {
        _submittingMission = false;
        _loadError = error.message;
      });
    }
  }

  void _scheduleCurrentNarration() {
    final List<String> sentences =
        _snapshot?.currentScene?.narrationSentences ?? const <String>[];
    if (_storyPaused || _advancingScene) return;
    if (_narrationIndex >= sentences.length) {
      _storyTimer = Timer(const Duration(milliseconds: 700), () {
        unawaited(_completeStoryScene());
      });
      return;
    }
    final int milliseconds = (1400 + sentences[_narrationIndex].length * 65)
        .clamp(2400, 7500)
        .toInt();
    _storyTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted || _storyPaused) return;
      setState(() => _narrationIndex++);
      _scheduleCurrentNarration();
    });
  }

  Future<void> _completeStoryScene() async {
    if (_advancingScene || widget.repository == null) return;
    setState(() => _advancingScene = true);
    try {
      final PlaySessionSnapshot snapshot = await widget.repository!
          .completeStoryScene(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _advancingScene = false;
        _narrationIndex = 0;
      });
      _activateSnapshot(snapshot);
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _advancingScene = false;
        _loadError = error.message;
      });
    }
  }

  void _toggleStoryPause() {
    _storyTimer?.cancel();
    setState(() => _storyPaused = !_storyPaused);
    if (!_storyPaused) _scheduleCurrentNarration();
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

  Future<void> _playCharacterMessage(
    String text, {
    String? audioUrl,
    VoidCallback? onComplete,
  }) async {
    final int token = ++_speechToken;
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
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

    for (int index = 0; index < sentences.length; index++) {
      if (!mounted || token != _speechToken) return;
      setState(() => _characterSentenceIndex = index);
      bool played = false;
      if (_soundOn && widget.repository != null) {
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
          if (source.isNotEmpty) {
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
      if (!played) {
        final int milliseconds = widget.repository == null
            ? 2000
            : (1200 + sentences[index].length * 55).clamp(1800, 5200).toInt();
        await _waitForSpeech(Duration(milliseconds: milliseconds));
      }
    }
    if (mounted && token == _speechToken) onComplete?.call();
  }

  Future<void> _waitForSpeech(Duration duration) {
    final Completer<void> completer = Completer<void>();
    _questionTimer?.cancel();
    _questionTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  List<String> _splitSentences(String text) {
    final List<String> sentences = RegExp(r'[^.!?。！？]+[.!?。！？]?')
        .allMatches(text)
        .map((match) => match.group(0)?.trim() ?? '')
        .where((sentence) => sentence.isNotEmpty)
        .toList(growable: false);
    return sentences.isEmpty ? <String>[text.trim()] : sentences;
  }

  void _startListening() {
    if (!mounted || _phase == _DialoguePhase.paused) return;
    setState(() {
      _phase = _DialoguePhase.listening;
      _listeningSeconds = 0;
      _recordingVoice = false;
      _transcribingVoice = false;
    });
    _listeningTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phase == _DialoguePhase.listening && !_recordingVoice) {
        unawaited(_toggleVoiceAnswer());
      }
    });
  }

  void _togglePause() {
    if (_phase == _DialoguePhase.paused) {
      setState(() => _phase = _phaseBeforePause);
      if (_phase == _DialoguePhase.characterSpeaking) {
        _playQuestion();
      } else {
        _startListening();
      }
      return;
    }

    _phaseBeforePause = _phase;
    _speechToken++;
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    if (_recordingVoice) unawaited(_voiceRecorder.cancel());
    unawaited(_audioPlayer.stop());
    setState(() {
      _recordingVoice = false;
      _transcribingVoice = false;
      _phase = _DialoguePhase.paused;
    });
  }

  Future<void> _confirmExit() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('이야기를 나갈까요?'),
        content: const Text('지금까지 들은 곳은 저장해 둘게요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 듣기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('이야기 나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) await Navigator.of(context).maybePop();
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
          onExit: _confirmExit,
          onPause: _toggleStoryPause,
          onReplay: () {
            _storyTimer?.cancel();
            setState(() => _narrationIndex = 0);
            _scheduleCurrentNarration();
          },
          onSound: () => setState(() => _soundOn = !_soundOn),
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
                asset:
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
                      onExit: _confirmExit,
                      onPause: _togglePause,
                      onReplay: _playQuestion,
                      onSound: () => setState(() => _soundOn = !_soundOn),
                    ),
                    Expanded(
                      child: _DialogueCanvas(
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
                        onMicTap: _isListening ? _toggleVoiceAnswer : null,
                        submitting: _submittingUtterance,
                        lastChildText: _lastChildText,
                        lastSttLowConfidence: _lastSttLowConfidence,
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
    required this.onExit,
    required this.onPause,
    required this.onReplay,
    required this.onSound,
  });

  final bool isPaused;
  final bool soundOn;
  final VoidCallback onExit;
  final VoidCallback onPause;
  final VoidCallback onReplay;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ControlButton(label: '나가기', icon: AppIcons.close, onPressed: onExit),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .32),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: .42,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD56A),
                  borderRadius: BorderRadius.circular(99),
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
  });

  final String? characterAsset;
  final String characterName;
  final String question;
  final _DialoguePhase phase;
  final int listeningSeconds;
  final bool recording;
  final bool transcribing;
  final bool compact;
  final VoidCallback? onMicTap;
  final bool submitting;
  final String? lastChildText;
  final bool lastSttLowConfidence;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (characterAsset != null && !compact)
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
              left: compact ? 10 : constraints.maxWidth * .23,
              right: compact ? 10 : 20,
              top: compact ? 18 : 44,
              child: _QuestionBubble(
                characterName: characterName,
                question: question,
                compact: compact,
              ),
            ),
            if (!compact)
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
                onMicTap: onMicTap,
                lastChildText: lastChildText,
                lowConfidence: lastSttLowConfidence,
                compact: compact,
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

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({
    required this.characterName,
    required this.question,
    required this.compact,
  });

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
          constraints: BoxConstraints(minHeight: compact ? 138 : 176),
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
              Semantics(
                liveRegion: true,
                label: question,
                child: Text(
                  question,
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF172A3E),
                    fontSize: compact ? 27 : 34,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
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
  });

  final _DialoguePhase phase;
  final int seconds;
  final bool recording;
  final bool transcribing;
  final bool submitting;
  final VoidCallback? onMicTap;
  final String? lastChildText;
  final bool lowConfidence;
  final bool compact;

  bool get listening => phase == _DialoguePhase.listening;

  @override
  Widget build(BuildContext context) {
    final String status = transcribing
        ? '목소리를 글로 바꾸고 있어요'
        : submitting
        ? '이야기 친구가 답을 준비하고 있어요'
        : recording
        ? '잘 듣고 있어요 · $seconds초'
        : listening
        ? '이제 말할 차례예요'
        : '질문을 듣고 있어요';
    final String body = lastChildText?.trim().isNotEmpty == true
        ? lastChildText!.trim()
        : recording
        ? '나는 이렇게 생각해요…'
        : transcribing
        ? '말한 내용을 잠깐 확인하고 있어요.'
        : listening
        ? '마이크가 자동으로 켜졌어요.'
        : '질문이 끝나면 마이크가 켜져요.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: BoxConstraints(minHeight: compact ? 128 : 154),
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
            ready: listening,
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
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 20 : 23,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (lowConfidence && lastChildText != null) ...<Widget>[
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
