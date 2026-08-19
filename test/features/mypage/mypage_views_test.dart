import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/di/injector.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/network/dio_client.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/core/widgets/confirm_actions.dart';
import 'package:goodquestion/features/mypage/data/datasources/settings_remote_data_source.dart';
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
import 'package:goodquestion/features/mypage/presentation/widgets/settings_sections.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// 게이트가 부르는 보호자 조회. 이메일 계정(provider null)이라 비밀번호를
/// 묻는 쪽으로 갑니다.
class _GateRemote extends SettingsRemoteDataSource {
  _GateRemote() : super(DioClient());

  @override
  Future<Map<String, dynamic>> getParent() async => <String, dynamic>{
    'provider': null,
  };

  @override
  Future<void> verifyPassword(String password) async {}
}

class _Stub
    implements
        MyPageRepository,
        ChildProfileRepository,
        ReportRepository,
        SettingsRepository {
  _Stub({
    this.summary,
    this.childProfiles,
    this.list,
    this.detail,
    this.settings,
    this.error,
  });

  MyPageSummary? summary;
  final List<MyPageChild>? childProfiles;
  final ReportList? list;
  final ReportDetail? detail;
  AppSettings? settings;
  final Object? error;
  @override
  String? selectedChildId;

  /// 새로 만든 아이 · 고친 아이. **섞이면 안 됩니다** - 수정 버튼이 추가로
  /// 이어지면 아이가 하나 더 생깁니다.
  final List<String> created = <String>[];
  final List<String> updated = <String>[];

  @override
  Future<void> createChild({required String name, required int age}) async {
    if (error != null) throw error!;
    created.add('$name/$age');
  }

  @override
  Future<void> updateChild({
    required String childId,
    required String name,
    required int age,
  }) async {
    if (error != null) throw error!;
    updated.add('$childId/$name/$age');
  }

  @override
  Future<List<MyPageChild>> getChildren() async =>
      childProfiles ??
      (summary?.child == null
          ? <MyPageChild>[]
          : <MyPageChild>[summary!.child!]);

  @override
  Future<void> selectChild(String childId) async {
    selectedChildId = childId;
    final MyPageChild selected = (await getChildren()).firstWhere(
      (MyPageChild child) => child.childId == childId,
    );
    final MyPageSummary current = summary!;
    summary = MyPageSummary(
      child: selected,
      childCount: current.childCount,
      completedStories: current.completedStories,
      stardust: current.stardust,
    );
  }

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
  Future<ReportDetail?> getReportDetail(String sessionId) async {
    if (error != null) throw error!;
    return detail;
  }

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
  child: MyPageChild(childId: 'child-1', name: '하늘이', age: 8),
  childCount: 2,
  completedStories: 3,
  stardust: 7,
);

const MyPageSummary _noChild = MyPageSummary(
  childCount: 0,
  completedStories: 0,
  stardust: 0,
);

const MyPageChild _skyChild = MyPageChild(
  childId: 'child-1',
  name: '하늘이',
  age: 7,
);
const MyPageChild _seaChild = MyPageChild(
  childId: 'child-2',
  name: '바다',
  age: 10,
);
const List<MyPageChild> _twoChildren = <MyPageChild>[_skyChild, _seaChild];

const ReportList _list = ReportList(
  childName: '하늘이',
  totalCount: 2,
  reports: <ReportSummary>[
    ReportSummary(
      sessionId: '104',
      storyTitle: '방귀 뀌는 며느리',
      completedAt: null,
      playCount: 2,
      highlightUtterance: '며느리가 참으면 배가 아프니까',
    ),
  ],
);

