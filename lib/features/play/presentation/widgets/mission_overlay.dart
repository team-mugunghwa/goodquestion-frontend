import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/entities/play_session.dart';
import '../voice/mission_voice_recorder.dart';

class MissionOverlay extends StatefulWidget {
  const MissionOverlay({
    required this.mission,
    required this.onSubmit,
    required this.transcribeAudio,
    this.recorder,
    this.submitting = false,
    this.completed = false,
    super.key,
  });

  final PlayMission mission;
  final ValueChanged<String> onSubmit;
  final Future<String> Function(Uint8List wavBytes) transcribeAudio;
  final MissionVoiceRecorder? recorder;
  final bool submitting;
  final bool completed;

  @override
  State<MissionOverlay> createState() => _MissionOverlayState();
}

enum _VoiceStage { ready, recording, transcribing, confirming, error }

class _MissionOverlayState extends State<MissionOverlay> {
  late final MissionVoiceRecorder _recorder;
  final Map<String, String> _answers = <String, String>{};
  Timer? _recordingTimer;
  int _activeIndex = 0;
  int _recordingSeconds = 0;
  _VoiceStage _stage = _VoiceStage.ready;
  String? _errorMessage;

  /// 아이의 확인을 기다리는 변환 결과. 확인 전에는 [_answers] 에 넣지 않습니다 -
  /// 넣어 버리면 진행 눈금이 먼저 차오르고, 다음 생각으로 넘어간 뒤라 아이가
  /// 방금 무엇이 저장됐는지 볼 자리가 사라집니다.
  ///
  /// 대화 화면과 같은 규칙입니다: 말한다 → 내 말을 본다 → 보낸다.
  /// 여기에는 무반응 자동 확정 시계를 걸지 않습니다 - 미션은 아이가 네 번
  /// 눌러서 쌓아 가는 화면이고, 저 혼자 넘어가면 쌓는 감각이 깨집니다.
  String? _pendingTranscript;

  List<_MissionPrompt> get _prompts =>
      widget.mission.missionType == PlayMissionType.problemSolving
      ? widget.mission.questions
            .map(
              (item) => _MissionPrompt(
                key: item.key,
                title: item.label,
                guide: _questionGuide(item.key),
              ),
            )
            .toList(growable: false)
      : widget.mission.cards
            .map(
              (item) => _MissionPrompt(
                key: item.key,
                title: item.label,
                guide: item.template?.isNotEmpty == true
                    ? item.template!
                    : '${item.label}의 새로운 장점을 말해 볼까요?',
              ),
            )
            .toList(growable: false);

  bool get _allAnswered =>
      _prompts.isNotEmpty &&
      _prompts.every((prompt) => _answers[prompt.key]?.isNotEmpty == true);

