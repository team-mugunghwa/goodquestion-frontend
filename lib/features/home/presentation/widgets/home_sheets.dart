import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../domain/entities/child_profile.dart';
import 'home_metrics.dart';

/// 아이 프로필 전환 모달(모달 6)을 여는 자리.
///
/// **홈은 분기 렌더만 담당합니다.** 어떤 아이가 있고 어떻게 고르는지는
/// 모달 6 의 몫이라, 여기서는 호출 지점과 "닫으면 홈으로 돌아온다"는 계약만
/// 만들어 둡니다. 모달 6 가 만들어지면 이 함수 안의 위젯만 바뀝니다.
///
/// 반환값이 `true` 면 아이가 바뀐 것이므로 호출한 쪽이 홈 데이터를 다시
/// 불러옵니다.
Future<bool> showChildSwitchSheet(
  BuildContext context, {
  required HomeMetrics metrics,
  ChildProfile? current,
}) async {
  final bool? switched = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => _KidSheet(
      title: HomeStrings.switchChildTitle,
      metrics: metrics,
      children: <Widget>[
        if (current != null)
          Text(current.name, style: metrics.text(AppTypography.kidBody)),
        const SizedBox(height: AppSpacing.lg),
        KidPrimaryButton(
          icon: AppIcons.close,
          label: HomeStrings.close,
          labelStyle: metrics.text(AppTypography.kidButton),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return switched ?? false;
}

/// 아이 프로필이 없는 계정이 이야기에 들어가려 할 때. (PRD F-01 게이트)
///
/// 홈에 들어오는 것 자체를 막지 않습니다 — 무엇을 하는 앱인지 보여 준 다음,
/// **행동하려는 순간에만** 프로필 생성으로 보냅니다. 처음부터 막으면 아이는
/// 이 앱이 뭔지도 모른 채 로그인 화면만 봅니다.
Future<void> showProfileNeededSheet(
  BuildContext context, {
  required HomeMetrics metrics,
  required VoidCallback onCreate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => _KidSheet(
      title: HomeStrings.profileNeededTitle,
      metrics: metrics,
      children: <Widget>[
        KidPrimaryButton(
          icon: AppIcons.childProfile,
          label: HomeStrings.profileNeededAction,
          labelStyle: metrics.text(AppTypography.kidButton),
          onPressed: () {
            Navigator.of(context).pop();
            onCreate();
          },
        ),
      ],
    ),
  );
}

/// 아이용 시트의 공통 뼈대. 캐릭터가 말을 걸고, 선택지는 하나뿐입니다.
class _KidSheet extends StatelessWidget {
  const _KidSheet({
    required this.title,
    required this.metrics,
    required this.children,
  });

  final String title;
  final HomeMetrics metrics;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.screenPadding,
          AppSpacing.md,
          metrics.screenPadding,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              AppAssets.logoMark,
              width: AppSizes.illustration,
              height: AppSizes.illustration,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.bubbleMaxWidth,
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: metrics.text(AppTypography.kidTitle),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}
