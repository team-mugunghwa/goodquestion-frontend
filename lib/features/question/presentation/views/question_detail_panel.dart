import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../domain/entities/question.dart';

/// 질문 상세 내용.
///
/// 폰에서는 별도 화면으로, 태블릿에서는 2단 레이아웃의 오른쪽 패널로
/// **같은 위젯을 재사용**합니다. 화면을 두 벌 만들지 않습니다.
class QuestionDetailPanel extends StatelessWidget {
  const QuestionDetailPanel({super.key, required this.question});

  final Question? question;

  @override
  Widget build(BuildContext context) {
    final q = question;
    if (q == null) {
      return const AppEmptyView(
        message: '왼쪽에서 질문을 선택하세요.',
        icon: Icons.touch_app_outlined,
      );
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${q.authorName} · ${_formatDate(q.createdAt)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Divider(height: AppSpacing.xl),
          Text(q.content, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  // 날짜 포맷이 여러 곳에서 필요해지면 core/utils 로 옮기고,
  // 다국어가 필요해지면 intl 패키지를 도입하세요.
  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')}';
}
