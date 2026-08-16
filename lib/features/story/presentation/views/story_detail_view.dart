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
/// | 3 | 메타 칩(시간·난이도·주제) + 소개 한 줄 — 보호자가 고를 때 보는 정보 |
/// | 4 | 도입문 + "들려줘" — 아이에게 읽어 주는 글 |
/// | 5 | 내 역할 카드 |
/// | 6 | 하단 고정 "시작하기" |
///
/// 섹션3의 소개(`summary`)와 섹션4의 도입문(`introText`)은 **읽는 사람이
/// 다릅니다.** 소개는 "무슨 이야기인지" 알려 주는 3인칭 설명이라 보호자
/// 것이고, 도입문은 아이에게 들려주는 말입니다. 같은 카드에 같은 크기로
/// 붙여 두면 아이가 자기 것이 아닌 문장부터 읽습니다.
///
/// ## 빈 값은 빈 상자가 아니라 없는 섹션입니다
///
/// 서버 시드가 아직 안 채워져서 `intro` · `childRole` 이 **빈 문자열로 오는
/// 이야기가 대부분**입니다. 빈 문단이나 빈 파스텔 상자를 그리면 화면이
/// 고장 난 것처럼 보입니다. 값이 없으면 그 섹션을 통째로 안 그립니다 —
/// 남는 것(그림 · 칩 · 시작하기)만으로도 이야기를 시작하는 데는 지장이
/// 없습니다.
///
/// **시작하기가 서비스 전체에서 세션이 생기는 유일한 지점**입니다.
/// 이어하기(홈)는 이 화면을 거치지 않고 바로 `/play` 로 복원됩니다.
class StoryDetailPage extends StatelessWidget {
  const StoryDetailPage({super.key, required this.storyId});

  /// 서버 storyId 는 UUID 라 그대로 String 으로 씁니다.
  /// `/stories/abc` 처럼 없는 id 로 들어오면 화면은 "찾을 수 없어"로 갑니다.
  final String storyId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StoryDetailViewModel>(
      create: (_) => StoryDetailViewModel(
        getIt<GetStoryDetailUseCase>(),
        getIt<StartStorySessionUseCase>(),
        storyId: storyId,
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
    final String? sessionId = await vm.start();
    if (sessionId == null || !context.mounted) return;
    // go 입니다 — 세션이 시작된 뒤 뒤로가기로 상세에 돌아오면
    // "시작하기"를 또 누를 수 있게 됩니다.
    //
    // 전체 장면 수는 세션 API 가 안 내려줘서 이 화면이 실어 보냅니다
    // (재생 화면 상단 진행바가 씁니다). → [AppRoutes.playOf]
    context.go(AppRoutes.playOf(sessionId, totalScenes: vm.story?.sceneCount));
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
                title: story.title,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // 섹션3 — 메타 칩과 소개. 둘 다 **보호자가 고를 때 보는 판단
          // 정보**라 한 덩어리로 묶고, 아이 본문(24sp)보다 작게 둡니다.
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
          if (story.summary.isNotEmpty) ...<Widget>[
            // 칩과의 간격은 md — 섹션 사이(lg)보다 좁아야 "칩에 딸린 설명"
            // 으로 읽힙니다.
            const SizedBox(height: AppSpacing.md),
            // Align 이 없으면 바깥 Column 의 stretch 가 폭을 꽉 채워 버려서
            // ConstrainedBox 가 무시됩니다. 태블릿에서 한 줄이 화면 폭만큼
            // 길어집니다.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.bubbleMaxWidth,
                ),
                child: Text(
                  story.summary,
                  // 18sp 인 kidLabel 을 굵기만 풀어 씁니다. 3인칭 설명문이라
                  // 라벨 굵기(700)면 제목처럼 보이고, 아이 본문 크기(24sp)면
                  // 도입문과 구분이 안 됩니다.
                  style: metrics
                      .text(AppTypography.kidLabel)
                      .copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppColors.ink500,
                      ),
                ),
              ),
            ),
          ],
          // 섹션4 — 도입문. 아이에게 들려주는 말입니다.
          // 서버 `intro` 가 비고 음성도 없으면 카드를 통째로 안 그립니다.
          if (story.introText.isNotEmpty ||
              story.introAudio != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _IntroCard(story: story, metrics: metrics),
          ],
          // 섹션5 — 내 역할. 이름이 비면(시드 미완) 빈 파스텔 상자 대신
          // 아무것도 안 그립니다.
          if (story.role.name.isNotEmpty) ...<Widget>[
            SizedBox(height: metrics.sectionGap),
            RoleCard(role: story.role, metrics: metrics),
          ],
        ],
      ),
    );
  }
}

/// 섹션4 — 도입/상황 한 덩어리와 "들려줘".
///
/// 서버 `intro` 는 기획의 "도입"과 "상황"을 합쳐 담습니다
/// (`데이터베이스_설계.md` §3.1). 여기서 문단을 임의로 쪼개지 않습니다 —
/// 원문의 줄바꿈이 곧 문단입니다.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.story, required this.metrics});

  final StoryDetail story;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final String? audio = story.introAudio;
    final bool hasText = story.introText.isNotEmpty;

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
          if (hasText)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.bubbleMaxWidth,
              ),
              child: Text(
                story.introText,
                style: metrics.text(AppTypography.kidBody),
              ),
            ),
          // "들려줘"는 **재생할 음성이 있을 때만** 그립니다.
          //
          // 서버가 아직 도입 음성을 안 내려줘서(TTS 501) 이 버튼은 지금
          // 100% 비활성입니다. 영영 안 눌리는 큰 버튼을 아이 화면 한가운데
          // 두면, 저학년은 "안 되는 이유"를 추론하지 못하고 계속 누르다가
          // 앱이 고장 났다고 결론 냅니다. 비활성 회색보다 없는 편이 낫습니다.
          // TTS 가 붙어 `introAudio` 가 채워지면 버튼은 저절로 돌아옵니다.
          if (audio != null) ...<Widget>[
            if (hasText) const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.center,
              child: SpeakerButton(
                audio: audio,
                semanticLabel: StoryDetailStrings.listen,
                label: StoryDetailStrings.listen,
                labelStyle: metrics.text(AppTypography.kidButton),
                size: AppSizes.tapChildPrimary,
                filled: true,
              ),
            ),
          ],
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
