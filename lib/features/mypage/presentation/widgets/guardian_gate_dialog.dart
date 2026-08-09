import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 보호자 확인 게이트(모달 5)를 여는 자리.
///
/// **여기서 게이트를 설계하지 않습니다.** 실제 확인 방법(간단한 산수, 생년월일
/// 입력 등)은 모달 5 의 몫이고, 이 함수는 호출 지점과 "통과하면 true" 라는
/// 계약만 만들어 둡니다. 모달 5 가 확정되면 이 함수 안만 바뀝니다.
///
/// 아이에게 "여긴 어른 것"이라는 신호를 주는 게 게이트의 절반입니다 —
/// 그래서 방패 아이콘과 문구는 지금도 진짜처럼 둡니다.
Future<bool> showGuardianGateDialog(BuildContext context) async {
  final TextTheme text = Theme.of(context).textTheme;
  final bool? passed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(
        AppIcons.guardianGate,
        size: AppSizes.iconGuardian,
        color: AppColors.brandBlueDeep,
      ),
      title: Text(MyPageStrings.gateTitle, style: text.titleLarge),
      content: Text(MyPageStrings.gateBody, style: text.bodyMedium),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(MyPageStrings.gateCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(MyPageStrings.gateConfirm),
        ),
      ],
    ),
  );
  return passed ?? false;
}