const ReportDetail _detail = ReportDetail(
  sessionId: '104',
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
  // 마이페이지가 게이트를, 게이트가 보호자 조회를 getIt 에서 꺼내 씁니다.
  setUpAll(() {
    getIt
      ..registerLazySingleton<GuardianGate>(GuardianGate.new)
      ..registerLazySingleton<SettingsRemoteDataSource>(_GateRemote.new);
  });
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
    // 설정이 이 화면 안으로 들어와서 ViewModel 두 개가 함께 필요합니다.
    Widget under(_Stub stub) => MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<MyPageViewModel>(
          create: (_) => MyPageViewModel(
            GetMyPageSummaryUseCase(stub),
            CreateMyPageChildUseCase(stub),
            UpdateMyPageChildUseCase(stub),
            GetMyPageChildrenUseCase(stub),
            SelectMyPageChildUseCase(stub),
          )..load(),
        ),
        ChangeNotifierProvider<SettingsViewModel>(
          create: (_) => SettingsViewModel(
            GetSettingsUseCase(stub),
            SetReportNotificationUseCase(stub),
            SetMarketingConsentUseCase(stub),
          )..load(),
        ),
      ],
      child: const MyPageView(),
    );

    testWidgets('프로필 카드·메뉴·하단 내비가 보인다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(summary: _summary, settings: _settings)));

      expect(find.text('하늘이 · 8살'), findsOneWidget);
      expect(find.text(MyPageStrings.completedStories(3)), findsOneWidget);
      expect(find.text(MyPageStrings.report), findsOneWidget);
      // 설정이 이 화면 안으로 들어왔습니다 — 별도 진입 줄 대신
      // 알림 묶음이 바로 보입니다.
      expect(find.text(SettingsStrings.notificationGroup), findsOneWidget);
      expect(find.text(SettingsStrings.signOut), findsOneWidget);
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
      expect(find.text(MyPageStrings.gatePasswordLabel), findsOneWidget);
      // 취소하면 아무 데도 안 갑니다.
      await tester.tap(find.text(MyPageStrings.gateCancel));
      await tester.pumpAndSettle();
      expect(getIt<GuardianGate>().isPassed, isFalse);
    });

    testWidgets('프로필 전환에서 등록된 아이를 선택한다', (WidgetTester tester) async {
      final _Stub stub = _Stub(
        summary: const MyPageSummary(
          child: _skyChild,
          childCount: 2,
          completedStories: 0,
          stardust: 0,
        ),
        childProfiles: _twoChildren,
      );
      await pump(tester, under(stub));

      await tester.tap(find.text(MyPageStrings.switchChild));
      await tester.pumpAndSettle();

      expect(find.text('하늘이'), findsOneWidget);
      expect(find.text('바다'), findsOneWidget);
      expect(find.text('7살'), findsWidgets);
      expect(find.text('10살'), findsOneWidget);

      await tester.tap(find.text('바다'));
      await tester.pumpAndSettle();

      expect(stub.selectedChildId, 'child-2');
      expect(find.text('바다 · 10살'), findsOneWidget);
    });

    testWidgets('연필을 누르면 지금 값이 채워진 수정 폼이 열린다', (WidgetTester tester) async {
      final _Stub stub = _Stub(summary: _summary);
      await pump(tester, under(stub));

      await tester.tap(find.byTooltip(MyPageStrings.editChild));
      await tester.pumpAndSettle();

      // 빈 폼이 열리면 저장할 때 아이가 하나 더 생깁니다.
      expect(find.text('아이 프로필 수정'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '하늘이'), findsOneWidget);
      expect(find.text('8세'), findsOneWidget);
      expect(find.text('수정'), findsOneWidget);
    });

    testWidgets('수정 폼을 저장하면 그 아이를 고치고 새로 만들지 않는다', (WidgetTester tester) async {
      final _Stub stub = _Stub(summary: _summary);
      await pump(tester, under(stub));

      await tester.tap(find.byTooltip(MyPageStrings.editChild));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '하늘');
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();

      expect(stub.updated, <String>['child-1/하늘/8']);
      expect(stub.created, isEmpty, reason: '수정인데 아이가 하나 더 생기면 안 됩니다');
      expect(find.text('아이 프로필을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('아이 추가는 빈 폼에서 새로 만든다', (WidgetTester tester) async {
      final _Stub stub = _Stub(summary: _summary);
      await pump(tester, under(stub));

      await tester.tap(find.text(MyPageStrings.addChild));
      await tester.pumpAndSettle();

      // 메뉴 타일에도 같은 말이 있어 시트의 안내문으로 가립니다.
      expect(find.text('아이의 이름과 나이를 입력해 주세요.'), findsOneWidget);
      // 지금 아이 이름이 남아 있으면 그 아이를 고치는 것처럼 보입니다.
      expect(find.widgetWithText(TextFormField, '하늘이'), findsNothing);

      await tester.enterText(find.byType(TextFormField), '새봄');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(stub.created, <String>['새봄/7']);
      expect(stub.updated, isEmpty);
      expect(find.text('아이 프로필을 추가했습니다.'), findsOneWidget);
    });

    testWidgets('동의하지 않으면 아이를 만들지 않는다', (WidgetTester tester) async {
      final _Stub stub = _Stub(summary: _summary);
      await pump(tester, under(stub));

      await tester.tap(find.text(MyPageStrings.addChild));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '새봄');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // 동의 없이 아이만 만들어지면 그 아이로는 이야기를 시작할 수 없습니다
      // (서버가 CONSENT_REQUIRED 로 막습니다).
      expect(find.text(MyPageStrings.childConsentMissing), findsOneWidget);
      expect(stub.created, isEmpty);
    });

    testWidgets('수정 폼에는 동의 체크가 없다', (WidgetTester tester) async {
      final _Stub stub = _Stub(summary: _summary);
      await pump(tester, under(stub));

      await tester.tap(find.byTooltip(MyPageStrings.editChild));
      await tester.pumpAndSettle();

      // 이미 동의를 받아 둔 아이를 고치는 자리입니다.
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text(MyPageStrings.childConsentLabel), findsNothing);
    });

    testWidgets('실패해도 메뉴는 남는다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(error: const NetworkFailure())));

      expect(find.text(AppStrings.retry), findsOneWidget);
      // 프로필을 못 불러와도 리포트·관리 메뉴는 남아 있어야 합니다.
      expect(find.text(MyPageStrings.report), findsOneWidget);
      expect(find.text(MyPageStrings.addChild), findsOneWidget);
    });
  });

  group('리포트 목록', () {
    Widget under(_Stub stub) => ChangeNotifierProvider<ReportListViewModel>(
      create: (_) => ReportListViewModel(GetReportListUseCase(stub))..load(),
      child: const ReportListView(),
    );

    testWidgets('요약 스트립과 카드가 보인다 - NEW 배지는 없다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(list: _list)));

      expect(find.text(ReportListStrings.summary(2)), findsOneWidget);
      expect(find.text('방귀 뀌는 며느리'), findsOneWidget);
      // 서버가 열람 여부를 저장하지 않아 앱을 다시 켤 때마다 전부 NEW 가
      // 됐습니다. 틀린 신호를 남기느니 없앴습니다.
      expect(find.text('NEW'), findsNothing);
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
              reports: <ReportSummary>[],
            ),
          ),
        ),
      );

      expect(find.text(ReportListStrings.goToHome), findsOneWidget);
    });
  });

  group('리포트 상세', () {
    Widget under(_Stub stub, {String sessionId = '104'}) =>
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
      await pump(tester, under(_Stub(), sessionId: '999'));

      expect(find.text(ReportDetailStrings.pending), findsOneWidget);
      expect(find.text(ReportDetailStrings.goToList), findsWidgets);
    });
  });

  group('설정', () {
    // 설정은 마이페이지 안에 펼쳐지는 묶음이 됐습니다. 화면 전체가 아니라
    // 그 묶음만 세워 검사합니다.
    Widget under(_Stub stub) => ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(
        GetSettingsUseCase(stub),
        SetReportNotificationUseCase(stub),
        SetMarketingConsentUseCase(stub),
      )..load(),
      child: Scaffold(
        body: Consumer<SettingsViewModel>(
          builder: (_, SettingsViewModel vm, _) =>
              SingleChildScrollView(child: SettingsSections(vm: vm)),
        ),
      ),
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
      // 취소와 로그아웃이 대등하게 놓입니다 - 되돌리기 어려운 동작이라
      // 한쪽으로 기울면 안 됩니다.
      expect(find.byType(ConfirmActions), findsOneWidget);
    });

    testWidgets('설정 화면에는 게이트가 없다', (WidgetTester tester) async {
      await pump(tester, under(_Stub(settings: _settings)));

      // 아이가 열어도 유해한 정보가 없어서 게이트를 두지 않습니다.
      expect(find.text(MyPageStrings.gateTitle), findsNothing);
    });
  });
}
