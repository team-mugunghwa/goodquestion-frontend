import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/in_progress_session.dart';

/// 섹션2 — 이어하기 카드. **화면에서 가장 큰 면적**을 차지합니다.
///
/// 이 화면의 성패가 여기 걸려 있습니다. 진행 중인 이야기가 있는 아이에게
/// 다른 선택지가 이어하기보다 먼저 눈에 들어오면 완주율이 새어 나갑니다.
/// 그래서 이 카드만 [AppShadows.lift] 로 한 겹 더 띄우고, 추천·행성은
/// [AppShadows.soft] 로 바닥에 둡니다.
///
/// 카드 전체와 버튼이 **같은 곳**으로 갑니다 — 아이가 어디를 눌러도 됩니다.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.session,
    required this.metrics,
    required this.onResume,
  });

  final InProgressSession session;
  final ScreenMetrics metrics;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onResume,
      borderRadius: AppRadius.xl,
      semanticLabel: '${session.storyTitle} ${HomeStrings.resume}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // 위는 순수 흰색, 아래로 갈수록 아주 옅은 브랜드 파랑 —
          // 로고의 부풀어 오른 3D 말풍선처럼 카드에 미세한 입체감을 줍니다.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.surface,
              Color.alphaBlend(AppColors.brandBlueSurface, AppColors.surface),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: <BoxShadow>[
            // 브랜드 파랑을 넓게 깐 앰비언트. 기존 lift 그림자 위에 색을 더해
            // 카드가 낮 배경에서 또렷하게 떠오른 온도감을 냅니다.
            BoxShadow(
              color: AppColors.brandBlue.withValues(alpha: 0.28),
              blurRadius: 48,
              offset: const Offset(0, 22),
            ),
            ...AppShadows.lift,
          ],
        ),
        // 폭이 넓으면 카드를 늘리는 게 아니라 **가로로 눕힙니다.**
        // 태블릿에서 16:9 이미지를 전폭으로 깔면 이미지만으로 화면이 찹니다.
        child: metrics.isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: _Thumbnail(session: session, metrics: metrics),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _Body(
                        session: session,
                        metrics: metrics,
                        onResume: onResume,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Thumbnail(session: session, metrics: metrics),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _Body(
                      session: session,
                      metrics: metrics,
                      onResume: onResume,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 이어하기 카드의 대표 이미지 자리.
///
/// 표지는 주제별 코드 표지([StoryCover])가 [StoryThumbnail] 안에서 그려집니다.
/// 여기서는 그 위에 **상태 뱃지**(레퍼런스의 "학습중" 자리)만 얹습니다.
/// 진행 중 세션에는 주제 정보가 없어 브랜드 기본 표지로 뜹니다.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.session, required this.metrics});

  final InProgressSession session;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        StoryThumbnail(
          image: session.storyImage,
          fallbackIcon: AppIcons.stories,
          title: session.storyTitle,
        ),
        // 상태 뱃지 — 행동(버튼)이 아니라 표식이라 흰 알약에 브랜드 파랑으로.
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.md,
          child: _StatusBadge(metrics: metrics),
        ),
      ],
    );
  }
}

/// "이어보던 이야기" 상태 표식. 흰 알약 + 브랜드 파랑.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            AppIcons.play,
            size: AppSizes.iconInline,
            color: AppColors.brandBlueDeep,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            HomeStrings.resumeBadge,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.brandBlueDeep),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.session,
    required this.metrics,
    required this.onResume,
  });

  final InProgressSession session;
  final ScreenMetrics metrics;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          session.storyTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: metrics.text(AppTypography.kidTitle),
        ),
        const SizedBox(height: AppSpacing.md),
        _Progress(session: session, metrics: metrics),
        const SizedBox(height: AppSpacing.lg),
        KidPrimaryButton(
          icon: AppIcons.play,
          label: HomeStrings.resume,
          labelStyle: metrics.text(AppTypography.kidButton),
          onPressed: onResume,
        ),
      ],
    );
  }
}

/// "●●●○○ 3번째 장면까지 했어요"
///
/// 진행률을 퍼센트나 막대로 주지 않는 이유: 저학년은 "60%"를 자기 이야기의
/// 위치로 바꿔 읽지 못합니다. **셀 수 있는 점**이 훨씬 빠릅니다.
class _Progress extends StatelessWidget {
  const _Progress({required this.session, required this.metrics});

  /// 이 개수를 넘으면 점이 너무 작아져서 세는 의미가 없어집니다.
  static const int _maxDots = 10;

  final InProgressSession session;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final String label = HomeStrings.sceneProgress(session.lastCompletedScene);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (session.totalScenes <= _maxDots)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < session.totalScenes; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == session.totalScenes - 1 ? 0 : AppSpacing.sm,
                    ),
                    child: _Dot(done: i < session.lastCompletedScene),
                  ),
              ],
            ),
          Text(label, style: metrics.text(AppTypography.kidLabel)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpacing.md,
    height: AppSpacing.md,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done ? AppColors.brandBlueDeep : AppColors.ink300,
    ),
  );
}
