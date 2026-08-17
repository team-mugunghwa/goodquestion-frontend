import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_breakpoints.dart';
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
import '../../../../core/widgets/cosmic_backdrop.dart';
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
/// | 2 | 표지 |
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
/// ## 태블릿은 2단, 폰은 세로 한 줄
///
/// 표지 원본은 **세로 2:3 그림책 판형**입니다(`docs/COVER_ART_GUIDE.md`).
/// 이걸 가로 배너로 잘라 전폭에 깔면 그림 대부분이 버려지는데 세로는 세로
/// 대로 다 먹어서, 정작 중요한 역할 카드가 접히는 곳 아래로 내려갑니다.
///
/// 태블릿에서는 **왼쪽에 표지 세로 전체, 오른쪽에 글**로 갈라 놓습니다 —
/// 잘린 그림도 없고, 비어 있던 가로 공간이 글에 쓰입니다. 폰(compact)은
/// 2단으로 쪼개지 않습니다. 좁으면 카드를 줄이는 게 아니라 **레이아웃을
/// 바꿉니다.** → [_Content]
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
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 목록에서 이어져 들어오는 화면 — 같은 하늘을 잇습니다.
            const CosmicBackdrop(seed: 23, planetCenterX: 0.5),
            SafeArea(
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
                          onStart: vm.isStarting
                              ? null
                              : () => _start(context, vm),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
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

/// 표지가 가져갈 수 있는 **최대 가로 몫**.
///
/// 표지는 [_coverWidthFor] 처럼 높이에 맞춰 세우지만, 아이패드 세로
/// (1024×1366)처럼 화면이 길면 높이만 따라가다 표지 하나가 본문 폭을 다
/// 먹습니다(756dp). 이 화면에서 오른쪽 글이 먼저라 여기서 끊고, 그때는
/// 표지가 **잘리지 않고 작아집니다.**
///
/// 4할인 이유: 아이패드 세로에서 오른쪽에 544dp 가 남습니다 — 말풍선 최대
/// 폭([AppSizes.bubbleMaxWidth] 560)과 거의 같아서 도입문 한 줄 길이가
/// 다른 화면과 달라지지 않습니다.
const double _coverWidthShare = 0.4;

/// 2단에서 표지가 설 폭. 높이에 맞춰 세우고 폭이 따라옵니다.
///
/// 2:3 을 폭 기준으로 깔면 아이패드 가로(1024×768)에서 세로가 넘칩니다.
/// 반대로 **쓸 수 있는 높이**에서 시작하면 표지는 어떤 화면에서도 한 번에
/// 다 보이고, 스크롤 대상에서 빠집니다. → [_Content]
double _coverWidthFor(BoxConstraints constraints, ScreenMetrics metrics) {
  // 세로 여백(위 sm · 아래 lg)을 뺀, 표지가 실제로 설 수 있는 높이.
  final double boxHeight = math.max(
    constraints.maxHeight - AppSpacing.sm - AppSpacing.lg,
    0,
  );
  final double contentWidth = math.max(
    constraints.maxWidth - metrics.screenPadding * 2,
    0,
  );
  return math.min(
    boxHeight * StoryThumbnail.portrait,
    contentWidth * _coverWidthShare,
  );
}

/// 섹션2~5. 태블릿은 표지 | 글 2단, 폰은 세로 한 줄.
class _Content extends StatelessWidget {
  const _Content({required this.story, required this.metrics});

  final StoryDetail story;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      metrics.screenPadding,
      AppSpacing.sm,
      metrics.screenPadding,
      AppSpacing.lg,
    );

    // 폰(compact)은 2단으로 쪼개지 않습니다. 390dp 를 둘로 나누면 표지도
    // 글도 못 씁니다 — 좁으면 카드를 줄이는 게 아니라 레이아웃을 바꿉니다.
    if (!metrics.isWide) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 폰에서는 표지를 세로 전체로 깔지 않습니다. 390dp 폭의 2:3 은
            // 585dp — 첫 화면이 표지 하나로 끝나고 칩·도입·역할이 전부
            // 접히는 곳 아래로 밀립니다. 홈 카드와 같은 16:9 로 자릅니다.
            // 표지는 주인공이 세로 가운데라 가운데 크롭이 안전합니다.
            // (`docs/COVER_ART_GUIDE.md`)
            _Cover(story: story, aspectRatio: StoryThumbnail.wide),
            const SizedBox(height: AppSpacing.lg),
            ..._sections(),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double coverWidth = _coverWidthFor(constraints, metrics);
        return Padding(
          padding: padding,
          child: Align(
            // 세로는 위로 붙입니다. 아이패드 세로처럼 화면이 길면 표지가
            // 폭 상한에 걸려 두 단 다 짧아지는데, 그때 덩어리를 가운데
            // 띄우면 상단 바와 내용 사이가 빈 띠로 끊깁니다.
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              // 2000dp 짜리 태블릿에서 두 단이 양 끝으로 벌어지면 표지와
              // 글이 한 화면의 두 물건처럼 안 읽힙니다. 글 칼럼은 보호자
              // 본문 폭에서 끊고, 남는 폭은 양옆으로 흘려보냅니다.
              constraints: BoxConstraints(
                maxWidth:
                    coverWidth + AppSpacing.xl + AppBreakpoints.maxContentWidth,
              ),
              child: Row(
                // stretch 를 주면 표지 높이가 강제로 늘어나 2:3 이 깨집니다.
                // 표지 쪽이 짧을 때(폭 상한에 걸린 경우) 가운데에 서게 둡니다.
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: coverWidth,
                    child: _Cover(
                      story: story,
                      aspectRatio: StoryThumbnail.portrait,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  // **스크롤은 오른쪽 칼럼만** 합니다. 화면 전체를 스크롤
                  // 시키면 아이패드 가로(768)에서 표지가 위로 잘려 올라가는데,
                  // 표지는 이 화면에서 아이가 "무슨 이야기인지" 판단하는
                  // 유일한 그림입니다. 넘치는 것은 글이니 글을 흐르게 합니다.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: _sections(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 섹션3~5. 2단이든 세로 한 줄이든 **읽는 순서는 같습니다.**
  List<Widget> _sections() {
    // 2단에서는 카드 사이를 lg 로 좁힙니다 — 오른쪽 칼럼의 세로는 화면
    // 높이로 묶여 있어서 sectionGap(64) 을 주면 역할 카드가 그만큼 스크롤
    // 밖으로 밀립니다. 폰은 어차피 세로로 흐르니 원래 간격을 유지합니다.
    final double cardGap = metrics.isWide ? AppSpacing.lg : metrics.sectionGap;

    return <Widget>[
      // 섹션3 — 메타 칩이 소개보다 위입니다.
      //
      // 2단에서 이 줄은 상단 바 제목과 **같은 띠**에 놓입니다. 왼쪽에 제목,
      // 오른쪽에 시간·난이도·주제 — 화면을 가로지르는 머리글 한 줄로
      // 읽힙니다. 소개는 그 아래에 와야 "머리글에 딸린 부제"가 되고,
      // 소개를 칩 위로 올리면 회색 한 줄이 화면 맨 위에서 제목과 경쟁합니다.
      // 폰에서도 순서가 같아 두 레이아웃의 읽는 차례가 어긋나지 않습니다.
      _MetaChips(story: story, metrics: metrics),
      if (story.summary.isNotEmpty) ...<Widget>[
        // 칩과의 간격은 md — 섹션 사이(lg)보다 좁아야 "칩에 딸린 설명"
        // 으로 읽힙니다.
        const SizedBox(height: AppSpacing.md),
        _SummaryLine(text: story.summary, metrics: metrics),
      ],
      // 섹션4 — 도입문. 아이에게 들려주는 말입니다.
      // 서버 `intro` 가 비고 음성도 없으면 카드를 통째로 안 그립니다.
      if (story.introText.isNotEmpty || story.introAudio != null) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        _IntroCard(story: story, metrics: metrics),
      ],
      // 섹션5 — 내 역할. 이름이 비면(시드 미완) 빈 파스텔 상자 대신
      // 아무것도 안 그립니다.
      if (story.role.name.isNotEmpty) ...<Widget>[
        SizedBox(height: cardGap),
        RoleCard(role: story.role, storyId: story.storyId, metrics: metrics),
      ],
    ];
  }
}

/// 섹션2 — 표지. 아이는 글보다 분위기를 먼저 읽습니다.
///
/// 원본은 세로 2:3 그림책 판형(`docs/COVER_ART_GUIDE.md`)이라, 태블릿
/// 2단에서는 [StoryThumbnail.portrait] 로 **그림 전체**를 세웁니다.
/// 표지가 없는 이야기는 [StoryThumbnail] 이 제목 표지 → 코드 표지 순으로
/// 대신 그립니다 — 같은 비율의 면이라 레이아웃은 그대로입니다.
class _Cover extends StatelessWidget {
  const _Cover({required this.story, required this.aspectRatio});

  final StoryDetail story;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // 그림자는 그림을 화면에 붙은 무늬가 아니라 **책으로 얹힌 물건**으로
      // 보이게 합니다. 다른 카드와 같은 soft 를 씁니다.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: StoryThumbnail(
          image: story.coverImage,
          fallbackIcon: AppIcons.stories,
          aspectRatio: aspectRatio,
          title: story.title,
        ),
      ),
    );
  }
}

