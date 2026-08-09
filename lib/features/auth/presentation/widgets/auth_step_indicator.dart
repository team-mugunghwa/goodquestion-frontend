import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// ● ● ○ — 지금 몇 번째 스텝인지.
///
/// 가입은 세 단계를 연달아 밟는 흐름이라, **끝이 보여야** 중간에 안 나갑니다.
/// 점만으로는 스크린리더가 아무것도 못 읽으므로 [Semantics] 로 문장을 답니다.
class AuthStepIndicator extends StatelessWidget {
  const AuthStepIndicator({super.key, required this.current, this.total = 3});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AuthStrings.stepOf(current, total),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 1; i <= total; i++) ...<Widget>[
            if (i > 1) const SizedBox(width: AppSpacing.xs),
            Container(
              width: AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= current
                    ? AppColors.brandBlueDeep
                    : AppColors.ink300,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
