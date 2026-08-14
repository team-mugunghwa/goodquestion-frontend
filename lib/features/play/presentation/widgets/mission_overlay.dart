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

enum _VoiceStage { ready, recording, transcribing, error }

class _MissionOverlayState extends State<MissionOverlay> {
  late final MissionVoiceRecorder _recorder;
  final Map<String, String> _answers = <String, String>{};
  Timer? _recordingTimer;
  int _activeIndex = 0;
  int _recordingSeconds = 0;
  _VoiceStage _stage = _VoiceStage.ready;
  String? _errorMessage;

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
      final String transcript = await widget.transcribeAudio(audio);
      if (!mounted) return;
      final _MissionPrompt prompt = _prompts[_activeIndex];
      setState(() {
        _answers[prompt.key] = transcript.trim();
        _stage = _VoiceStage.ready;
        _errorMessage = null;
        final int next = _prompts.indexWhere(
          (item) => _answers[item.key]?.isNotEmpty != true,
        );
        if (next >= 0) _activeIndex = next;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _stage = _VoiceStage.error;
        _errorMessage = '목소리를 잘 듣지 못했어요. 다시 한번 말해 주세요.';
      });
    }
  }

  void _submit() {
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
                    allAnswered: _allAnswered,
                    submitting: widget.submitting,
                    onPromptSelected: (int index) {
                      if (_stage == _VoiceStage.recording) return;
                      setState(() {
                        _activeIndex = index;
                        _stage = _VoiceStage.ready;
                        _errorMessage = null;
                      });
                    },
                    onMic: _toggleRecording,
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
    required this.allAnswered,
    required this.submitting,
    required this.onPromptSelected,
    required this.onMic,
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
  final bool allAnswered;
  final bool submitting;
  final ValueChanged<int> onPromptSelected;
  final VoidCallback onMic;
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
                  allAnswered: allAnswered,
                  submitting: submitting,
                  onPromptSelected: onPromptSelected,
                  onMic: onMic,
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
    required this.allAnswered,
    required this.submitting,
    required this.onPromptSelected,
    required this.onMic,
    required this.onSubmit,
  });

  final List<_MissionPrompt> prompts;
  final _MissionPrompt prompt;
  final Map<String, String> answers;
  final int activeIndex;
  final _VoiceStage stage;
  final int recordingSeconds;
  final String? errorMessage;
  final bool allAnswered;
  final bool submitting;
  final ValueChanged<int> onPromptSelected;
  final VoidCallback onMic;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final String? answer = answers[prompt.key];
    final bool busy = stage == _VoiceStage.transcribing || submitting;
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
          const Spacer(),
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
