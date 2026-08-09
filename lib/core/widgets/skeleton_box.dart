import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

/// 로딩 중 콘텐츠가 들어올 자리를 미리 잡아 두는 블록.
///
/// 스피너 하나로 채우지 않는 이유: 데이터가 도착하는 순간 화면이 통째로
/// 다시 그려지면 아이가 눌러야 할 것이 갑자기 움직입니다. **자리를 먼저
/// 잡아 두면** 버튼의 위치가 로딩 전후로 바뀌지 않습니다.
///
/// 화면의 스켈레톤은 실제 콘텐츠와 **같은 순서·같은 여백**으로 짜세요.
/// 모양이 다르면 데이터가 도착할 때 화면이 덜컹거립니다.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.aspectRatio,
    this.borderRadius = AppRadius.pill,
  });

  final double? width;
  final double? height;
  final double? aspectRatio;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.thinkingLoop,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "동작 줄이기" 를 켠 기기에서는 숨쉬기를 멈추고 가만히 있습니다.
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: SizedBox(width: widget.width, height: widget.height),
    );

    final Widget sized = widget.aspectRatio == null
        ? box
        : AspectRatio(aspectRatio: widget.aspectRatio!, child: box);

    if (!animate) return sized;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: AppCurves.standard),
      ),
      child: sized,
    );
  }
}

/// 카드 자리를 채우는 스켈레톤 목록. 그리드·세로 목록 화면에서 씁니다.
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({
    super.key,
    required this.count,
    this.aspectRatio,
    this.mainAxisExtent,
    this.columns = 1,
    this.gap = AppSpacing.lg,
  }) : assert(
         aspectRatio != null || mainAxisExtent != null,
         '비율이나 높이 중 하나는 줘야 합니다',
       );

  final int count;

  /// 셀의 가로세로 비. [mainAxisExtent] 를 주면 무시됩니다.
  final double? aspectRatio;

  /// 셀 높이를 직접 지정. 실제 카드 높이를 계산해서 쓰는 화면용입니다.
  final double? mainAxisExtent;

  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: aspectRatio ?? 1,
        mainAxisExtent: mainAxisExtent,
      ),
      itemBuilder: (BuildContext context, int index) =>
          const SkeletonBox(borderRadius: AppRadius.xl),
    );
  }
}
