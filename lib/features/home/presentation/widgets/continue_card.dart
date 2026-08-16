import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../domain/entities/in_progress_session.dart';
import 'home_hero_card.dart';

/// 섹션2 — 이어하기. 홈에서 **가장 큰 면적**을 쓰는 히어로입니다.
///
/// 이 화면의 성패가 여기 걸려 있습니다. 진행 중인 이야기가 있는 아이에게
/// 다른 선택지가 이어하기보다 먼저 눈에 들어오면 완주율이 새어 나갑니다.
///
/// 껍데기(표지 전폭 배경 + 글자 오버레이 + 버튼)는 [HomeHeroCard] 가 갖고
/// 있습니다. 여기서 정하는 것은 **무엇을 얹을지**뿐입니다 — 이어보던 표식,
/// 이야기 제목, 어디까지 했는지.
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
    return HomeHeroCard(
      metrics: metrics,
      image: session.storyImage,
      storyTitle: session.storyTitle,
      eyebrowIcon: AppIcons.play,
      eyebrowLabel: HomeStrings.resumeBadge,
      detail: _Progress(session: session, metrics: metrics),
      actionIcon: AppIcons.play,
      actionLabel: HomeStrings.resume,
      onTap: onResume,
    );
  }
}

/// "●●●○○ 3번째 장면까지 했어요"
///
/// 진행률을 퍼센트나 막대로 주지 않는 이유: 저학년은 "60%"를 자기 이야기의
/// 위치로 바꿔 읽지 못합니다. **셀 수 있는 점**이 훨씬 빠릅니다.
///
/// 점과 글자는 표지 사진 위에 얹히므로 전부 흰색 계열입니다
/// ([HomeHeroCard.onCover]). 잉크색으로 두면 밝은 표지에서 사라집니다.
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
            // 점도 Wrap 입니다. 폰에서는 점 열 개와 라벨이 한 줄에 못 서서
            // 라벨이 아래로 내려옵니다. 줄이 나뉘어도 세는 데는 지장이 없습니다.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (int i = 0; i < session.totalScenes; i++)
                  _Dot(done: i < session.lastCompletedScene),
              ],
            ),
          Text(
            label,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: HomeHeroCard.onCover),
          ),
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
      // 아직 안 한 장면도 "빈 자리"로 보여야 해서 지우지 않고 흐리게 둡니다.
      // 사진 위라 회색([AppColors.ink300])을 쓰면 표지 색에 따라 사라졌다
      // 나타났다 합니다 — 같은 흰색의 농도로만 구분합니다.
      color: done
          ? HomeHeroCard.onCover
          : HomeHeroCard.onCover.withValues(alpha: 0.40),
    ),
  );
}
