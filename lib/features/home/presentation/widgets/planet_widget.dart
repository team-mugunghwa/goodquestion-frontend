import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/stardust_chip.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/planet_summary.dart';

/// 섹션4 — 내 행성 미니 뷰.
///
/// **이어하기·추천보다 작아야 합니다.** 행성은 "다음 회차에 돌아올 이유"를
/// 상기시키는 장치이지 놀이 진입 유도가 아닙니다. 여기가 커지면 아이는
/// 말하기 대신 꾸미기를 하러 옵니다. (PRD F-08)
///
/// 그래서 이 카드만 한 줄이고, 썸네일은 원형 64 입니다.
class PlanetWidget extends StatelessWidget {
  const PlanetWidget({
    super.key,
    required this.planet,
    required this.metrics,
    required this.onTap,
  });

  final PlanetSummary planet;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel:
          '${HomeStrings.planetTitle} · '
          '${HomeStrings.stardust} ${planet.stardustBalance}개',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: <Widget>[
            _PlanetPreview(image: planet.thumbnailImage),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                HomeStrings.planetTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metrics.text(AppTypography.kidLabel),
              ),
            ),
            StardustChip.day(count: planet.stardustBalance),
            const SizedBox(width: AppSpacing.sm),
            Text(
              HomeStrings.planetAction,
              style: metrics
                  .text(AppTypography.kidLabel)
                  .copyWith(color: AppColors.brandBlueDeep),
            ),
            const Icon(
              AppIcons.chevronRight,
              size: AppSizes.iconInline,
              color: AppColors.brandBlueDeep,
            ),
          ],
        ),
      ),
    );
  }
}

/// 낮 카드 안의 **밤 미리보기** 원. 홈은 낮이지만, 행성은 밤 세계라
/// 여기만 작게 밤 하늘을 보여 줘서 "이따 갈 곳"을 예고합니다.
///
/// 서버가 행성 썸네일 이미지를 주면 그걸 먼저 씁니다. (지금은 코드로 그림)
class _PlanetPreview extends StatelessWidget {
  const _PlanetPreview({required this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.tapChildSecondary,
      height: AppSizes.tapChildSecondary,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          // 밤 원이 낮 카드 위에 살짝 떠 보이도록 옅은 차가운 글로우.
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: image != null
            ? StoryThumbnail(
                image: image,
                fallbackIcon: AppIcons.planet,
                aspectRatio: StoryThumbnail.square,
              )
            : const CustomPaint(painter: _NightPlanetPainter()),
      ),
    );
  }
}

class _NightPlanetPainter extends CustomPainter {
  const _NightPlanetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect rect = Offset.zero & size;

    // 밤 하늘.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.nightTop, AppColors.nightBottom],
        ).createShader(rect),
    );

    // 별 몇 개(흰빛). 노랑(별가루)이 아니라 배경 별이라 흰색입니다.
    final Paint star = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(w * 0.26, h * 0.24), w * 0.03, star);
    canvas.drawCircle(Offset(w * 0.70, h * 0.20), w * 0.022, star);
    canvas.drawCircle(Offset(w * 0.78, h * 0.44), w * 0.018, star);

    final Offset center = Offset(w * 0.52, h * 0.66);
    final double r = w * 0.3;

    // 행성 고리 — 본체 뒤에 먼저 그려 좌우로만 삐져나오게 합니다.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 3.0, height: r * 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = AppColors.brandMint.withValues(alpha: 0.85),
    );
    canvas.restore();

    // 행성 본체 — 파스텔 구. 살짝 아래쪽에 크게 앉힙니다.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: <Color>[AppColors.brandMint, AppColors.brandBlue],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_NightPlanetPainter oldDelegate) => false;
}
