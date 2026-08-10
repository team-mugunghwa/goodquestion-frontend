import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/di/injector.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/features/mypage/domain/entities/app_settings.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_detail.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_summary.dart';
import 'package:goodquestion/features/mypage/domain/guardian_gate.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';
import 'package:goodquestion/features/mypage/domain/usecases/my_page_use_cases.dart';
import 'package:goodquestion/features/mypage/presentation/viewmodels/my_page_view_model.dart';
import 'package:goodquestion/features/mypage/presentation/viewmodels/report_detail_view_model.dart';
import 'package:goodquestion/features/mypage/presentation/viewmodels/report_list_view_model.dart';
import 'package:goodquestion/features/mypage/presentation/viewmodels/settings_view_model.dart';
import 'package:goodquestion/features/mypage/presentation/views/my_page_view.dart';
import 'package:goodquestion/features/mypage/presentation/views/report_detail_view.dart';
import 'package:goodquestion/features/mypage/presentation/views/report_list_view.dart';
import 'package:goodquestion/features/mypage/presentation/views/settings_view.dart';
import 'package:provider/provider.dart';

class _Stub implements MyPageRepository, ReportRepository, SettingsRepository {
  _Stub({this.summary, this.list, this.detail, this.settings, this.error});

  final MyPageSummary? summary;
  final ReportList? list;
  final ReportDetail? detail;
  AppSettings? settings;
  final Object? error;

  @override
  Future<MyPageSummary> getSummary() async {
    if (error != null) throw error!;
    return summary!;
  }

  @override
  Future<ReportList> getReportList() async {
    if (error != null) throw error!;
    return list!;
  }

  @override
  Future<ReportDetail?> getReportDetail(int sessionId) async {
    if (error != null) throw error!;
    return detail;
  }

  @override
  Future<void> markAsRead(int sessionId) async {}

  @override
  Future<AppSettings> getSettings() async {
    if (error != null) throw error!;
    return settings!;
  }

  @override
  Future<AppSettings> setReportNotification({required bool enabled}) async {
    settings = settings!.copyWith(reportNotification: enabled);
    return settings!;
  }

  @override
  Future<AppSettings> setMarketingConsent({required bool enabled}) async {
    settings = settings!.copyWith(marketingConsent: enabled);
    return settings!;
  }
}

const MyPageSummary _summary = MyPageSummary(
  child: MyPageChild(childId: 1, name: '하늘이', age: 8),
  childCount: 2,
  completedStories: 3,
  stardust: 7,
  hasNewReport: true,
);

const MyPageSummary _noChild = MyPageSummary(
  childCount: 0,
  completedStories: 0,
  stardust: 0,
  hasNewReport: false,
);

const ReportList _list = ReportList(
  childName: '하늘이',
  totalCount: 2,
  newCount: 1,
  reports: <ReportSummary>[
    ReportSummary(
      sessionId: 104,
      storyTitle: '방귀 뀌는 며느리',
      completedAt: null,
      isNew: true,
      playCount: 2,
      highlightUtterance: '며느리가 참으면 배가 아프니까',
    ),
  ],
);

const ReportDetail _detail = ReportDetail(
  sessionId: 104,
  childName: '하늘이',
  storyTitle: '방귀 뀌는 며느리',
  summary: '자기 생각을 이유와 함께 말하는 힘이 돋보인 세션이었어요.',
  skills: <SkillReport>[
    SkillReport(
      name: '어휘',
      feature: '낯선 낱말을 그냥 넘기지 않았어요.',
      evidence: <String>['며느리가 뭐예요?'],
      strength: '모르는 낱말을 물어봤어요.',
      improvement: '다음 문장에서 한 번 더 써 보면 좋아요.',
      askedWords: <String>['며느리', '사랑방'],
    ),
    SkillReport(
      name: '표현',
      feature: '느낀 점을 자기 말로 풀어냈어요.',
      evidence: <String>['너무 놀랐을 것 같아요'],
      strength: '감정을 담아 말했어요.',
      improvement: '다른 인물의 마음도 말해 보면 좋아요.',
      askedWords: <String>[],
    ),
  ],
  highlight: ReportHighlight(
    utterance: '며느리가 부끄러웠을 것 같아요.',
    reason: '감정과 이유를 연결해 말했어요.',
  ),
  questionGroups: <QuestionGroup>[
    QuestionGroup(
      title: '이야기 주제 이어가기',
      questions: <String>['너라면 어떻게 했을 것 같아?'],
    ),
  ],
);