/// 섹션3 앞줄 — 시간·난이도·주제. **보호자가 고를 때 보는 판단 정보**라
/// 아이 본문(24sp)보다 작게 둡니다.
class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.story, required this.metrics});

  final StoryDetail story;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
          KidInfoChip(icon: AppIcons.topic, label: topic, metrics: metrics),
      ],
    );
  }
}

/// 섹션3 뒷줄 — 3인칭 소개 한 줄. 제목의 **부제**로 읽혀야 합니다.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.text, required this.metrics});

  final String text;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    // Align 이 없으면 바깥 Column 의 stretch 가 폭을 꽉 채워 버려서
    // ConstrainedBox 가 무시됩니다. 태블릿에서 한 줄이 칼럼 폭만큼
    // 길어집니다.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.bubbleMaxWidth),
        child: Text(
          text,
          // 18sp 인 kidLabel 을 굵기만 풀어 씁니다. 3인칭 설명문이라
          // 라벨 굵기(700)면 제목처럼 보이고, 아이 본문 크기(24sp)면
          // 도입문과 구분이 안 됩니다.
          style: metrics
              .text(AppTypography.kidLabel)
              .copyWith(fontWeight: FontWeight.w400, color: AppColors.ink500),
        ),
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
    // 흰 판을 깔지 않습니다 — 배경 위에 버튼만 떠 있어야 화면이 한 장으로
    // 이어집니다. 버튼 자체의 그림자가 스크롤되는 본문과 층을 나눕니다.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.sm,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          boxShadow: AppShadows.lift,
        ),
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

