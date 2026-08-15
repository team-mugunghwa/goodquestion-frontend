import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../domain/entities/helpdesk.dart';
import '../../domain/usecases/helpdesk_use_cases.dart';
import '../viewmodels/helpdesk_view_models.dart';
import '../widgets/helpdesk_widgets.dart';

/// 공지사항 목록.
///
/// 내용을 만드는 것은 관리자 콘솔입니다. 이 화면은 공개된 공지만 받아 보여줍니다.
class NoticeListPage extends StatelessWidget {
  const NoticeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoticeListViewModel>(
      create: (_) => NoticeListViewModel(getIt<GetNoticesUseCase>())..load(),
      child: const NoticeListView(),
    );
  }
}

class NoticeListView extends StatelessWidget {
  const NoticeListView({super.key});

  @override
  Widget build(BuildContext context) {
    final NoticeListViewModel vm = context.watch<NoticeListViewModel>();

    return GuardianScaffold(
      title: '공지사항',
      onBack: () => context.pop(),
      child: switch (vm.state) {
        ViewState.idle || ViewState.loading => const AppLoadingView(),
        ViewState.error => AppErrorView(
          message: vm.errorMessage,
          onRetry: () => context.read<NoticeListViewModel>().load(),
        ),
        ViewState.success =>
          vm.notices.isEmpty
              ? const AppEmptyView(
                  message: '아직 공지가 없습니다.',
                  icon: AppIcons.notice,
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: vm.notices.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) =>
                      _NoticeRow(notice: vm.notices[index]),
                ),
      },
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push(AppRoutes.noticeDetailOf(notice.id)),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: HelpdeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (notice.pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: HelpdeskBadge(
                      label: '중요',
                      color: AppColors.caution,
                      background: AppColors.cautionSurface,
                    ),
                  ),
                HelpdeskBadge(label: notice.category.label),
                const Spacer(),
                Text(
                  formatDate(notice.publishedAt),
                  style: text.bodySmall?.copyWith(color: AppColors.ink500),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(notice.title, style: text.titleMedium),
          ],
        ),
      ),
    );
  }
}
