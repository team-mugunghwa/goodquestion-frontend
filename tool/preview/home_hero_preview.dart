import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/home/domain/entities/child_profile.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/home/domain/entities/in_progress_session.dart';
import 'package:goodquestion/features/home/domain/entities/planet_summary.dart';
import 'package:goodquestion/features/home/domain/entities/recommended_story.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
import 'package:goodquestion/features/home/domain/usecases/get_home_summary_use_case.dart';
import 'package:goodquestion/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:goodquestion/features/home/presentation/views/home_view.dart';
import 'package:provider/provider.dart';

/// 홈 히어로를 **로그인·백엔드 없이** 눈으로 보는 프리뷰입니다.
///
/// 위젯 테스트는 스텁 폰트라 한글 줄바꿈·오버플로를 못 잡습니다. 표지가 어디서도
/// 안 잘리는지, 아래 "새로운 이야기"의 표지와 라벨이 첫 화면에 들어오는지는
/// 브라우저 창을 재 봐야 압니다.
///
/// 상태는 주소로 고릅니다 — 화면 위에 토글을 두면 그만큼 세로가 줄어서
/// "첫 화면에 들어오는가"를 잘못 재게 됩니다.
///
/// | 주소 | 상태 |
/// |---|---|
/// | `/` | 이어하기 있음 |
/// | `/today` | 이어하기 없음 · 추천 1순위가 히어로 |
/// | `/fallback` | 이어하기도 추천도 없음 |
/// | `/loading` | 스켈레톤 |
///
/// `flutter run -d web-server` 는 이 환경에서 화면이 안 그려집니다. **빌드해서
/// 정적 서버로** 띄우세요.
///
/// ```
/// flutter build web --profile -t tool/preview/home_hero_preview.dart
/// cd build/web && python -m http.server 5000
/// # http://127.0.0.1:5000/#/  ·  /#/today  ·  /#/fallback  ·  /#/loading
/// ```
void main() => runApp(const _HomeHeroPreviewApp());

const ChildProfile _child = ChildProfile(name: '지우');
const PlanetSummary _planet = PlanetSummary(stardustBalance: 15);

const List<RecommendedStory> _recommended = <RecommendedStory>[
  RecommendedStory(
    storyId: '22',
    title: '의좋은 형제',
    image: 'assets/images/covers/story_22.png',
    estimatedMinutes: 20,
    topicTag: '옛이야기',
  ),
  RecommendedStory(
    storyId: '21',
    title: '해와 달이 된 오누이',
    image: 'assets/images/covers/story_21.png',
    estimatedMinutes: 15,
    topicTag: '용기',
  ),
  RecommendedStory(
    storyId: '23',
    title: '흥부와 놀부',
    image: 'assets/images/covers/story_23.png',
    estimatedMinutes: 15,
    topicTag: '가족',
  ),
];

class _HomeHeroPreviewApp extends StatelessWidget {
  const _HomeHeroPreviewApp();

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => _preview(
            const HomeSummary(
              child: _child,
              inProgressSession: InProgressSession(
                sessionId: '2481',
                storyTitle: '방귀 뀌는 며느리',
                storyImage: 'assets/images/covers/story_11.png',
                lastCompletedScene: 5,
                totalScenes: 10,
              ),
              recommendedStories: _recommended,
              planet: _planet,
            ),
          ),
        ),
        GoRoute(
          path: '/today',
          builder: (_, __) => _preview(
            const HomeSummary(
              child: _child,
              recommendedStories: _recommended,
              planet: _planet,
            ),
          ),
        ),
        GoRoute(
          path: '/fallback',
          builder: (_, __) => _preview(
            const HomeSummary(
              child: _child,
              recommendedStories: <RecommendedStory>[],
              planet: _planet,
            ),
          ),
        ),
        GoRoute(path: '/loading', builder: (_, __) => _preview(null)),
        // 하단 내비·추천 카드가 나가는 곳들. 프리뷰에서는 돌아오는 문만 둡니다.
        for (final String path in <String>[
          AppRoutes.stories,
          AppRoutes.storyDetailPath,
          AppRoutes.words,
          AppRoutes.myPage,
          AppRoutes.planet,
        ])
          GoRoute(
            path: path,
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text('${state.uri} → 홈으로'),
                ),
              ),
            ),
          ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
  }
}

Widget _preview(HomeSummary? summary) => ChangeNotifierProvider<HomeViewModel>(
  create: (_) =>
      HomeViewModel(GetHomeSummaryUseCase(_StubRepository(summary)))..load(),
  child: const HomeView(),
);

/// [summary] 가 `null` 이면 영원히 로딩 — 스켈레톤을 붙잡아 두려고 그렇습니다.
class _StubRepository implements HomeRepository {
  const _StubRepository(this.summary);

  final HomeSummary? summary;

  @override
  Future<HomeSummary> getHomeSummary() async {
    final HomeSummary? data = summary;
    if (data == null) return Completer<HomeSummary>().future;
    return data;
  }
}
