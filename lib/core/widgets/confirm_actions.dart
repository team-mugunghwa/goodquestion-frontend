import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 확인 다이얼로그의 버튼 줄. **두 선택지를 대등하게** 놓습니다.
///
/// 기본 `actions`(OverflowBar)는 취소를 오른쪽 위에 작은 텍스트 버튼으로
/// 흘려 두고 확인만 채워진 버튼으로 강조합니다 — 취소가 "잘못 놓인 것"처럼
/// 보이고, 되돌리기 어려운 동작(로그아웃·삭제)일수록 그 기울기가 위험합니다.
/// 같은 너비로 한 줄에 묶고 취소를 [OutlinedButton] 으로 세우면 둘 다
/// "고를 수 있는 것"으로 읽힙니다.
///
/// 확인 다이얼로그를 새로 만들 때는 [dialogPadding] 을 `actionsPadding` 에
/// 함께 넘기세요 — 기본 여백은 이 줄을 가장자리에 붙여 놓습니다.
///
/// ```dart
/// AlertDialog(
///   title: const Text('로그아웃할까요?'),
///   actionsPadding: ConfirmActions.dialogPadding,
///   actions: <Widget>[
///     ConfirmActions(
///       cancelLabel: '취소',
///       confirmLabel: '로그아웃',
///       onCancel: () => Navigator.of(context).pop(false),
///       onConfirm: () => Navigator.of(context).pop(true),
///     ),
///   ],
/// )
/// ```
class ConfirmActions extends StatelessWidget {
  const ConfirmActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.danger = false,
    super.key,
  });

  final String cancelLabel;
  final String confirmLabel;

  /// null 이면 비활성입니다(예: 처리 중).
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  /// 지우기처럼 **되돌릴 수 없는** 동작. 확인 버튼이 경고색이 됩니다.
  ///
  /// 빨강은 보호자 화면에서만 씁니다 — 아이 화면에 실패·경고색을 쓰지
  /// 않는다는 원칙 때문입니다. (`docs/DESIGN_SYSTEM.md` 3장)
  final bool danger;

  /// 이 줄을 쓸 때 다이얼로그가 함께 넘기는 `actionsPadding`.
  static const EdgeInsets dialogPadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    0,
    AppSpacing.md,
    AppSpacing.md,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(onPressed: onCancel, child: Text(cancelLabel)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton(
            onPressed: onConfirm,
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
