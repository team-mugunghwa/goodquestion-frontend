import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/di/injector.dart';
import 'package:goodquestion/core/router/app_router.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';

/// 라우터 골격이 살아 있는지 확인합니다.
///
/// 화면 내용이 아니라 **경로 → 화면 연결**만 검사합니다. 각 화면에 실제 UI 가
/// 들어오면 그때 화면별 테스트를 따로 만드세요.
/// (홈은 `test/features/home/` 에 따로 있습니다)
void main() {
  // 홈이 실제 화면이 되면서 UseCase 를 DI 에서 꺼내 씁니다.
  setUpAll(configureDependencies);
  tearDownAll(getIt.reset);

  /// 주소를 직접 입력해 들어온 상황을 흉내 냅니다.
  Future<void> pumpAt(WidgetTester tester, String location) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createAppRouter(initialLocation: location),
      ),
    );
    await tester.pumpAndSettle();
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
    AppRoutes.auth: '/auth - 보호자 인증',
  };

  expectedText.forEach((String location, String text) {
    testWidgets('$location 로 들어가면 "$text" 가 보인다', (WidgetTester tester) async {
      await pumpAt(tester, location);
      expect(find.text(text), findsOneWidget);
    });
  });

  testWidgets('설계에 없는 12개 외의 경로는 만들지 않는다', (WidgetTester tester) async {
    // 로그인/회원가입은 /auth 하나로만 처리합니다.
    for (final String location in <String>['/login', '/signup']) {
      await pumpAt(tester, location);
      expect(find.text('$location - 없는 경로'), findsOneWidget);
    }
  });
}
