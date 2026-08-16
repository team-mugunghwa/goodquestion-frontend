import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/router/pop_or_go.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../domain/entities/helpdesk.dart';
import '../../domain/usecases/helpdesk_use_cases.dart';
import '../viewmodels/helpdesk_view_models.dart';
import '../widgets/helpdesk_widgets.dart';

/// 고객센터 — 내 문의 목록.
///
/// 답변이 등록되면 알림이 오고, 그 알림을 누르면 이 목록이 아니라 문의 상세로
/// 바로 들어옵니다(관리자 콘솔이 알림에 경로를 실어 보냅니다).
class InquiryListPage extends StatelessWidget {
  const InquiryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InquiryListViewModel>(
      create: (_) => InquiryListViewModel(getIt<GetInquiriesUseCase>())..load(),
      child: const InquiryListView(),
    );
  }
}

class InquiryListView extends StatelessWidget {
  const InquiryListView({super.key});

  @override
  Widget build(BuildContext context) {
    final InquiryListViewModel vm = context.watch<InquiryListViewModel>();

    return GuardianScaffold(
      title: '고객센터',
      onBack: () => popOrGo(context, AppRoutes.settings),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            // 문의를 쓰고 돌아오면 목록이 새 문의를 보여줘야 합니다.
            onPressed: () async {
              await context.push(AppRoutes.inquiryNew);
              if (context.mounted) {
                await context.read<InquiryListViewModel>().load();
              }
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('문의하기'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: switch (vm.state) {
              ViewState.idle || ViewState.loading => const AppLoadingView(),
              ViewState.error => AppErrorView(
                message: vm.errorMessage,
                onRetry: () => context.read<InquiryListViewModel>().load(),
              ),
              ViewState.success =>
                vm.inquiries.isEmpty
                    ? const AppEmptyView(
                        message: '아직 문의하신 내용이 없습니다.',
                        icon: AppIcons.support,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        itemCount: vm.inquiries.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int index) =>
                            _InquiryRow(inquiry: vm.inquiries[index]),
                      ),
            },
          ),
        ],
      ),
    );
  }
}

class _InquiryRow extends StatelessWidget {
  const _InquiryRow({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool answered = inquiry.answered;

    return InkWell(
      onTap: () => context.push(AppRoutes.inquiryDetailOf(inquiry.id)),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: HelpdeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                HelpdeskBadge(
                  label: answered ? '답변 완료' : inquiry.status.label,
                  color: answered ? AppColors.success : AppColors.ink500,
                  background: answered
                      ? const Color(0x1A387C4C)
                      : AppColors.ink100,
                ),
                const SizedBox(width: AppSpacing.sm),
                HelpdeskBadge(label: inquiry.category.label),
                const Spacer(),
                Text(
                  formatDate(inquiry.createdAt),
                  style: text.bodySmall?.copyWith(color: AppColors.ink500),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              inquiry.title,
              style: text.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