const AppSettings _settings = AppSettings(
  reportNotification: true,
  marketingConsent: false,
  accountType: 'kakao',
  accountLabel: 'sl***@kakao.com',
  hasNewNotice: true,
  appVersion: '0.1.0',
);

void main() {
  // 마이페이지가 게이트를 getIt 에서 꺼내 씁니다.
  setUpAll(() => getIt.registerLazySingleton<GuardianGate>(GuardianGate.new));
  tearDownAll(getIt.reset);
  setUp(() => getIt<GuardianGate>().reset());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(900, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
    await tester.pumpAndSettle();
  }

  group('마이페이지', () {
    Widget under(_Stub stub) => ChangeNotifierProvider<MyPageViewModel>(
      create: (_) => MyPageViewModel(GetMyPageSummaryUseCase(stub))..load(),
      child: const MyPageView(),
    );

    testWidgets('프로필 카드·메뉴·하단 내비가 보인다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(summary: _summary)));

      expect(find.text('하늘이 · 8살'), findsOneWidget);
      expect(find.text(MyPageStrings.completedStories(3)), findsOneWidget);
      expect(find.text(MyPageStrings.report), findsOneWidget);
      expect(find.text(MyPageStrings.settings), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('아이가 없으면 등록 유도가 뜬다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(summary: _noChild)));

      expect(find.text(MyPageStrings.noChild), findsOneWidget);
      expect(find.text(MyPageStrings.createChild), findsOneWidget);
    });

    testWidgets('리포트를 누르면 보호자 확인을 먼저 묻는다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(summary: _summary)));

      await tester.tap(find.text(MyPageStrings.report));
      await tester.pumpAndSettle();

      expect(find.text(MyPageStrings.gateTitle), findsOneWidget);
      // 취소하면 아무 데도 안 갑니다.
      await tester.tap(find.text(MyPageStrings.gateCancel));
      await tester.pumpAndSettle();
      expect(getIt<GuardianGate>().isPassed, isFalse);
    });

    testWidgets('실패해도 메뉴는 남는다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(error: const NetworkFailure())));

      expect(find.text(AppStrings.retry), findsOneWidget);
      // 프로필을 못 불러와도 설정으로는 갈 수 있어야 합니다.
      expect(find.text(MyPageStrings.settings), findsOneWidget);
    });
  });

  group('리포트 목록', () {
    Widget under(_Stub stub) => ChangeNotifierProvider<ReportListViewModel>(
      create: (_) => ReportListViewModel(
        GetReportListUseCase(stub),
        MarkReportAsReadUseCase(stub),
      )..load(),
      child: const ReportListView(),
    );

    testWidgets('요약 스트립·카드·NEW 배지가 보인다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(list: _list)));

      expect(find.text(ReportListStrings.summary(2, 1)), findsOneWidget);
      expect(find.text('방귀 뀌는 며느리'), findsOneWidget);
      expect(find.text(ReportListStrings.badgeNew), findsOneWidget);
      // 회차가 없으면 같은 제목 카드가 중복으로 보입니다.
      expect(
        find.textContaining(ReportListStrings.playCount(2)),
        findsOneWidget,
      );
    });

    testWidgets('아이 이름은 읽기 전용 라벨이다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(list: _list)));

      expect(find.text(ReportListStrings.childLabel('하늘이')), findsOneWidget);
      // 여기서 아이를 바꿀 수 있으면 게이트 상태와 꼬입니다.
      expect(find.text(MyPageStrings.switchChild), findsNothing);
    });

    testWidgets('리포트가 없으면 이야기로 보낸다', (WidgetTester tester) async {
      await pump(
        tester,
        under(
          _Stub(
            list: const ReportList(
              childName: '하늘이',
              totalCount: 0,
              newCount: 0,
              reports: <ReportSummary>[],
            ),
          ),
        ),
      );

      expect(find.text(ReportListStrings.goToHome), findsOneWidget);
    });
  });

  group('리포트 상세', () {
    Widget under(_Stub stub, {int sessionId = 104}) =>
        ChangeNotifierProvider<ReportDetailViewModel>(
          create: (_) => ReportDetailViewModel(
            GetReportDetailUseCase(stub),
            sessionId: sessionId,
          )..load(),
          child: const ReportDetailView(),
        );

    testWidgets('총평이 역량 카드보다 먼저 나온다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(detail: _detail)));

      final double summaryY = tester.getTopLeft(find.text(_detail.summary)).dy;
      final double skillsY = tester
          .getTopLeft(find.text(ReportDetailStrings.skills))
          .dy;
      // 보호자가 스크롤을 안 내려도 "잘했다"는 인상을 먼저 받아야 합니다.
      expect(summaryY, lessThan(skillsY));
    });

    testWidgets('역량 탭은 첫 항목이 기본으로 열려 있다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(detail: _detail)));

      // 탭 전환 없이도 첫 역량(어휘)의 근거 발화·보완이 바로 보입니다.
      expect(find.text('"며느리가 뭐예요?"'), findsOneWidget);
      expect(find.text(ReportDetailStrings.improvement), findsOneWidget);
      expect(find.text('며느리'), findsOneWidget, reason: '질문한 어휘 칩');
      // 다른 탭(표현)의 내용은 아직 보이지 않습니다.
      expect(find.text('너무 놀랐을 것 같아요'), findsNothing);
    });

    testWidgets('역량 탭을 누르면 그 역량만 보인다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(detail: _detail)));

      await tester.tap(find.text('표현'));
      await tester.pumpAndSettle();

      expect(find.text('"너무 놀랐을 것 같아요"'), findsOneWidget);
      // 이전에 보이던 어휘 탭의 내용은 사라집니다 — 한 번에 하나만.
      expect(find.text('"며느리가 뭐예요?"'), findsNothing);
      expect(find.text('며느리'), findsNothing, reason: '어휘 탭 전용 칩');
    });

    testWidgets('대표 발화에 음성 재생 버튼을 두지 않는다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(detail: _detail)));

      // 음성 원본을 저장하지 않는 게 정책입니다. 재생기를 만들면
      // 지킬 수 없는 약속이 됩니다.
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('아직 분석 중이면 목록으로 가는 문을 준다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(), sessionId: 999));

      expect(find.text(ReportDetailStrings.pending), findsOneWidget);
      expect(find.text(ReportDetailStrings.goToList), findsWidgets);
    });
  });

  group('설정', () {
    Widget under(_Stub stub) => ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(
        GetSettingsUseCase(stub),
        SetReportNotificationUseCase(stub),
        SetMarketingConsentUseCase(stub),
      )..load(),
      child: const SettingsView(),
    );

    testWidgets('알림이 최상단이고 네 그룹이 보인다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(settings: _settings)));

      final double notiY = tester
          .getTopLeft(find.text(SettingsStrings.notificationGroup))
          .dy;
      final double infoY = tester
          .getTopLeft(find.text(SettingsStrings.infoGroup))
          .dy;
      expect(notiY, lessThan(infoY));
      expect(find.text(SettingsStrings.policyGroup), findsOneWidget);
      expect(find.text(SettingsStrings.accountGroup), findsOneWidget);
      expect(find.text(SettingsStrings.appVersion('0.1.0')), findsOneWidget);
    });

    testWidgets('아동 개인정보 처리방침이 별도 행이다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(settings: _settings)));

      // 가입 시 별도 동의를 받는 구조와 정합해야 합니다. (F-01)
      expect(find.text(SettingsStrings.childPrivacy), findsOneWidget);
      expect(find.text(SettingsStrings.privacy), findsOneWidget);
    });

    testWidgets('알림 토글이 즉시 반영된다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(settings: _settings)));

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final Switch toggle = tester.widget<Switch>(find.byType(Switch).first);
      expect(toggle.value, isFalse);
    });

    testWidgets('로그아웃은 확인을 한 번 받는다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(settings: _settings)));

      await tester.tap(find.text(SettingsStrings.signOut));
      await tester.pumpAndSettle();

      expect(find.text(SettingsStrings.signOutConfirm), findsOneWidget);
    });

    testWidgets('설정 화면에는 게이트가 없다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(settings: _settings)));

      // 아이가 열어도 유해한 정보가 없어서 게이트를 두지 않습니다.
      expect(find.text(MyPageStrings.gateTitle), findsNothing);
    });
  });
}