/// 로딩 자리. **실제 콘텐츠와 같은 레이아웃**으로 잡습니다 — 태블릿에서
/// 세로 스켈레톤을 보여 주고 2단으로 바뀌면 화면이 통째로 덜컹거립니다.
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      metrics.screenPadding,
      AppSpacing.sm,
      metrics.screenPadding,
      AppSpacing.lg,
    );

    if (!metrics.isWide) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SkeletonBox(
              aspectRatio: StoryThumbnail.wide,
              borderRadius: AppRadius.xl,
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._lines(),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double coverWidth = _coverWidthFor(constraints, metrics);
        return Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    coverWidth + AppSpacing.xl + AppBreakpoints.maxContentWidth,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: coverWidth,
                    child: const SkeletonBox(
                      aspectRatio: StoryThumbnail.portrait,
                      borderRadius: AppRadius.xl,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  // 콘텐츠와 마찬가지로 오른쪽만 흐릅니다. 폰 가로(390 높이)
                  // 처럼 세로가 짧은 화면에서 자리표시자가 넘칩니다.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: _lines(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 칩 줄 → 도입 카드 → 역할 카드. 도착할 콘텐츠와 같은 순서·같은 여백.
  List<Widget> _lines() => <Widget>[
    const SkeletonBox(width: 240, height: AppSpacing.xl),
    const SizedBox(height: AppSpacing.lg),
    const SkeletonBox(height: AppSizes.mic, borderRadius: AppRadius.xl),
    SizedBox(height: metrics.isWide ? AppSpacing.lg : metrics.sectionGap),
    const SkeletonBox(
      height: AppSizes.illustration,
      borderRadius: AppRadius.xl,
    ),
  ];
}
