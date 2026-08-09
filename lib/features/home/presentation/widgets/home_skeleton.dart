import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import 'home_metrics.dart';

/// 로딩 중 카드가 들어올 자리를 미리 잡아 두는 회색 블록.
///
/// 스피너 하나로 채우지 않는 이유: 데이터가 도착하는 순간 화면이 통째로
/// 다시 그려지면 아이가 눌러야 할 것이 갑자기 움직입니다. **자리를 먼저
/// 잡아 두면** 이어하기 버튼의 위치가 로딩 전후로 바뀌지 않습니다.
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

/// 홈 본문(섹션2~4)의 골격.
///
/// 실제 콘텐츠와 **같은 순서·같은 여백**이어야 합니다. 모양이 다르면
/// 데이터가 도착할 때 화면이 덜컹거립니다.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key, required this.metrics});

  final HomeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.lg,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 섹션2 — 이어하기 카드
          SkeletonBox(
            aspectRatio: metrics.isWide ? 21 / 9 : 4 / 5,
            borderRadius: AppRadius.xl,
          ),
          SizedBox(height: metrics.sectionGap),
          // 섹션3 — 추천
          const SkeletonBox(width: 220, height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.lg),
          if (metrics.isWide)
            const Row(
              children: <Widget>[
                Expanded(
                  child: SkeletonBox(
                    aspectRatio: 3 / 4,
                    borderRadius: AppRadius.xl,
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: SkeletonBox(
                    aspectRatio: 3 / 4,
                    borderRadius: AppRadius.xl,
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: SkeletonBox(
                    aspectRatio: 3 / 4,
                    borderRadius: AppRadius.xl,
                  ),
                ),
              ],
            )
          else
            const Column(
              children: <Widget>[
                SkeletonBox(aspectRatio: 16 / 6, borderRadius: AppRadius.xl),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(aspectRatio: 16 / 6, borderRadius: AppRadius.xl),
              ],
            ),
          SizedBox(height: metrics.sectionGap),
          // 섹션4 — 행성 위젯
          const SkeletonBox(
            height: AppSizes.tapChildPrimary + AppSpacing.xl,
            borderRadius: AppRadius.xl,
          ),
        ],
      ),
    );
  }
}
