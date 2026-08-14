import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dialogue_character_manifest.dart';
import 'dialogue_character_state_machine.dart';

/// 캐릭터 한 명을 그린다. 표정은 [state]로 갈아 끼우고, 그 위에 [activity]에 맞는 작은 모션을
/// 얹는다.
///
/// 정지 이미지 + 코드 모션 방식이다(콘텐츠 확정안). Rive·Spine 관절 애니메이션이 아니라
/// 호흡·고개 각도·상체 기울기를 좁은 범위로 조합한다. 아이가 보는 화면이라 움직임의 폭을
/// 넓히면 어지럽다 - 회전은 1도 안쪽, 이동은 캐릭터 높이의 1% 안쪽으로 묶어 둔다.
class DialogueCharacterStage extends StatefulWidget {
  const DialogueCharacterStage({
    super.key,
    required this.scene,
    required this.state,
    required this.activity,
    this.alignment = Alignment.bottomCenter,
  });

  final DialogueSceneStates scene;

  /// 표정 상태 키. 매니페스트에 없는 키면 아무것도 그리지 않는다.
  final String state;

  final DialogueActivity activity;
  final Alignment alignment;

  @override
  State<DialogueCharacterStage> createState() => _DialogueCharacterStageState();
}

class _DialogueCharacterStageState extends State<DialogueCharacterStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    // 3.4초 주기의 느린 호흡. 말하기 모션은 이 위상에 배수를 걸어 얹는다.
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? asset = widget.scene.assetOf(widget.state);
    if (asset == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _idle,
      builder: (BuildContext context, Widget? child) {
        final _Motion motion = _motionFor(widget.activity, _idle.value);
        return Transform.translate(
          offset: Offset(0, motion.lift),
          child: Transform.rotate(
            angle: motion.tilt,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scaleY: motion.breath,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      // 표정 교체. 크로스페이드만 쓴다 - 슬라이드나 스케일을 섞으면 같은 인물이 아니라
      // 다른 그림으로 갈아탄 것처럼 보인다.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: widget.alignment,
          children: <Widget>[...previous, if (current != null) current],
        ),
        child: Semantics(
          key: ValueKey<String>(asset),
          image: true,
          label: '${widget.scene.characterName} 캐릭터',
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            alignment: widget.alignment,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  _Motion _motionFor(DialogueActivity activity, double t) {
    final double breathPhase = math.sin(t * 2 * math.pi);
    switch (activity) {
      case DialogueActivity.idle:
        return _Motion(
          breath: 1 + breathPhase * .004,
          lift: breathPhase * -1.2,
          tilt: 0,
        );
      case DialogueActivity.listening:
        // 듣는 동안에는 느린 호흡에 아주 작은 정면 끄덕임을 더한다.
        final double nod = math.sin(t * 4 * math.pi);
        return _Motion(
          breath: 1 + breathPhase * .005,
          lift: breathPhase * -1.6 + nod * .8,
          tilt: 0,
        );
      case DialogueActivity.thinking:
        // 정면 눈맞춤을 유지한 채 고개만 살짝 기운다. 0.9도.
        return _Motion(
          breath: 1 + breathPhase * .003,
          lift: breathPhase * -1,
          tilt: math.sin(t * 2 * math.pi) * 0.016,
        );
      case DialogueActivity.speaking:
        // 말할 때의 작은 상체·손 강조. 호흡보다 빠르게 얹는다.
        final double beat = math.sin(t * 6 * math.pi);
        return _Motion(
          breath: 1 + beat * .006,
          lift: beat * -2.2,
          tilt: math.sin(t * 3 * math.pi) * 0.008,
        );
    }
  }
}

class _Motion {
  const _Motion({required this.breath, required this.lift, required this.tilt});

  /// 세로 스케일. 바닥을 고정해 키가 늘었다 줄었다 하는 호흡을 만든다.
  final double breath;

  /// 세로 이동(px).
  final double lift;

  /// 회전(rad).
  final double tilt;
}
