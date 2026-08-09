import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// 누르면 살짝 줄어드는 터치 영역.
///
/// 아이 화면의 카드는 리플(잉크 번짐)로는 눌린 걸 알기 어렵습니다 — 손가락이
/// 카드를 거의 다 덮기 때문입니다. **면 전체가 줄었다 돌아오는** 편이 훨씬
/// 분명합니다. (`AppDurations.tap` = 눌린 느낌)
///
/// `GestureDetector` 대신 [InkWell] 위에 얹은 이유는 포커스 링·키보드 조작·
/// 시맨틱스를 공짜로 얻기 위해서입니다. (`docs/DESIGN_SYSTEM.md` 12장)
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.borderRadius,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;

  /// 눌림 하이라이트·포커스 링이 카드 모서리와 어긋나지 않도록 같은 값을 주세요.
  final double borderRadius;

  /// `null` 이면 눌리지 않습니다. (스켈레톤·비활성 카드)
  final VoidCallback? onTap;

  /// 스크린리더가 읽을 이름. 카드 안 텍스트로 충분하면 생략하세요.
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  /// 더 줄이면 카드가 "흔들리는" 것처럼 보이고, 덜 줄이면 눌린 걸 못 느낍니다.
  static const double _pressedScale = 0.97;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(widget.borderRadius);
    return AnimatedScale(
      scale: _pressed ? _pressedScale : 1,
      duration: respect(context, AppDurations.tap),
      curve: AppCurves.standard,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (bool value) {
            if (_pressed == value) return;
            setState(() => _pressed = value);
          },
          borderRadius: radius,
          // 크기 변화로 이미 눌린 걸 알려 주므로 잉크는 끕니다.
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          // 마우스 호버로 면 전체가 물들면 "선택됨"처럼 보입니다. 특히 하단
          // 내비에서 활성 탭과 구분이 안 됩니다. 포커스 링만 남깁니다.
          hoverColor: Colors.transparent,
          focusColor: AppColors.brandBlueSurface,
          child: Semantics(
            button: widget.onTap != null,
            label: widget.semanticLabel,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