  @override
  void initState() {
    super.initState();
    _recorder = widget.recorder ?? DeviceMissionVoiceRecorder();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_stage == _VoiceStage.transcribing || widget.submitting) return;
    // 확인을 기다리는 결과가 있으면 마이크는 움직이지 않습니다.
    // "맞아요"와 "다시 말할래요" 둘 중 하나로만 진행합니다.
    if (_stage == _VoiceStage.confirming) return;
    if (_stage == _VoiceStage.recording) {
      await _stopAndTranscribe();
      return;
    }
    try {
      final bool allowed = await _recorder.start();
      if (!mounted) return;
      if (!allowed) {
        setState(() {
          _stage = _VoiceStage.error;
          _errorMessage = '마이크 권한을 허용하면 목소리를 들을 수 있어요.';
        });
        return;
      }
      setState(() {
        _stage = _VoiceStage.recording;
        _recordingSeconds = 0;
        _errorMessage = null;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _stage == _VoiceStage.recording) {
          setState(() => _recordingSeconds++);
          // 업로드 한도(10MB, 웹 48kHz 기준 109초) 전에 끊는다.
          if (_recordingSeconds >= maxRecordingSeconds) {
            unawaited(_stopAndTranscribe());
          }
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _stage = _VoiceStage.error;
        _errorMessage = '마이크를 켜지 못했어요. 잠시 후 다시 눌러 주세요.';
      });
    }
  }

  Future<void> _stopAndTranscribe() async {
    _recordingTimer?.cancel();
    setState(() => _stage = _VoiceStage.transcribing);
    try {
      final Uint8List? audio = await _recorder.stop();
      if (audio == null || audio.isEmpty) {
        throw StateError('empty audio');
      }
      final String transcript = (await widget.transcribeAudio(audio)).trim();
      if (!mounted) return;
      if (transcript.isEmpty) {
        // 빈 결과를 답으로 앉히면 눈금만 차고 내용은 없습니다.
        throw StateError('empty transcript');
      }
      // 아직 [_answers] 에 넣지 않습니다. 아이가 맞다고 해야 들어갑니다.
      setState(() {
        _pendingTranscript = transcript;
        _stage = _VoiceStage.confirming;
        _errorMessage = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _stage = _VoiceStage.error;
        _errorMessage = '목소리를 잘 듣지 못했어요. 다시 한번 말해 주세요.';
      });
    }
  }

  /// 아이가 "맞아요"를 눌렀습니다. 이제서야 답으로 앉히고 다음 생각으로
  /// 넘어갑니다 - 넘어가는 것은 확인 뒤여야 합니다.
  void _acceptTranscript() {
    final String? pending = _pendingTranscript;
    if (pending == null || _prompts.isEmpty || widget.submitting) return;
    final _MissionPrompt prompt =
        _prompts[_activeIndex.clamp(0, _prompts.length - 1)];
    setState(() {
      _answers[prompt.key] = pending;
      _pendingTranscript = null;
      _stage = _VoiceStage.ready;
      _errorMessage = null;
      final int next = _prompts.indexWhere(
        (item) => _answers[item.key]?.isNotEmpty != true,
      );
      if (next >= 0) _activeIndex = next;
    });
  }

  /// 아이가 다르게 들렸다고 했습니다. 결과를 버리고 **곧바로 다시 녹음**합니다 -
  /// 마이크를 한 번 더 누르게 하면 아이가 흐름을 놓칩니다. 대화 화면의
  /// "다시 말할래요"와 같은 동작입니다.
  Future<void> _retryTranscript() async {
    if (_pendingTranscript == null || widget.submitting) return;
    setState(() {
      _pendingTranscript = null;
      _stage = _VoiceStage.ready;
      _errorMessage = null;
    });
    await _toggleRecording();
  }

  void _submit() {
    // 확인을 기다리는 말이 남아 있으면 보내지 않습니다 - 여기서 보내면 방금
    // 다시 말한 내용이 조용히 사라집니다.
    if (_pendingTranscript != null) return;
    if (!_allAnswered || widget.submitting) return;
    final String result = _prompts
        .map((prompt) => '${prompt.title}: ${_answers[prompt.key]}')
        .join('. ');
    widget.onSubmit(result);
  }

  String _questionGuide(String key) => switch (key) {
    'tool' => '그림 속 도구를 살펴보고 무엇을 사용할지 말해 주세요.',
    'safety' => '왜 그 방법이면 안전하게 받을 수 있는지 말해 주세요.',
    'request' => '며느리에게 어떤 말로 부탁할지 직접 말해 보세요.',
    'expectedResult' => '그 방법을 쓰면 어떤 일이 생길지 상상해 보세요.',
    _ => '정답은 없어요. 떠오르는 생각을 편하게 말해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE0122942),
      child: SafeArea(
        minimum: const EdgeInsets.all(14),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            child: widget.completed
                ? const _MissionCompleteCard(key: ValueKey<String>('done'))
                : _MissionBoard(
                    key: const ValueKey<String>('mission'),
                    mission: widget.mission,
                    prompts: _prompts,
                    answers: _answers,
                    activeIndex: _activeIndex,
                    stage: _stage,
                    recordingSeconds: _recordingSeconds,
                    errorMessage: _errorMessage,
                    pendingTranscript: _pendingTranscript,
                    allAnswered: _allAnswered,
                    submitting: widget.submitting,
                    onPromptSelected: (int index) {
                      // 확인 중에는 생각을 갈아타지 못하게 합니다 - 갈아타면
                      // 방금 말한 것이 엉뚱한 칸에 들어갑니다.
                      if (_stage == _VoiceStage.recording ||
                          _stage == _VoiceStage.confirming) {
                        return;
                      }
                      setState(() {
                        _activeIndex = index;
                        _stage = _VoiceStage.ready;
                        _errorMessage = null;
                      });
                    },
                    onMic: _toggleRecording,
                    onAccept: _acceptTranscript,
                    onRetry: _retryTranscript,
                    onSubmit: _submit,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MissionPrompt {
  const _MissionPrompt({
    required this.key,
    required this.title,
    required this.guide,
  });

  final String key;
  final String title;
  final String guide;
}

class _MissionBoard extends StatelessWidget {
  const _MissionBoard({
    required this.mission,
    required this.prompts,
    required this.answers,
    required this.activeIndex,
    required this.stage,
    required this.recordingSeconds,
    required this.errorMessage,
    required this.pendingTranscript,
    required this.allAnswered,
    required this.submitting,
    required this.onPromptSelected,
    required this.onMic,
    required this.onAccept,
    required this.onRetry,
    required this.onSubmit,
    super.key,
  });

  final PlayMission mission;
  final List<_MissionPrompt> prompts;
  final Map<String, String> answers;
  final int activeIndex;
  final _VoiceStage stage;
  final int recordingSeconds;
  final String? errorMessage;
  final String? pendingTranscript;
  final bool allAnswered;
  final bool submitting;
  final ValueChanged<int> onPromptSelected;
  final VoidCallback onMic;
  final VoidCallback onAccept;
  final VoidCallback onRetry;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final _MissionPrompt prompt = prompts.isEmpty
        ? const _MissionPrompt(key: 'empty', title: '자유롭게 생각해 봐요', guide: '')
        : prompts[activeIndex.clamp(0, prompts.length - 1)];
    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1240, maxHeight: 790),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DF),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFFFD26A), width: 4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 42,
            offset: Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _MissionHeader(
            mission: mission,
            answered: answers.length,
            total: prompts.length,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 850;
                final Widget artwork = _MissionArtwork(
                  mission: mission,
                  prompts: prompts,
                  activeIndex: activeIndex,
                );
                final Widget voice = _VoiceMissionPanel(
                  prompts: prompts,
                  prompt: prompt,
                  answers: answers,
                  activeIndex: activeIndex,
                  stage: stage,
                  recordingSeconds: recordingSeconds,
                  errorMessage: errorMessage,
                  pendingTranscript: pendingTranscript,
                  allAnswered: allAnswered,
                  submitting: submitting,
                  onPromptSelected: onPromptSelected,
                  onMic: onMic,
                  onAccept: onAccept,
                  onRetry: onRetry,
                  onSubmit: onSubmit,
                );
                if (compact) {
                  return ListView(
                    padding: const EdgeInsets.all(14),
                    children: <Widget>[
                      SizedBox(height: 340, child: artwork),
                      const SizedBox(height: 14),
                      voice,
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: 7, child: artwork),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: voice),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({
    required this.mission,
    required this.answered,
    required this.total,
  });

  final PlayMission mission;
  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double progress = total == 0 ? 0 : answered / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 15),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFFFD65B), Color(0xFFFFB84E)],
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFF7047),
              size: 31,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '이야기 속 생각 미션',
                  style: TextStyle(
                    color: Color(0xFF75471D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  mission.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF34261D),
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '$answered / $total 생각 모음',
                  style: const TextStyle(
                    color: Color(0xFF684318),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF3EA77B),
                  backgroundColor: Colors.white70,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionArtwork extends StatelessWidget {
  const _MissionArtwork({
    required this.mission,
    required this.prompts,
    required this.activeIndex,
  });

  final PlayMission mission;
  final List<_MissionPrompt> prompts;
  final int activeIndex;

  String? get _storyAsset => switch (mission.missionId) {
    'mission_1' => 'assets/images/missions/banggui_mission_1.png',
    'mission_2' => 'assets/images/missions/banggui_mission_2.png',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2DFC1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD9B879), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: _storyAsset != null
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.asset(_storyAsset!, fit: BoxFit.contain),
                Positioned(
                  left: 14,
                  top: 14,
                  child: _ArtworkBadge(
                    label: mission.missionType == PlayMissionType.problemSolving
                        ? '그림을 보고 방법을 만들어 봐요'
                        : '친구의 특징을 새롭게 바라봐요',
                  ),
                ),
              ],
            )
          : _GenericMissionArtwork(prompts: prompts, activeIndex: activeIndex),
    );
  }
}

