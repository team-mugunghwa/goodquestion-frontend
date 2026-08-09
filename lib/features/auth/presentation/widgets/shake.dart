import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';

/// [trigger] 가 바뀔 때 좌우로 한 번 흔들립니다.
///
/// 필수 동의를 안 한 채 버튼을 눌렀을 때 **어디를 봐야 하는지** 알려 주는
/// 용도입니다. 빨간 글씨를 띄우는 것보다 시선이 정확히 그리로 갑니다.
///
/// "동작 줄이기" 설정에서는 흔들지 않습니다 — 전정기관이 예민한 사람에게
/// 흔들림은 불쾌합니다. 그 경우에도 문구는 그대로 뜨므로 정보는 안 사라집니다.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  /// 값이 바뀔 때마다 한 번 흔듭니다.
  final Object? trigger;

  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  static const double _amplitude = 8;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.quick,
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger != null) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // 0 → 1 사이에서 두 번 왕복하고 진폭이 줄어듭니다.
        final double t = _controller.value;
        final double offset = _amplitude * (1 - t) * math.sin(t * math.pi * 4);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}
