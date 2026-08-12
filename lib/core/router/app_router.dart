import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/datasources/auth_token_store.dart';
import '../../features/auth/presentation/views/account_recovery_view.dart';
import '../../features/auth/presentation/views/auth_view.dart';
import '../../features/auth/presentation/views/password_reset_view.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/mypage/presentation/views/my_page_view.dart';
import '../../features/mypage/presentation/views/report_detail_view.dart';
import '../../features/mypage/presentation/views/report_list_view.dart';
import '../../features/mypage/presentation/views/settings_view.dart';
import '../../features/planet/presentation/views/planet_view.dart';
import '../../features/play/presentation/views/play_recap_view.dart';
import '../../features/play/presentation/views/play_view.dart';
import '../../features/story/presentation/views/story_detail_view.dart';
import '../../features/story/presentation/views/story_list_view.dart';
import '../../features/word/presentation/views/word_list_view.dart';
import '../di/injector.dart';
import '../widgets/route_placeholder_view.dart';
import 'app_routes.dart';

/// 앱 전체의 라우트 표.
///
/// **여러 명이 동시에 건드리기 쉬운 파일입니다.** 라우트를 추가할 땐 팀 채널에
/// 알리세요. → `docs/CONVENTIONS.md` 6장
///
/// 경로는 [AppRoutes] 에만 적습니다. 여기에 문자열을 직접 쓰지 마세요.
///
/// 자식 라우트의 `path` 는 **상대 경로**라 앞에 `/` 를 붙이지 않습니다.
/// 예: `/mypage` 의 자식 `report` → 실제 경로는 `/mypage/report`.
final GoRouter appRouter = createAppRouter();

/// 라우터를 새로 만듭니다.
///
/// 앱은 [appRouter] 하나만 씁니다. 이 함수는 **테스트에서** 원하는 경로로
/// 바로 진입한 라우터를 매번 새로 만들기 위해 열어 둔 것입니다.
/// (전역 [appRouter] 를 테스트끼리 돌려 쓰면 앞 테스트의 히스토리가 남습니다.)
GoRouter createAppRouter({
  String initialLocation = AppRoutes.home,
  Future<String?> Function()? authTokenProvider,
}) {
  final Future<String?> Function() readToken =
      authTokenProvider ?? getIt<AuthTokenStore>().read;

  return GoRouter(
    initialLocation: initialLocation,
    redirect: (BuildContext context, GoRouterState state) async {
      final bool signedIn = (await readToken())?.isNotEmpty ?? false;
      final String location = state.matchedLocation;
      final bool isRecovery =
          location == AppRoutes.findId ||
          location == AppRoutes.findPassword ||
          location == AppRoutes.resetPassword;
      final bool isLogin =
          location == AppRoutes.login ||
          (location == AppRoutes.auth &&
              state.uri.queryParameters[AppRoutes.stepParam] !=
                  AppRoutes.childStepValue);

      if (!signedIn && !isLogin && !isRecovery) return AppRoutes.auth;
      if (signedIn && isLogin) return AppRoutes.home;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.stories,
        builder: (BuildContext context, GoRouterState state) =>
            const StoryListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':${AppRoutes.storyIdParam}',
            builder: (BuildContext context, GoRouterState state) =>
                StoryDetailPage(
                  storyId: state.pathParameters[AppRoutes.storyIdParam]!,
                ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.playPath,
        builder: (BuildContext context, GoRouterState state) => PlayPage(
          sessionId: state.pathParameters[AppRoutes.sessionIdParam]!,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'recap',
            builder: (BuildContext context, GoRouterState state) =>
                PlayRecapPage(
                  sessionId: state.pathParameters[AppRoutes.sessionIdParam]!,
                ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.planet,
        builder: (BuildContext context, GoRouterState state) =>
            const PlanetPage(),
      ),
      GoRoute(
        path: AppRoutes.words,
        builder: (BuildContext context, GoRouterState state) =>
            const WordListPage(),
      ),
      GoRoute(
        path: AppRoutes.myPage,
        builder: (BuildContext context, GoRouterState state) => const MyPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'report',
            builder: (BuildContext context, GoRouterState state) =>
                const ReportListPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':${AppRoutes.sessionIdParam}',
                builder: (BuildContext context, GoRouterState state) =>
                    ReportDetailPage(
                      sessionId:
                          state.pathParameters[AppRoutes.sessionIdParam]!,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: 'settings',
            redirect: (BuildContext context, GoRouterState state) =>
                AppRoutes.settings,
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (BuildContext context, GoRouterState state) => AuthPage(
          // 프로필 없는 기존 계정은 로그인 스텝을 건너뜁니다.
          startAtChildProfile:
              state.uri.queryParameters[AppRoutes.stepParam] ==
              AppRoutes.childStepValue,
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const AuthPage(),
      ),
      GoRoute(
        path: AppRoutes.findId,
        builder: (BuildContext context, GoRouterState state) =>
            const AccountRecoveryPage(mode: AccountRecoveryMode.findId),
      ),
      GoRoute(
        path: AppRoutes.findPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const AccountRecoveryPage(mode: AccountRecoveryMode.resetPassword),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (BuildContext context, GoRouterState state) =>
            PasswordResetPage(token: state.uri.queryParameters['token'] ?? ''),
      ),
    ],
    // 없는 경로로 들어왔을 때 빨간 에러 화면 대신 무엇이 틀렸는지 보여 줍니다.
    errorBuilder: (BuildContext context, GoRouterState state) =>
        RoutePlaceholderView(path: state.uri.toString(), title: '없는 경로'),
  );
}