class _ArtworkBadge extends StatelessWidget {
  const _ArtworkBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xEB173653),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white70),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.visibility_rounded,
            color: Color(0xFFFFD762),
            size: 20,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenericMissionArtwork extends StatelessWidget {
  const _GenericMissionArtwork({
    required this.prompts,
    required this.activeIndex,
  });

  final List<_MissionPrompt> prompts;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(18),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: prompts.length,
      itemBuilder: (BuildContext context, int index) {
        final bool active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: <Color>[
              const Color(0xFFFFE28A),
              const Color(0xFFAEDCFA),
              const Color(0xFFBEE3A3),
              const Color(0xFFD5B8F1),
            ][index % 4],
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? const Color(0xFFFF7047) : Colors.white,
              width: active ? 5 : 2,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                prompts[index].title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF283D50),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoiceMissionPanel extends StatelessWidget {
  const _VoiceMissionPanel({
    required this.prompts,
    required this.prompt,
    required this.answers,
    required this.activeIndex,
    required this.stage,
    required this.recordingSeconds,
    required this.errorMessage,
    required this.pendingTranscript,
    required this.allAnswered,
    required this.submitting,
    required this.onPromptSelected,
    required this.onMic,
    required this.onAccept,
    required this.onRetry,
    required this.onSubmit,
  });

  final List<_MissionPrompt> prompts;
  final _MissionPrompt prompt;
  final Map<String, String> answers;
  final int activeIndex;
  final _VoiceStage stage;
  final int recordingSeconds;
  final String? errorMessage;
  final String? pendingTranscript;
  final bool allAnswered;
  final bool submitting;
  final ValueChanged<int> onPromptSelected;
  final VoidCallback onMic;
  final VoidCallback onAccept;
  final VoidCallback onRetry;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final String? answer = answers[prompt.key];
    final bool busy = stage == _VoiceStage.transcribing || submitting;
    final String? pending = pendingTranscript;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF173653),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF6FCFB2), width: 2),
      ),
      child: Column(
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List<Widget>.generate(prompts.length, (int index) {
              final bool done = answers[prompts[index].key]?.isNotEmpty == true;
              final bool active = index == activeIndex;
              return Semantics(
                button: true,
                selected: active,
                label: '${index + 1}번째 생각${done ? ', 완료' : ''}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => onPromptSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF72D6B7)
                          : active
                          ? const Color(0xFFFFD45E)
                          : Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : Icons.mic_rounded,
                      color: done || active
                          ? const Color(0xFF173653)
                          : Colors.white70,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Text(
            '${activeIndex + 1}번째 생각',
            style: const TextStyle(
              color: Color(0xFFFFD45E),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            prompt.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          // 확인 중에는 안내 문장을 접습니다. 아이가 읽어야 할 것은 "무엇을
          // 말할까"가 아니라 "내가 방금 뭐라고 했나" 하나뿐입니다.
          if (pending == null)
            Text(
              prompt.guide,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB8DBD4),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          const Spacer(),
          if (pending != null)
            _TranscriptConfirm(
              transcript: pending,
              busy: submitting,
              onAccept: onAccept,
              onRetry: onRetry,
            )
          else ...<Widget>[
            if (answer != null && stage != _VoiceStage.recording)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FFF9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.format_quote_rounded,
                      color: Color(0xFF3BA47A),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        answer,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF244159),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFB29A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _VoiceWave(active: stage == _VoiceStage.recording),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: stage == _VoiceStage.recording ? '말하기 완료' : '눌러서 말하기',
              child: InkWell(
                onTap: busy ? null : onMic,
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: stage == _VoiceStage.recording
                        ? const Color(0xFFFF6F59)
                        : const Color(0xFF72D6B7),
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color:
                            (stage == _VoiceStage.recording
                                    ? const Color(0xFFFF6F59)
                                    : const Color(0xFF72D6B7))
                                .withValues(alpha: .45),
                        blurRadius: 20,
                        spreadRadius: stage == _VoiceStage.recording ? 6 : 2,
                      ),
                    ],
                  ),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(
                            color: Color(0xFF173653),
                            strokeWidth: 4,
                          ),
                        )
                      : Icon(
                          stage == _VoiceStage.recording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: const Color(0xFF173653),
                          size: 48,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              switch (stage) {
                _VoiceStage.recording =>
                  '듣고 있어요 · $recordingSeconds초\n말을 마치면 다시 눌러 주세요',
                _VoiceStage.transcribing => '목소리에서 생각을 찾고 있어요...',
                _ => answer == null ? '마이크를 누르고 편하게 말해요' : '다시 말하려면 마이크를 눌러요',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
          const Spacer(),
          // 확인 중에는 전달 버튼을 감춥니다. 여기서 눌리면 방금 다시 말한
          // 내용이 확정되기 전에 통째로 나갑니다.
          if (pending == null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: allAnswered
                  ? SizedBox(
                      key: const ValueKey<String>('submit'),
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : onSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB84E),
                          foregroundColor: const Color(0xFF3B291B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          submitting ? '이야기에 전하고 있어요...' : '내 생각을 이야기에 전하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      '생각 ${answers.length}개를 모았어요 · ${prompts.length - answers.length}개 남음',
                      key: const ValueKey<String>('progress'),
                      style: const TextStyle(
                        color: Color(0xFF8FE5CA),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// 이 생각에 대해 방금 들은 말을 보여 주고, 맞는지 묻습니다.
///
/// 글을 못 읽는 아이도 있으므로 문구에만 기대지 않습니다 - 큰 버튼 두 개를
/// 색과 아이콘(체크/새로고침)으로 갈라 둡니다. 대화 화면의 확인 카드와 같은
/// 모양이라 아이가 화면마다 다른 규칙을 배우지 않아도 됩니다.
///
/// 아이가 한 말은 자르지 않습니다. 길게 말했으면 카드 안에서 굴리고, 버튼
/// 두 개는 어떤 경우에도 남습니다.
class _TranscriptConfirm extends StatelessWidget {
  const _TranscriptConfirm({
    required this.transcript,
    required this.busy,
    required this.onAccept,
    required this.onRetry,
  });

  final String transcript;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '이렇게 들었어요: $transcript. 맞으면 맞아요를 누르세요.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FFF9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF72D6B7), width: 3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  '이렇게 들었어요',
                  style: TextStyle(
                    color: Color(0xFF2F8F6B),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 138),
                  child: SingleChildScrollView(
                    child: Text(
                      transcript,
                      style: const TextStyle(
                        color: Color(0xFF244159),
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF72D6B7),
                      foregroundColor: const Color(0xFF10314A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 23),
                    label: const _ConfirmButtonLabel('맞아요'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onRetry,
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
                    icon: const Icon(Icons.refresh_rounded, size: 23),
                    label: const _ConfirmButtonLabel('다시 말할래요'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 확인 버튼 글자. 미션 패널은 대화 화면보다 좁아서 "다시 말할래요"가 두 줄로
/// 접힙니다 - 접힌 버튼은 아이 눈에 두 개의 다른 것처럼 보입니다. 좁으면
/// 글자를 줄여서라도 **한 줄로** 둡니다.
class _ConfirmButtonLabel extends StatelessWidget {
  const _ConfirmButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _VoiceWave extends StatelessWidget {
  const _VoiceWave({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(9, (int index) {
        final double height = active ? 10 + ((index * 13) % 25) : 5;
        return AnimatedContainer(
          duration: Duration(milliseconds: 180 + index * 15),
          curve: Curves.easeInOut,
          width: 5,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFD45E) : Colors.white24,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _MissionCompleteCard extends StatelessWidget {
  const _MissionCompleteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 44),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DF),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: const Color(0xFFFFD05A), width: 4),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.stars_rounded, color: Color(0xFFFFB629), size: 94),
          SizedBox(height: 12),
          Text(
            '생각 미션 성공!',
            style: TextStyle(
              color: Color(0xFF3A2B26),
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '네 목소리가 다음 이야기를 움직였어요',
            style: TextStyle(
              color: Color(0xFF765A4C),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
