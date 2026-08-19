import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/di/injector.dart';
import 'package:goodquestion/core/router/app_router.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/features/mypage/domain/entities/app_settings.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_detail.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_summary.dart';
import 'package:goodquestion/features/mypage/domain/guardian_gate.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';

/// 보호자 확인은 **리포트 영역에 있는 동안만** 열려 있습니다.
///
/// 세션 내내 열어 두면 보호자가 리포트를 보고 태블릿을 아이에게 넘긴 뒤
/// 아이가 비밀번호 없이 리포트를 엽니다. 반대로 목록 ↔ 상세에서 매번 물으면
/// 아무도 못 씁니다 — 그 경계를 여기서 고정합니다.
void main() {
  // 라우터가 진짜 화면들을 만들고, 그 화면들이 DI 에서 UseCase 를 꺼냅니다.
  // (게이트 자체는 주입해서 씁니다 - DI 의 것과 섞이지 않게)
  setUpAll(() async {
    await configureDependencies();
    // 리포트 화면이 진짜 서버를 부르면 연결 타임아웃 타이머가 테스트보다
    // 오래 남습니다. 이 파일은 주소와 게이트만 보는 자리라 즉시 답하는
    // 가짜로 바꿔 둡니다.
    getIt
      ..unregister<ReportRepository>()
      ..registerLazySingleton<ReportRepository>(_SilentReports.new)
      ..unregister<MyPageRepository>()
      ..registerLazySingleton<MyPageRepository>(_SilentMyPage.new)
      ..unregister<ChildProfileRepository>()
      ..registerLazySingleton<ChildProfileRepository>(
        () => getIt<MyPageRepository>() as _SilentMyPage,
      )
      // 마이페이지가 설정까지 펼치면서 설정도 서버를 부릅니다.
      ..unregister<SettingsRepository>()
      ..registerLazySingleton<SettingsRepository>(_SilentSettings.new);
  });
  tearDownAll(getIt.reset);

  /// 라우터만 띄웁니다. 화면 내용은 각 화면 테스트가 봅니다 - 여기서 보는
  /// 것은 주소가 바뀔 때 게이트가 어떻게 되는가뿐입니다.
  Future<GoRouter> pumpRouter(
    WidgetTester tester,
    GuardianGate gate, {
    String initialLocation = AppRoutes.report,
  }) async {
    final GoRouter router = createAppRouter(
      initialLocation: initialLocation,
      authTokenProvider: () async => 'test-token',
      guardianGate: gate,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    return router;
  }

  /// 화면들이 걸어 둔 타이머(로딩 지연·네트워크 타임아웃)를 흘려보냅니다.
  /// 남겨 두면 위젯 트리가 사라진 뒤에도 타이머가 살아 있다고 테스트가
  /// 실패합니다 - 이 파일이 보는 것은 주소와 게이트뿐입니다.
  Future<void> drain(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 30));
      // 그 프레임이 새로 건 0초짜리 타이머까지 마저 흘려보냅니다.
      await tester.pump();
    }
  }

  testWidgets('목록에서 상세로 들어가도 통과 상태가 유지된다', (WidgetTester tester) async {
    final GuardianGate gate = GuardianGate()..pass();
    final GoRouter router = await pumpRouter(tester, gate);

    router.go(AppRoutes.reportDetailOf('104'));
    await tester.pump();

    expect(gate.isPassed, isTrue, reason: '목록과 상세 사이에서 다시 물으면 보호자가 리포트를 못 씁니다');
  });

  testWidgets('상세에서 목록으로 돌아와도 통과 상태가 유지된다', (WidgetTester tester) async {
    final GuardianGate gate = GuardianGate()..pass();
    final GoRouter router = await pumpRouter(
      tester,
      gate,
      initialLocation: AppRoutes.reportDetailOf('104'),
    );

    router.go(AppRoutes.report);
    await tester.pump();

    expect(gate.isPassed, isTrue);
    await drain(tester);
  });

  testWidgets('리포트 영역을 벗어나면 다시 잠긴다', (WidgetTester tester) async {
    for (final String away in <String>[
      AppRoutes.home,
      AppRoutes.myPage,
      AppRoutes.settings,
    ]) {
      final GuardianGate gate = GuardianGate()..pass();
      final GoRouter router = await pumpRouter(tester, gate);

      router.go(away);
      await tester.pump();

      expect(gate.isPassed, isFalse, reason: '$away 로 나갔는데 게이트가 열려 있습니다');
      await drain(tester);
    }
  });

  testWidgets('다시 리포트로 들어가도 저절로 열리지는 않는다', (WidgetTester tester) async {
    final GuardianGate gate = GuardianGate()..pass();
    final GoRouter router = await pumpRouter(tester, gate);

    router.go(AppRoutes.home);
    await tester.pump();
    router.go(AppRoutes.report);
    await tester.pump();

    // 잠긴 채로 들어옵니다 - 여는 것은 비밀번호를 확인한 호출부의 몫입니다.
    expect(gate.isPassed, isFalse);
    await drain(tester);
  });

  testWidgets('뒤로 눌러 마이페이지로 돌아오면 다시 잠긴다', (WidgetTester tester) async {
    // 실제 흐름은 마이페이지에서 push 로 열고 뒤로 눌러 닫습니다.
    final GuardianGate gate = GuardianGate();
    final GoRouter router = await pumpRouter(
      tester,
      gate,
      initialLocation: AppRoutes.myPage,
    );

    unawaited(router.push(AppRoutes.report));
    await tester.pump();
    gate.pass();

    router.pop();
    await tester.pump();

    expect(gate.isPassed, isFalse);
    await drain(tester);
  });

  test('리포트 영역 판별은 접두사만 보지 않는다', () {
    expect(AppRoutes.isReportArea(AppRoutes.report), isTrue);
    expect(AppRoutes.isReportArea(AppRoutes.reportDetailOf('104')), isTrue);
    expect(AppRoutes.isReportArea(AppRoutes.myPage), isFalse);
    // 이름이 겹치는 남의 경로가 딸려 들어오면 안 됩니다.
    expect(AppRoutes.isReportArea('/mypage/reports-2026'), isFalse);
  });
}

