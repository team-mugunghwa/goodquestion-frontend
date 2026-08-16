import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../domain/usecases/helpdesk_use_cases.dart';
import '../viewmodels/helpdesk_view_models.dart';
import '../widgets/helpdesk_widgets.dart';

class NoticeDetailPage extends StatelessWidget {
  const NoticeDetailPage({super.key, required this.noticeId});

  final String noticeId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoticeDetailViewModel>(
      create: (_) =>
          NoticeDetailViewModel(getIt<GetNoticeUseCase>(), noticeId)..load(),
      child: const NoticeDetailView(),
    );
  }
}

class NoticeDetailView extends StatelessWidget {
  const NoticeDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final NoticeDetailViewModel vm = context.watch<NoticeDetailViewModel>();
    final TextTheme text = Theme.of(context).textTheme;

    return GuardianScaffold(
      title: '공지사항',
      onBack: () => context.pop(),
      child: switch (vm.state) {
        ViewState.idle || ViewState.loading => const AppLoadingView(),
        ViewState.error => AppErrorView(
          message: vm.errorMessage,
          onRetry: () => context.read<NoticeDetailViewModel>().load(),
        ),
        ViewState.success => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: <Widget>[
            Row(
              children: <Widget>[
                HelpdeskBadge(label: vm.notice!.category.label),
                const Spacer(),
                Text(
                  formatDate(vm.notice!.publishedAt),
                  style: text.bodySmall?.copyWith(color: AppColors.ink500),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(vm.notice!.title, style: text.headlineLarge),
            const SizedBox(height: AppSpacing.lg),
            HelpdeskCard(
              // 관리자가 쓴 줄바꿈을 그대로 살립니다. 문단을 다시 짜면 뜻이 달라집니다.
              child: SelectableText(
                vm.notice!.content ?? '',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      },
    );
  }
}
