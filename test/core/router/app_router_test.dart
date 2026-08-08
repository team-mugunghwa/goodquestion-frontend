import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/router/app_router.dart';
import 'package:goodquestion/core/router/app_routes.dart';

/// 라우터 골격이 살아 있는지 확인합니다.
///
/// 화면 내용이 아니라 **경로 → 화면 연결**만 검사합니다. 각 화면에 실제 UI 가
/// 들어오면 그때 화면별 테스트를 따로 만드세요.
void main() {
  /// 주소를 직접 입력해 들어온 상황을 흉내 냅니다.
  Future<void> pumpAt(WidgetTester tester, String location) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createAppRouter(initialLocation: location),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 경로 → 화면에 보여야 하는 문구.
  final Map<String, String> expectedText = <String, String>{
    AppRoutes.home: '/ - 홈',
    AppRoutes.stories: '/stories - 이야기 목록',
    AppRoutes.storyDetailOf('12'): '/stories/12 - 이야기 상세',
    AppRoutes.playOf('abc'): '/play/abc - 장면 진행',
    AppRoutes.playRecapOf('abc'): '/play/abc/recap - 말하기 후 활동',
    AppRoutes.planet: '/planet - 내 행성',
    AppRoutes.words: '/words - 단어장',
    AppRoutes.myPage: '/mypage - 마이페이지',
    AppRoutes.report: '/mypage/report - 보호자 리포트 목록',
    AppRoutes.reportDetailOf('abc'): '/mypage/report/abc - 보호자 리포트 상세',
    AppRoutes.settings: '/mypage/settings - 설정',
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
