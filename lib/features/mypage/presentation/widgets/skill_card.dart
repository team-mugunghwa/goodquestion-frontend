import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/report_detail.dart';

/// 어휘 · 표현 · 논리를 가로 탭으로 전환하는 역량 분석 묶음.
///
/// ## 왜 아코디언 대신 탭인가
///
/// 예전에는 세 카드를 세로로 쌓고 각각 접었다 펼 수 있었습니다. 탭으로
/// 바꾼 이유는 같습니다 — **한 번에 하나의 역량만 보여서 정보 과밀을
/// 막는 것.** 세 카드가 동시에 펼쳐지는 상태 자체가 없으므로, 첫 탭은
/// 기본으로 열어 둡니다. 탭을 누르는 순간 이전 탭의 내용은 사라집니다.
///
/// ## 5단 순서를 재배열하지 마세요
///
/// 역량명(탭 라벨) → 이번 활동의 특징 → 근거 발화 → **잘한 점** → 보완할 부분.
/// 잘한 점이 보완보다 먼저 오는 건 PRD F-09 의 규칙입니다. 순서를 바꾸면
/// 같은 내용이 "지적"으로 읽힙니다.
class SkillTabs extends StatefulWidget {
  const SkillTabs({super.key, required this.skills});

  final List<SkillReport> skills;

  @override
  State<SkillTabs> createState() => _SkillTabsState();
}

class _SkillTabsState extends State<SkillTabs> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<SkillReport> skills = widget.skills;
    if (skills.isEmpty) return const SizedBox.shrink();
    final SkillReport skill = skills[_selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < skills.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SkillTabButton(
                  label: skills[i].name,
                  selected: i == _selected,
                  onTap: () => setState(() => _selected = i),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.ink100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(skill.feature, style: text.bodyMedium),
              if (skill.askedWords.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _Block(
                  title: ReportDetailStrings.askedWords,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final String word in skill.askedWords)
                        Chip(label: Text(word)),
                    ],
                  ),
                ),
              ],
              if (skill.evidence.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _Block(
                  title: ReportDetailStrings.evidence,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final String line in skill.evidence)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          // 아이 말은 우리 문장과 글꼴로 구분합니다.
                          child: Text('"$line"', style: AppTypography.quote),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _Block(
                title: ReportDetailStrings.strength,
                child: Text(skill.strength, style: text.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.md),
              _Block(
                title: ReportDetailStrings.improvement,
                child: Text(skill.improvement, style: text.bodyMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkillTabButton extends StatelessWidget {
  const _SkillTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: selected ? AppColors.brandBlueSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tapGuardian),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.brandBlueDeep : AppColors.ink100,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: text.titleMedium?.copyWith(
              color: selected ? AppColors.brandBlueDeep : AppColors.ink500,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
