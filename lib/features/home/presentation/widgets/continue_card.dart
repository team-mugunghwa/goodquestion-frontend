import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../domain/entities/in_progress_session.dart';
import 'home_metrics.dart';
import 'story_thumbnail.dart';

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
  final HomeMetrics metrics;
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.lift,
        ),
        // 폭이 넓으면 카드를 늘리는 게 아니라 **가로로 눕힙니다.**
        // 태블릿에서 16:9 이미지를 전폭으로 깔면 이미지만으로 화면이 찹니다.
        child: metrics.isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(flex: 5, child: _Thumbnail(session: session)),
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
                  _Thumbnail(session: session),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.session});

  final InProgressSession session;

  @override
  Widget build(BuildContext context) =>
      StoryThumbnail(image: session.storyImage, fallbackIcon: AppIcons.stories);
}

class _Body extends StatelessWidget {
  const _Body({
    required this.session,
    required this.metrics,
    required this.onResume,
  });

  final InProgressSession session;
  final HomeMetrics metrics;
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
  final HomeMetrics metrics;

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
