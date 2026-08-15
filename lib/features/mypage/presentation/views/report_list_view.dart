import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/usecases/my_page_use_cases.dart';
import '../viewmodels/report_list_view_model.dart';

/// 보호자 리포트 목록 — 보호자 동선의 시작점.
///
/// ## 아이용 UI 규칙의 예외입니다
///
/// 보호자 전용이므로 그림·음성 우선이 아니라 **텍스트 중심의 성인용 정보
/// 밀도**로 갑니다. 단, 톤은 PRD 리포트 원칙(잘한 점 먼저, 단정적 부정 금지)과
/// 일관되게 유지합니다.
///
/// 헤더의 아이 이름은 **읽기 전용**입니다. 여기서 아이를 바꾸면 게이트 통과
/// 상태와 child_id 동기화가 꼬입니다 — 전환은 마이페이지의 몫입니다.
class ReportListPage extends StatelessWidget {
  const ReportListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportListViewModel>(
      create: (_) => ReportListViewModel(
        getIt<GetReportListUseCase>(),
        getIt<MarkReportAsReadUseCase>(),
      )..load(),
      child: const ReportListView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class ReportListView extends StatelessWidget {
  const ReportListView({super.key});

  @override
  Widget build(BuildContext context) {
    final ReportListViewModel vm = context.watch<ReportListViewModel>();
    final TextTheme text = Theme.of(context).textTheme;
    final String? childName = vm.list?.childName;

    return GuardianScaffold(
      title: ReportListStrings.title,
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.myPage),
      trailing: childName == null
          ? null
          : Text(
              ReportListStrings.childLabel(childName),
              style: text.bodySmall,
            ),
      child: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, ReportListViewModel vm) {
    if (vm.state.isError) {
      return AppErrorView(
        message: vm.errorMessage ?? ReportListStrings.loadFailed,
        onRetry: vm.load,
      );
    }
    if (!vm.state.isSuccess) return const _Skeleton();
    if (vm.isEmpty) {
      return _Empty(onGoHome: () => context.go(AppRoutes.home));
    }

    final ReportList list = vm.list!;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      // 첫 항목은 요약 스트립입니다.
      itemCount: list.reports.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              ReportListStrings.summary(list.totalCount, list.newCount),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final ReportSummary report = list.reports[index - 1];
        return _ReportCard(
          report: report,
          onTap: () => _open(context, vm, report),
        );
      },
    );
  }

  /// 배지를 먼저 지우고 이동합니다 — 상세를 보고 돌아왔는데 NEW 가 그대로면
  /// 무엇을 읽었는지 알 수 없습니다.
  Future<void> _open(
    BuildContext context,
    ReportListViewModel vm,
    ReportSummary report,
  ) async {
    await vm.markAsRead(report.sessionId);
    if (!context.mounted) return;
    unawaited(context.push(AppRoutes.reportDetailOf(report.sessionId)));
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final ReportSummary report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.ink100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: SizedBox.square(
                  dimension: AppSizes.tapChildSecondary,
                  child: StoryThumbnail(
                    image: report.storyImage,
                    fallbackIcon: AppIcons.stories,
                    aspectRatio: StoryThumbnail.square,
                    iconSize: AppSizes.iconGuardian,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            report.storyTitle,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (report.isNew) const _NewBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_subtitle(report), style: text.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '"${report.highlightUtterance}"',
                      style: text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "2회차 · 8월 8일 저녁"
  ///
  /// 회차가 없으면 같은 제목의 카드가 여러 장 쌓였을 때 보호자에게
  /// 중복으로 보입니다.
  String _subtitle(ReportSummary report) {
    final String round = ReportListStrings.playCount(report.playCount);
    final DateTime? at = report.completedAt;
    if (at == null) return round;
    return '$round · ${at.month}월 ${at.day}일';
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        // 빨강은 보호자 화면 전용입니다. 여기가 그 자리입니다.
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        ReportListStrings.badgeNew,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.surface),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              ReportListStrings.empty,
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onGoHome,
              child: const Text(ReportListStrings.goToHome),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: <Widget>[
        const SkeletonBox(width: 180, height: AppSpacing.lg),
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < 3; i++) ...<Widget>[
          const SkeletonBox(height: 110, borderRadius: AppRadius.md),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
