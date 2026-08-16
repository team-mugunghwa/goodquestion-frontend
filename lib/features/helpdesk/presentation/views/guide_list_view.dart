import 'package:flutter/material.dart';
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

/// 이용 안내.
///
/// 아코디언으로 만든 이유: 문서가 짧고 제목만 훑다가 필요한 것 하나를 펼치는
/// 화면입니다. 목록 -> 상세로 나누면 뒤로 가기를 반복하게 됩니다.
class GuideListPage extends StatelessWidget {
  const GuideListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GuideListViewModel>(
      create: (_) => GuideListViewModel(getIt<GetGuidesUseCase>())..load(),
      child: const GuideListView(),
    );
  }
}

class GuideListView extends StatelessWidget {
  const GuideListView({super.key});

  @override
  Widget build(BuildContext context) {
    final GuideListViewModel vm = context.watch<GuideListViewModel>();
    final TextTheme text = Theme.of(context).textTheme;

    return GuardianScaffold(
      title: '이용 안내',
      onBack: () => popOrGo(context, AppRoutes.settings),
      child: switch (vm.state) {
        ViewState.idle || ViewState.loading => const AppLoadingView(),
        ViewState.error => AppErrorView(
          message: vm.errorMessage,
          onRetry: () => context.read<GuideListViewModel>().load(),
        ),
        ViewState.success =>
          vm.guides.isEmpty
              ? const AppEmptyView(
                  message: '아직 등록된 안내가 없습니다.',
                  icon: AppIcons.guide,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  children: <Widget>[
                    for (final MapEntry<GuideCategory, List<Guide>> entry
                        in vm.grouped.entries) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xs,
                          AppSpacing.lg,
                          0,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          entry.key.label,
                          style: text.titleMedium?.copyWith(
                            color: AppColors.ink700,
                          ),
                        ),
                      ),
                      HelpdeskCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (final Guide guide in entry.value)
                              _GuideTile(guide: guide),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
      },
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Theme(
      // ExpansionTile 기본 구분선이 카드 테두리와 겹쳐 두 줄로 보입니다.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(guide.title, style: text.bodyMedium),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(
            guide.content,
            style: text.bodyMedium?.copyWith(color: AppColors.ink700),
          ),
        ],
      ),
    );
  }
}
