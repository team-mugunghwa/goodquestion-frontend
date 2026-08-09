import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/auth_options.dart';
import '../viewmodels/auth_view_model.dart';

/// 스텝 3 — 최초 아이 프로필 등록.
///
/// **여기를 건너뛰는 경로를 만들지 않습니다.** 아이 프로필이 없으면 발화·
/// 단어장·리포트를 귀속시킬 데가 없어서 서비스가 성립하지 않습니다.
///
/// 나이는 타이핑 대신 버튼으로 받습니다 — 보호자가 폰으로 가입하는 상황에서
/// 숫자 키패드를 여는 것만으로도 이탈이 생깁니다.
class ChildProfileStep extends StatelessWidget {
  const ChildProfileStep({super.key, required this.vm, required this.options});

  final AuthViewModel vm;
  final AuthOptions options;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool busy = vm.isSubmitting;

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
              Text(AuthStrings.childTitle, style: text.headlineLarge),
              const SizedBox(height: AppSpacing.xl),
              Text(AuthStrings.childName, style: text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                decoration: const InputDecoration(
                  hintText: AuthStrings.childNameHint,
                ),
                enabled: !busy,
                textInputAction: TextInputAction.done,
                onChanged: vm.setChildName,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(AuthStrings.childAge, style: text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final int age in options.ages)
                    _AgeChip(
                      age: age,
                      selected: vm.childAge == age,
                      onSelected: busy ? null : () => vm.setChildAge(age),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            // 아직 입력하지 않은 걸 "틀렸다"고 하지 않습니다.
            // 에러가 아니라 비활성입니다.
            onPressed: vm.canStart && !busy ? vm.submitChild : null,
            child: busy
                ? const SizedBox.square(
                    dimension: AppSpacing.lg,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surface,
                    ),
                  )
                : const Text(AuthStrings.start),
          ),
        ),
      ],
    );
  }
}

class _AgeChip extends StatelessWidget {
  const _AgeChip({
    required this.age,
    required this.selected,
    required this.onSelected,
  });

  final int age;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(AuthStrings.ageLabel(age)),
      selected: selected,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
      // 터치 타겟을 보호자 기준(48)까지 올립니다. 칩 기본값은 더 작습니다.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }
}
