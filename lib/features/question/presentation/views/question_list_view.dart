import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/usecases/get_questions_use_case.dart';
import '../viewmodels/question_list_view_model.dart';
import '../widgets/question_card.dart';
import 'question_detail_panel.dart';

/// 질문 목록 화면의 진입점.
///
/// ViewModel 은 여기서 화면 단위로 생성합니다. 화면을 나가면 자동으로
/// `dispose` 됩니다. **습관적으로 전역 Provider 에 올리지 마세요.**
class QuestionListPage extends StatelessWidget {
  const QuestionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          QuestionListViewModel(getIt<GetQuestionsUseCase>())..load(),
      child: const _QuestionListScaffold(),
    );
  }
}

class _QuestionListScaffold extends StatelessWidget {
  const _QuestionListScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 좁은 화면에서는 워드마크가 길어 잘리므로 Q마크만 보여줍니다.
        title: ResponsiveLayout(
          compact: (_) => const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogoMark(size: 28),
              SizedBox(width: AppSpacing.sm),
              Text('질문'),
            ],
          ),
          // 워드마크가 2줄 락업(1024×366)이라 26px면 글자가 너무 작습니다.
          // AppBar 기본 높이 56 안에서 36이 최대치에 가깝습니다.
          medium: (_) => const AppLogo(height: 36),
        ),
      ),
      body: SafeArea(
        // 폭에 따라 "늘리는" 게 아니라 "레이아웃을 바꿉니다".
        child: ResponsiveLayout(
          compact: (_) => const _QuestionListBody(),
          expanded: (_) => const _QuestionSplitBody(),
        ),
      ),
    );
  }
}

/// 폰: 목록만. 항목을 탭하면 상세 화면으로 이동.
class _QuestionListBody extends StatelessWidget {
  const _QuestionListBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuestionListViewModel>();

    // ViewState 하나로 분기합니다. sealed enum 이라 빠뜨린 경우가 있으면
    // 컴파일러가 잡아 줍니다.
    return switch (vm.state) {
      ViewState.idle || ViewState.loading => const AppLoadingView(),
      ViewState.error => AppErrorView(
        message: vm.errorMessage,
        onRetry: context.read<QuestionListViewModel>().refresh,
      ),
      ViewState.success when vm.isEmpty => const AppEmptyView(
        message: '아직 등록된 질문이 없습니다.',
      ),
      ViewState.success => RefreshIndicator(
        onRefresh: context.read<QuestionListViewModel>().refresh,
        child: ContentContainer(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: vm.questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final question = vm.questions[index];
              return QuestionCard(
                question: question,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(),
                      body: QuestionDetailPanel(question: question),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    };
  }
}

/// 태블릿/iPad: 목록 + 상세 2단.
///
/// 넓은 화면에서 목록만 늘리면 한 줄이 지나치게 길어져 읽기 나쁩니다.
/// 남는 폭은 상세를 함께 보여주는 데 씁니다.
class _QuestionSplitBody extends StatelessWidget {
  const _QuestionSplitBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuestionListViewModel>();

    if (vm.isLoading) return const AppLoadingView();
    if (vm.state.isError) {
      return AppErrorView(
        message: vm.errorMessage,
        onRetry: context.read<QuestionListViewModel>().refresh,
      );
    }
    if (vm.isEmpty) {
      return const AppEmptyView(message: '아직 등록된 질문이 없습니다.');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: vm.questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final question = vm.questions[index];
              return QuestionCard(
                question: question,
                isSelected: vm.selected == question,
                onTap: () =>
                    context.read<QuestionListViewModel>().select(question),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ContentContainer(
            child: QuestionDetailPanel(question: vm.selected),
          ),
        ),
      ],
    );
  }
}
