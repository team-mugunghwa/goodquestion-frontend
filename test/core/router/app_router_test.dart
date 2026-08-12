import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/di/injector.dart';
import 'package:goodquestion/core/router/app_router.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/features/home/data/datasources/home_local_data_source.dart';
import 'package:goodquestion/features/home/data/repositories/home_repository_mock.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
import 'package:goodquestion/features/story/data/datasources/story_local_data_source.dart';
import 'package:goodquestion/features/story/data/repositories/story_repository_mock.dart';
import 'package:goodquestion/features/story/domain/repositories/story_repository.dart';

/// 라우터 골격이 살아 있는지 확인합니다.
///
/// 화면 내용이 아니라 **경로 → 화면 연결**만 검사합니다. 각 화면에 실제 UI 가
/// 들어오면 그때 화면별 테스트를 따로 만드세요.
/// (홈은 `test/features/home/` 에 따로 있습니다)
void main() {
  // 홈이 실제 화면이 되면서 UseCase 를 DI 에서 꺼내 씁니다.
  setUpAll(() async {
    await configureDependencies();
    // 홈·이야기는 이제 실제 서버를 부릅니다. 이 파일은 "경로 → 화면 연결"만
    // 보는 자리라 백엔드 없이도 돌아야 해서, 더미로 되돌려 둡니다.
    getIt
      ..unregister<HomeRepository>()
      ..registerLazySingleton<HomeRepository>(
        () => const HomeRepositoryMock(HomeLocalDataSource()),
      )
      ..unregister<StoryRepository>()
      ..registerLazySingleton<StoryRepository>(
        () => const StoryRepositoryMock(StoryLocalDataSource()),
      );
  });
  tearDownAll(getIt.reset);

  // `rootBundle` 은 읽은 에셋의 **Future 를** 캐시합니다. 그 Future 는 만들어진
  // 테스트의 async 존에 묶여 있어서, 다음 테스트에서 같은 에셋을 읽으면
  // 영원히 안 끝납니다(화면이 로딩 스피너에서 멈춤). 테스트마다 비웁니다.
  setUp(rootBundle.clear);

  /// 주소를 직접 입력해 들어온 상황을 흉내 냅니다.
  ///
  /// `pumpAndSettle` 을 쓰지 않습니다 — 로딩 스피너·스켈레톤이 프레임을 계속
  /// 요청해서 영원히 안 멎습니다.
  ///
  /// 대신 [WidgetTester.runAsync] 로 **진짜 시간을 흘려보냅니다.** 화면들이
  /// 더미 JSON 을 `rootBundle` 에서 읽는데, 이건 실제 파일 I/O 라서 가짜
  /// 시계를 아무리 돌려도 안 끝납니다. `pump(Duration)` 만 반복하면 데이터가
  /// 도착하기 전에 단언이 실행돼 통과했다 말았다 합니다.
  Future<void> pumpAt(WidgetTester tester, String location) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createAppRouter(initialLocation: location),
      ),
    );
    // 목업 Repository 는 "가짜 지연(타이머) → 에셋 읽기(진짜 I/O)" 순서로
    // 움직입니다. 둘 중 하나만 돌리면 안 끝나므로 번갈아 흘려보냅니다.
    for (int i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  // 하단 내비를 가진 탭 루트 화면들. 자리 표시자가 아니라 실제 화면인지
  // 확인합니다.
  for (final String location in <String>[
    AppRoutes.home,
    AppRoutes.stories,
    AppRoutes.words,
  ]) {
    testWidgets('$location 로 들어가면 실제 화면이 뜬다', (WidgetTester tester) async {
      await pumpAt(tester, location);
      expect(find.byType(AppBottomNav), findsOneWidget);
    });
  }

  testWidgets('/mypage 로 들어가면 보호자 허브가 뜬다', (WidgetTester tester) async {
    await pumpAt(tester, AppRoutes.myPage);
    expect(find.text(MyPageStrings.title), findsOneWidget);
    // 경계 화면이라 하단 내비를 가집니다.
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  // 보호자 하위 화면들. 탭 루트가 아니라 하단 내비가 없습니다.
  testWidgets('마이페이지의 설정을 누르면 /settings로 이동한다', (WidgetTester tester) async {
    final router = createAppRouter(initialLocation: AppRoutes.myPage);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (int i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    final Finder settingsTile = find.ancestor(
      of: find.text(MyPageStrings.settings),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(settingsTile);
    await tester.pump();
    tester.widget<InkWell>(settingsTile).onTap!();
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.settings);
    expect(find.text(SettingsStrings.title), findsOneWidget);
  });

  testWidgets('기존 /mypage/settings 주소는 /settings로 이동한다', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, '/mypage/settings');
    expect(find.text(SettingsStrings.title), findsOneWidget);
  });

  final Map<String, String> guardianTitles = <String, String>{
    AppRoutes.report: ReportListStrings.title,
    AppRoutes.reportDetailOf('104'): ReportDetailStrings.title,
    AppRoutes.settings: SettingsStrings.title,
  };

  guardianTitles.forEach((String location, String title) {
    testWidgets('$location 로 들어가면 "$title" 화면이 뜬다', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, location);
      expect(find.text(title), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
    });
  });

  testWidgets('/auth 로 들어가면 로그인 스텝이 뜬다', (WidgetTester tester) async {
    await pumpAt(tester, AppRoutes.auth);
    // 소셜 버튼이 이 스텝의 주인공입니다. (이메일 로그인은 접히는 곳 아래)
    expect(find.text(AuthStrings.tagline), findsOneWidget);
    expect(find.textContaining('카카오'), findsOneWidget);
  });

  testWidgets('/login 로 들어가면 로그인 스텝이 뜬다', (WidgetTester tester) async {
    await pumpAt(tester, AppRoutes.login);
    expect(find.text(AuthStrings.socialSignIn), findsOneWidget);
    expect(find.text(AuthStrings.emailSignIn), findsOneWidget);
  });

  testWidgets('/auth?step=child 는 프로필 등록으로 바로 간다', (WidgetTester tester) async {
    await pumpAt(tester, AppRoutes.authChildStep);
    // 로그인은 됐는데 프로필이 없는 계정이 오는 자리입니다.
    expect(find.text(AuthStrings.childTitle), findsOneWidget);
  });

  testWidgets('/stories/:storyId 로 들어가면 상세 화면이 뜬다', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, AppRoutes.storyDetailOf('11'));
    // 탭 루트가 아니라 하단 내비가 없습니다. 대신 시작하기가 있어야 합니다.
    expect(find.text(StoryDetailStrings.start), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  // 경로 → 아직 자리 표시자인 화면에 보여야 하는 문구.
  final Map<String, String> expectedText = <String, String>{
    AppRoutes.playOf('abc'): '/play/abc - 장면 진행',
    AppRoutes.playRecapOf('abc'): '/play/abc/recap - 말하기 후 활동',
    AppRoutes.planet: '/planet - 내 행성',
  };

  expectedText.forEach((String location, String text) {
    testWidgets('$location 로 들어가면 "$text" 가 보인다', (WidgetTester tester) async {
      await pumpAt(tester, location);
      expect(find.text(text), findsOneWidget);
    });
  });

  testWidgets('회원가입 전용 경로는 만들지 않는다', (WidgetTester tester) async {
    for (final String location in <String>['/signup']) {
      await pumpAt(tester, location);
      expect(find.text('$location - 없는 경로'), findsOneWidget);
    }
  });
}
