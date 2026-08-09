import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/auth_options.dart';
import '../viewmodels/auth_view_model.dart';
import 'shake.dart';

/// 스텝 2 — 동의.
///
/// **아동 개인정보 수집은 서비스 약관과 별도 항목**입니다. 하나로 묶어
/// "전체 동의"만 남기면 안 됩니다 — 별도 동의를 받았다는 기록이 필요합니다.
/// (PRD F-01)
class ConsentStep extends StatelessWidget {
  const ConsentStep({
    super.key,
    required this.vm,
    required this.options,
    required this.shakeTrigger,
    required this.onOpenDocument,
  });

  final AuthViewModel vm;
  final AuthOptions options;

  /// 필수 항목 미체크로 버튼을 눌렀을 때 바뀌는 값.
  final Object? shakeTrigger;

  final void Function(ConsentItem item) onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: <Widget>[
              Text(AuthStrings.consentTitle, style: text.headlineLarge),
              const SizedBox(height: AppSpacing.lg),
              // ListTile 계열을 쓰지 않습니다 — AppCanvas 의 DecoratedBox 가
              // 배경을 칠하고 있어서 잉크 효과가 가려진다고 프레임워크가
              // 단언을 던집니다. 개별 항목과 같은 모양의 Row 로 맞춥니다.
              _CheckRow(
                label: AuthStrings.consentAll,
                checked: vm.isAllAgreed,
                onChanged: vm.toggleAll,
                style: text.bodyLarge,
              ),
              const Divider(),
              Shake(
                trigger: shakeTrigger,
                child: Column(
                  children: <Widget>[
                    for (final ConsentItem item in options.consents)
                      _ConsentRow(
                        item: item,
                        checked: vm.agreed.contains(item.id),
                        onChanged: () => vm.toggleConsent(item.id),
                        onView: () => onOpenDocument(item),
                      ),
                  ],
                ),
              ),
              if (!vm.canContinueConsent) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AuthStrings.consentMissing,
                  style: text.bodySmall?.copyWith(color: AppColors.ink500),
                ),
              ],
            ],
          ),
        ),
        // 하단 고정. 스크롤과 무관하게 항상 보입니다.
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            // 비활성으로 두지 않습니다 — 왜 못 누르는지 모르는 회색 버튼보다,
            // 눌리되 어디가 빠졌는지 흔들어 보여 주는 편이 빠릅니다.
            onPressed: vm.submitConsents,
            child: const Text(AuthStrings.consentContinue),
          ),
        ),
      ],
    );
  }
}

/// 체크박스 + 누를 수 있는 라벨. 라벨을 눌러도 체크됩니다 —
/// 작은 사각형만 정확히 눌러야 하면 손이 큰 사람이 짜증납니다.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.style,
    this.trailing,
  });

  final String label;
  final bool checked;
  final VoidCallback onChanged;
  final TextStyle? style;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Checkbox(value: checked, onChanged: (_) => onChanged()),
        Expanded(
          child: GestureDetector(
            onTap: onChanged,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(label, style: style),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.item,
    required this.checked,
    required this.onChanged,
    required this.onView,
  });

  final ConsentItem item;
  final bool checked;
  final VoidCallback onChanged;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String suffix = item.required
        ? AuthStrings.consentRequired
        : AuthStrings.consentOptional;

    return _CheckRow(
      label: '${item.title} ($suffix)',
      checked: checked,
      onChanged: onChanged,
      style: text.bodyMedium,
      trailing: item.docUrl == null
          ? null
          : TextButton(
              onPressed: onView,
              child: const Text(AuthStrings.consentView),
            ),
    );
  }
}