/// 화면이 뜨기만 하면 되므로 곧바로 빈 답을 줍니다. 상세의 `null` 은
/// "아직 분석이 안 끝난 세션"이라 대기 화면이 뜹니다(에러가 아닙니다).
class _SilentReports implements ReportRepository {
  @override
  Future<ReportList> getReportList() async => const ReportList(
    childName: '하늘이',
    totalCount: 0,
    reports: <ReportSummary>[],
  );

  @override
  Future<ReportDetail?> getReportDetail(String sessionId) async => null;
}

/// 마이페이지도 같은 이유로 조용히 만듭니다 - `/mypage/report` 는 `/mypage`
/// 아래라 마이페이지 화면도 함께 세워집니다.
class _SilentSettings implements SettingsRepository {
  static const AppSettings _value = AppSettings(
    reportNotification: true,
    marketingConsent: false,
    accountType: 'email',
    accountLabel: 'test@example.com',
    hasNewNotice: false,
    appVersion: '0.1.0',
  );

  @override
  Future<AppSettings> getSettings() async => _value;

  @override
  Future<AppSettings> setReportNotification({required bool enabled}) async =>
      _value;

  @override
  Future<AppSettings> setMarketingConsent({required bool enabled}) async =>
      _value;
}

class _SilentMyPage implements MyPageRepository, ChildProfileRepository {
  @override
  Future<void> updateChild({
    required String childId,
    required String name,
    required int age,
  }) async {}
  @override
  String? selectedChildId;

  @override
  Future<MyPageSummary> getSummary() async =>
      const MyPageSummary(childCount: 0, completedStories: 0, stardust: 0);

  @override
  Future<List<MyPageChild>> getChildren() async => const <MyPageChild>[];

  @override
  Future<void> createChild({required String name, required int age}) async {}

  @override
  Future<void> selectChild(String childId) async {}
}
