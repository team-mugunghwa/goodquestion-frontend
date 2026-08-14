import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../domain/entities/play_session.dart';
import '../../domain/repositories/play_repository.dart';

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
    super.key,
  });

  final String sessionId;
  final String? backgroundAsset;
  final String? characterAsset;
  final String characterName;
  final String question;
  final PlayRepository? repository;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

enum _DialoguePhase { characterSpeaking, listening, paused }

class _PlayPageState extends State<PlayPage> {
  static const Duration _previewQuestionDuration = Duration(seconds: 2);

  _DialoguePhase _phase = _DialoguePhase.characterSpeaking;
  _DialoguePhase _phaseBeforePause = _DialoguePhase.characterSpeaking;
  Timer? _questionTimer;
  Timer? _listeningTimer;
  Timer? _storyTimer;
  int _listeningSeconds = 0;
  bool _soundOn = true;
  bool _loadingSession = false;
  bool _advancingScene = false;
  bool _storyPaused = false;
  int _narrationIndex = 0;
  String? _loadError;
  PlaySessionSnapshot? _snapshot;

  bool get _isListening => _phase == _DialoguePhase.listening;

  @override
  void initState() {
    super.initState();
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
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
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
      _narrationIndex = 0;
      _storyPaused = false;
      _scheduleCurrentNarration();
      return;
    }
    _playQuestion();
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

  void _playQuestion() {
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    _listeningSeconds = 0;
    if (mounted) setState(() => _phase = _DialoguePhase.characterSpeaking);

    // 실제 연동 시에는 TTS player의 onComplete에서 _startListening을 호출합니다.
    _questionTimer = Timer(_previewQuestionDuration, _startListening);
  }

  void _startListening() {
    if (!mounted || _phase == _DialoguePhase.paused) return;
    setState(() {
      _phase = _DialoguePhase.listening;
      _listeningSeconds = 0;
    });
    _listeningTimer?.cancel();
    _listeningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isListening) setState(() => _listeningSeconds++);
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
    _questionTimer?.cancel();
    _listeningTimer?.cancel();
    setState(() => _phase = _DialoguePhase.paused);
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
                asset: dialogueScene?.imageUrl ?? widget.backgroundAsset,
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
                        question: _snapshot?.openingText ?? widget.question,
                        phase: _phase,
                        listeningSeconds: _listeningSeconds,
                        compact: compact,
                        onMicTap: _isListening ? _startListening : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (_phase == _DialoguePhase.paused)
                _PauseOverlay(onResume: _togglePause, onExit: _confirmExit),
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
      final Uri? uri = Uri.tryParse(asset!);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return Image.network(
          asset!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _FallbackStoryBackdrop(),
        );
      }
      return Image.asset(
        asset!,
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
    required this.compact,
    required this.onMicTap,
  });

  final String? characterAsset;
  final String characterName;
  final String question;
  final _DialoguePhase phase;
  final int listeningSeconds;
  final bool compact;
  final VoidCallback? onMicTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Align(
                  alignment: Alignment.bottomLeft,
                  child: _CharacterSlot(
                    asset: characterAsset,
                    name: characterName,
                    compact: true,
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: FractionallySizedBox(
                    widthFactor: .72,
                    child: _QuestionBubble(
                      name: characterName,
                      question: question,
                      speaking: phase == _DialoguePhase.characterSpeaking,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ChildBubble(
            phase: phase,
            seconds: listeningSeconds,
            onMicTap: onMicTap,
            compact: true,
          ),
        ],
      );
    }

    return Stack(
      children: <Widget>[
        Positioned(
          left: 16,
          bottom: 0,
          width: 390,
          top: 72,
          child: _CharacterSlot(asset: characterAsset, name: characterName),
        ),
        Positioned(
          left: 330,
          right: 90,
          top: 72,
          child: _QuestionBubble(
            name: characterName,
            question: question,
            speaking: phase == _DialoguePhase.characterSpeaking,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 20,
          width: 560,
          child: _ChildBubble(
            phase: phase,
            seconds: listeningSeconds,
            onMicTap: onMicTap,
          ),
        ),
      ],
    );
  }
}

class _CharacterSlot extends StatelessWidget {
  const _CharacterSlot({
    required this.asset,
    required this.name,
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
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          if (asset != null)
            Image.asset(
              asset!,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            )
          else
            CustomPaint(
              size: Size(compact ? 220 : 360, compact ? 320 : 520),
              painter: const _CharacterPlaceholderPainter(),
            ),
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE6173150),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white54),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({
    required this.name,
    required this.question,
    required this.speaking,
  });

  final String name;
  final String question;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _LeftTailPainter(color: Color(0xFFFFFCF2)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 142, maxWidth: 720),
        padding: const EdgeInsets.fromLTRB(30, 22, 30, 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFFFD56A), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  speaking
                      ? AppIcons.characterSpeaking
                      : Icons.check_circle_rounded,
                  color: speaking
                      ? const Color(0xFF4B8EC2)
                      : const Color(0xFF4A9B78),
                ),
                const SizedBox(width: 8),
                Text(
                  speaking ? '$name이 말하고 있어요' : '$name의 질문',
                  style: const TextStyle(
                    color: Color(0xFF47607A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1C2C40),
                fontSize: 25,
                height: 1.45,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildBubble extends StatelessWidget {
  const _ChildBubble({
    required this.phase,
    required this.seconds,
    required this.onMicTap,
    this.compact = false,
  });

  final _DialoguePhase phase;
  final int seconds;
  final VoidCallback? onMicTap;
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
            _ListeningMic(active: listening, onTap: onMicTap),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    listening ? '잘 듣고 있어요 · $seconds초' : '질문을 듣고 있어요',
                    style: const TextStyle(
                      color: Color(0xFF8DE7CF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    listening ? '나는 이렇게 생각해요…' : '질문이 끝나면 마이크가 자동으로 켜져요.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (listening) ...<Widget>[
                    const SizedBox(height: 10),
                    const Text(
                      '한 문장으로 천천히 말해 주세요',
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
  const _ListeningMic({required this.active, required this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: active ? '마이크 켜짐' : '마이크 준비 중',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF77E0C4) : const Color(0xFF6D8094),
          shape: BoxShape.circle,
          boxShadow: active
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x8877E0C4),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: IconButton(
          tooltip: active ? '듣고 있어요' : '질문이 끝나면 자동으로 켜져요',
          onPressed: onTap,
          icon: Icon(active ? AppIcons.speaking : AppIcons.speak),
          iconSize: 38,
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

class _LeftTailPainter extends CustomPainter {
  const _LeftTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(4, 56)
        ..lineTo(-28, 78)
        ..lineTo(6, 90)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _CharacterPlaceholderPainter extends CustomPainter {
  const _CharacterPlaceholderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glow = Paint()..color = const Color(0x334EE0C2);
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .35),
      size.width * .4,
      glow,
    );
    final Paint body = Paint()..color = const Color(0xFF92C4D9);
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .28),
      size.width * .22,
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .18,
          size.height * .48,
          size.width * .64,
          size.height * .52,
        ),
        Radius.circular(size.width * .28),
      ),
      body,
    );
    final Paint face = Paint()..color = const Color(0xFF264866);
    canvas.drawCircle(Offset(size.width * .43, size.height * .27), 5, face);
    canvas.drawCircle(Offset(size.width * .57, size.height * .27), 5, face);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .34),
        width: 42,
        height: 24,
      ),
      0,
      3.14,
      false,
      Paint()
        ..color = const Color(0xFF264866)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
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
