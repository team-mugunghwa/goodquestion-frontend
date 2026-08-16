import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../domain/entities/helpdesk.dart';
import '../../domain/usecases/helpdesk_use_cases.dart';
import '../viewmodels/helpdesk_view_models.dart';
import '../widgets/helpdesk_widgets.dart';

/// 문의 상세. **답변 알림을 누르면 도착하는 화면입니다.**
///
/// 관리자 콘솔이 알림에 `/support/{inquiryId}` 를 실어 보내므로 이 경로가
/// 바뀌면 이미 나간 알림이 갈 곳을 잃습니다.
class InquiryDetailPage extends StatelessWidget {
  const InquiryDetailPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InquiryDetailViewModel>(
      create: (_) =>
          InquiryDetailViewModel(getIt<GetInquiryUseCase>(), inquiryId)..load(),
      child: const InquiryDetailView(),
    );
  }
}

class InquiryDetailView extends StatelessWidget {
  const InquiryDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final InquiryDetailViewModel vm = context.watch<InquiryDetailViewModel>();

    return GuardianScaffold(
      title: '문의 내용',
      onBack: () => context.pop(),
      child: switch (vm.state) {
        ViewState.idle || ViewState.loading => const AppLoadingView(),
        ViewState.error => AppErrorView(
          message: vm.errorMessage,
          onRetry: () => context.read<InquiryDetailViewModel>().load(),
        ),
        ViewState.success => _Body(inquiry: vm.inquiry!),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        Row(
          children: <Widget>[
            HelpdeskBadge(label: inquiry.category.label),
            const Spacer(),
            Text(
              formatDate(inquiry.createdAt),
              style: text.bodySmall?.copyWith(color: AppColors.ink500),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(inquiry.title, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.lg),
        HelpdeskCard(
          child: SelectableText(inquiry.content ?? '', style: text.bodyMedium),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (inquiry.answer == null)
          HelpdeskCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '답변을 준비하고 있어요',
                  style: text.titleMedium?.copyWith(color: AppColors.ink700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '답변이 등록되면 알림으로 알려드립니다.',
                  style: text.bodySmall?.copyWith(color: AppColors.ink500),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              // 답변은 사용자가 이 화면에 온 이유입니다. 문의 본문과 다른 면으로
              // 구분해 눈이 먼저 가게 합니다.
              color: AppColors.brandBlueSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      inquiry.answer!.adminName,
                      style: text.titleMedium?.copyWith(
                        color: AppColors.brandBlueDeep,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatDate(inquiry.answer!.answeredAt),
                      style: text.bodySmall?.copyWith(color: AppColors.ink500),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(inquiry.answer!.content, style: text.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}
