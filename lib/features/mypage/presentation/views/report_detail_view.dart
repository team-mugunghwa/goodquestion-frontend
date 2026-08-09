import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/report_detail.dart';
import '../../domain/usecases/my_page_use_cases.dart';
import '../viewmodels/report_detail_view_model.dart';
import '../widgets/skill_card.dart';

/// 보호자 리포트 상세 — 서비스의 교육적 결과물을 보호자가 처음 만나는 화면.
///
/// ## 톤 자체가 제품입니다
///
/// 잘한 점 먼저, 단정적 부정 표현 금지, 내부 태그(DECISION·REASON) 미노출.
/// 더미 텍스트 단계에서부터 지킵니다 — 여기에 "REASON 태그 충족" 같은 문구가
/// 들어가는 순간 실패입니다. (PRD F-09)
///
/// | 섹션 | 내용 |
/// |---|---|
/// | 1 | 헤더 — 뒤로 · 제목 · 아이·이야기·일시 |
/// | 2 | 세션 요약 밴드 — 썸네일 + 한 줄 총평 |
/// | 3 | 역량 분석 — 어휘 · 표현 · 논리 (가로 탭) |
/// | 4 | 대표 발화 + 선정 이유 |
/// | 5 | 가정 연계 질문 (복사 가능) |
/// | 6 | 하단 "목록으로" |
///
/// **대표 발화에 음성 재생 버튼을 두지 않습니다** — 음성 원본을 저장하지
/// 않는 게 정책입니다.
class ReportDetailPage extends StatelessWidget {
  const ReportDetailPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportDetailViewModel>(
      create: (_) => ReportDetailViewModel(
        getIt<GetReportDetailUseCase>(),
        sessionId: int.tryParse(sessionId) ?? 0,
      )..load(),
      child: const ReportDetailView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class ReportDetailView extends StatelessWidget {
  const ReportDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final ReportDetailViewModel vm = context.watch<ReportDetailViewModel>();
    final ReportDetail? report = vm.report;

    return GuardianScaffold(
      title: ReportDetailStrings.title,
      subtitle: report == null ? null : _subtitle(report),
      // 딥링크로 들어왔어도 목록으로 보냅니다 — 뒤로 갈 곳이 없어서
      // 앱 밖으로 튕기는 것보다 낫습니다.
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.report),
      child: _body(context, vm),
    );
  }

  String _subtitle(ReportDetail report) {
    final DateTime? at = report.completedAt;
    final String date = at == null ? '' : ' · ${at.month}/${at.day}';
    return '${report.childName} · ${report.storyTitle}$date';
  }

  Widget _body(BuildContext context, ReportDetailViewModel vm) {
    if (vm.state.isError) {
      return _Centered(
        message: vm.errorMessage ?? ReportDetailStrings.loadFailed,
        primaryLabel: null,
        onRetry: vm.load,
        onGoList: () => context.go(AppRoutes.report),
      );
    }
    if (!vm.state.isSuccess) return const _Skeleton();

    final ReportDetail? report = vm.report;
    if (report == null) {
      // 완주 직후라 아직 분석이 안 끝난 경우. 빈 화면으로 방치하지 않습니다.
      return _Centered(
        message: ReportDetailStrings.pending,
        primaryLabel: ReportDetailStrings.goToList,
        onRetry: vm.load,
        onGoList: () => context.go(AppRoutes.report),
      );
    }
    return _Content(report: report);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.report});

  final ReportDetail report;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: <Widget>[
        // 섹션2 — 총평이 최상단입니다. 보호자가 스크롤을 끝까지 안 내려도
        // "아이가 잘했다"는 인상을 먼저 받아야 합니다.
        _SummaryBand(report: report),
        const SizedBox(height: AppSpacing.xl),
        Text(ReportDetailStrings.skills, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        SkillTabs(skills: report.skills),
        const SizedBox(height: AppSpacing.xl),
        Text(ReportDetailStrings.highlight, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _HighlightCard(highlight: report.highlight),
        const SizedBox(height: AppSpacing.xl),
        Text(ReportDetailStrings.questions, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final QuestionGroup group in report.questionGroups) ...<Widget>[
          _QuestionGroupBlock(group: group),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.report),
          child: const Text(ReportDetailStrings.goToList),
        ),
      ],
    );
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.report});

  final ReportDetail report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            child: Text(
              report.summary,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// 대화(원문 발화)와 선정 이유를 한 카드로 묶습니다. 이번 세션에서 고른
/// 단 하나의 발화라서, 다른 섹션보다 눈에 띄어야 합니다 — 그래서 흰
/// 카드가 아니라 브랜드 톤 면 + 진한 테두리를 씁니다.
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.highlight});

  final ReportHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandBlueSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.brandBlueDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 아이 말은 우리 문장과 글꼴로 구분합니다. (AppTypography.quote)
          Text('"${highlight.utterance}"', style: AppTypography.quote),
          const SizedBox(height: AppSpacing.sm),
          Divider(
            height: 1,
            color: AppColors.brandBlueDeep.withValues(alpha: 0.2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${ReportDetailStrings.highlightReason}: ${highlight.reason}',
            style: text.bodySmall?.copyWith(color: AppColors.ink700),
          ),
        ],
      ),
    );
  }
}

/// 추천 질문 묶음. 각 질문 옆에 복사 버튼이 붙습니다 —
/// 보호자가 메신저로 옮겨 쓰기 쉬우라고 있는 기능입니다.
class _QuestionGroupBlock extends StatelessWidget {
  const _QuestionGroupBlock({required this.group});

  final QuestionGroup group;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(group.title, style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final String question in group.questions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: Text('· $question', style: text.bodyMedium)),
                IconButton(
                  onPressed: () => _copy(context, question),
                  icon: const Icon(AppIcons.copy),
                  iconSize: AppSizes.iconGuardian,
                  tooltip: ReportDetailStrings.copy,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String question) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: question));
    messenger.showSnackBar(
      const SnackBar(content: Text(ReportDetailStrings.copied)),
    );
  }
}

/// 에러와 "아직 만들고 있어요"가 같은 뼈대를 씁니다. 둘 다 **목록으로
/// 나가는 문**을 함께 줍니다.
class _Centered extends StatelessWidget {
  const _Centered({
    required this.message,
    required this.primaryLabel,
    required this.onRetry,
    required this.onGoList,
  });

  final String message;

  /// `null` 이면 "다시 시도"가 주 버튼이 됩니다.
  final String? primaryLabel;
  final VoidCallback onRetry;
  final VoidCallback onGoList;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center, style: text.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: primaryLabel == null ? onRetry : onGoList,
              child: Text(primaryLabel ?? AppStrings.retry),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: primaryLabel == null ? onGoList : onRetry,
              child: Text(
                primaryLabel == null
                    ? ReportDetailStrings.goToList
                    : AppStrings.retry,
              ),
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
        const SkeletonBox(height: 96, borderRadius: AppRadius.md),
        const SizedBox(height: AppSpacing.xl),
        for (int i = 0; i < 3; i++) ...<Widget>[
          const SkeletonBox(height: 72, borderRadius: AppRadius.md),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
