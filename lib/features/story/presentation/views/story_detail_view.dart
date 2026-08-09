import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/kid_chips.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/speaker_button.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/story_detail.dart';
import '../../domain/usecases/get_story_detail_use_case.dart';
import '../../domain/usecases/start_story_session_use_case.dart';
import '../viewmodels/story_detail_view_model.dart';
import '../widgets/role_card.dart';

/// 이야기 상세 — 시작 전 준비, 그리고 세션 생성의 정문.
///
/// ## 이 화면이 하는 한 가지 일
///
/// **설득이 아니라 준비.** 정보를 많이 보여 주는 것보다, 아이가 자기 역할
/// 하나를 확실히 이해하고 넘어가게 하는 것이 완주율에 직결됩니다.
///
/// | 섹션 | 내용 |
/// |---|---|
/// | 1 | 상단 바 — 뒤로가기 + 제목 |
/// | 2 | 대표 비주얼 |
/// | 3 | 메타 칩 — 시간 · 난이도 · 주제 |
/// | 4 | 도입문 + "들려줘" |
/// | 5 | 내 역할 카드 |
/// | 6 | 하단 고정 "시작하기" |
///
/// **시작하기가 서비스 전체에서 세션이 생기는 유일한 지점**입니다.
/// 이어하기(홈)는 이 화면을 거치지 않고 바로 `/play` 로 복원됩니다.
class StoryDetailPage extends StatelessWidget {
  const StoryDetailPage({super.key, required this.storyId});

  /// 경로 파라미터는 문자열이라 숫자가 아닐 수 있습니다.
  /// `/stories/abc` 로 들어오면 0 이 되고, 화면은 "찾을 수 없어"로 갑니다.
  final String storyId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StoryDetailViewModel>(
      create: (_) => StoryDetailViewModel(
        getIt<GetStoryDetailUseCase>(),
        getIt<StartStorySessionUseCase>(),
        storyId: int.tryParse(storyId) ?? 0,
      )..load(),
      child: const StoryDetailView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class StoryDetailView extends StatelessWidget {
  const StoryDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final StoryDetailViewModel vm = context.watch<StoryDetailViewModel>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.day(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final ScreenMetrics metrics = ScreenMetrics.of(
                constraints.maxWidth,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _TopBar(title: vm.story?.title ?? '', metrics: metrics),
                  Expanded(child: _body(context, vm, metrics)),
                  // 섹션6 — 스크롤과 무관하게 항상 보이는 단일 CTA.
                  if (vm.story != null)
                    _StartBar(
                      metrics: metrics,
                      // 처리 중에는 null 을 넘겨 버튼을 잠급니다 —
                      // 두 번 누르면 세션이 두 개 생깁니다.
                      onStart: vm.isStarting ? null : () => _start(context, vm),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    StoryDetailViewModel vm,
    ScreenMetrics metrics,
  ) {
    if (vm.state.isError) {
      return AppKidErrorView(
        messageStyle: metrics.text(AppTypography.kidBody),
        onRetry: vm.load,
      );
    }
    if (!vm.state.isSuccess) return _Skeleton(metrics: metrics);

    final StoryDetail? story = vm.story;
    if (story == null) {
      // 없는 이야기입니다. "다시 불러오기"를 권하면 안 됩니다 —
      // 눌러도 영원히 안 나옵니다. 목록으로 보냅니다.
      return AppKidEmptyView(
        message: StoryDetailStrings.notFound,
        actionIcon: AppIcons.stories,
        actionLabel: StoryDetailStrings.goToList,
        messageStyle: metrics.text(AppTypography.kidBody),
        onAction: () => context.go(AppRoutes.stories),
      );
    }
    return _Content(story: story, metrics: metrics);
  }

  Future<void> _start(BuildContext context, StoryDetailViewModel vm) async {
    final int? sessionId = await vm.start();
    if (sessionId == null || !context.mounted) return;
    // go 입니다 — 세션이 시작된 뒤 뒤로가기로 상세에 돌아오면
    // "시작하기"를 또 누를 수 있게 됩니다.
    context.go(AppRoutes.playOf('$sessionId'));
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.metrics});

  final String title;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.sm,
        metrics.screenPadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          KidBackButton(
            labelStyle: metrics.text(AppTypography.kidLabel),
            // 목록에서 push 로 왔으면 pop, 주소로 바로 들어왔으면 목록으로.
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.stories),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metrics.text(AppTypography.kidTitle),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.story, required this.metrics});

  final StoryDetail story;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.sm,
        metrics.screenPadding,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 섹션2 — 그림이 먼저입니다. 아이는 글보다 분위기를 먼저 읽습니다.
          //
          // 다만 높이를 묶어 둡니다. 태블릿에서 16:9 를 전폭으로 깔면 커버
          // 하나가 화면을 다 먹고, 정작 중요한 역할 카드가 접히는 곳 아래로
          // 내려갑니다.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: SizedBox(
              height: metrics.isWide ? AppSizes.coverMaxHeight : null,
              child: StoryThumbnail(
                image: story.coverImage,
                fallbackIcon: AppIcons.stories,
                aspectRatio: metrics.isWide ? null : StoryThumbnail.wide,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // 섹션3 — 메타 칩. 주로 보호자가 보는 판단 정보라 작게 둡니다.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              KidInfoChip(
                icon: AppIcons.duration,
                label: AppStrings.minutes(story.estimatedMinutes),
                metrics: metrics,
              ),
              KidInfoChip(
                icon: AppIcons.difficulty,
                label: story.difficulty,
                metrics: metrics,
              ),
              for (final String topic in story.topics)
                KidInfoChip(
                  icon: AppIcons.topic,
                  label: topic,
                  metrics: metrics,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // 섹션4 — 도입문. 글자는 보조이고 "들려줘"가 본체입니다.
          _IntroCard(story: story, metrics: metrics),
          SizedBox(height: metrics.sectionGap),
          // 섹션5 — 내 역할.
          RoleCard(role: story.role, metrics: metrics),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.story, required this.metrics});

  final StoryDetail story;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.bubbleMaxWidth,
            ),
            child: Text(
              story.introText,
              style: metrics.text(AppTypography.kidBody),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.bubbleMaxWidth,
            ),
            child: Text(
              story.situationText,
              style: metrics.text(AppTypography.kidBody),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.center,
            child: SpeakerButton(
              audio: story.introAudio,
              semanticLabel: StoryDetailStrings.listen,
              label: StoryDetailStrings.listen,
              labelStyle: metrics.text(AppTypography.kidButton),
              size: AppSizes.tapChildPrimary,
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 고정 액션 바. 스크롤해도 "시작하기"가 사라지지 않습니다.
class _StartBar extends StatelessWidget {
  const _StartBar({required this.metrics, required this.onStart});

  final ScreenMetrics metrics;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.lift,
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: KidPrimaryButton(
          icon: AppIcons.play,
          label: StoryDetailStrings.start,
          labelStyle: metrics.text(AppTypography.kidButton),
          expand: true,
          onPressed: onStart,
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SkeletonBox(
            aspectRatio: StoryThumbnail.wide,
            borderRadius: AppRadius.xl,
          ),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(width: 240, height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(height: AppSizes.mic, borderRadius: AppRadius.xl),
          SizedBox(height: metrics.sectionGap),
          const SkeletonBox(
            height: AppSizes.illustration,
            borderRadius: AppRadius.xl,
          ),
        ],
      ),
    );
  }
}
