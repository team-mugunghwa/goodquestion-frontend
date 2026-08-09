import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/report_detail.dart';

/// 역량 카드 하나. 접으면 특징 + 잘한 점, 펼치면 근거 발화 + 보완할 부분.
///
/// ## 5단 순서를 재배열하지 마세요
///
/// 역량명 → 이번 활동의 특징 → 근거 발화 → **잘한 점** → 보완할 부분.
/// 잘한 점이 보완보다 먼저 오는 건 PRD F-09 의 규칙입니다. 순서를 바꾸면
/// 같은 내용이 "지적"으로 읽힙니다.
///
/// 기본을 접힌 상태로 두는 건 정보 과밀 방지입니다 — 세 카드가 전부 펼쳐져
/// 있으면 보호자가 어디부터 읽을지 모릅니다.
class SkillCard extends StatefulWidget {
  const SkillCard({super.key, required this.skill});

  final SkillReport skill;

  @override
  State<SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<SkillCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final SkillReport skill = widget.skill;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ink100),
      ),
      child: ExpansionTile(
        // ExpansionTile 의 기본 화살표·패딩을 쓰되, 테두리는 지웁니다 —
        // 카드가 이미 테두리를 갖고 있어 두 겹이 됩니다.
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        onExpansionChanged: (bool value) => setState(() => _expanded = value),
        title: Text(skill.name, style: text.titleLarge),
        subtitle: _expanded
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  skill.strength,
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(skill.feature, style: text.bodyMedium),
          ),
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
