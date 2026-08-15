import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
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
  ReportList? list;
  final ReportDetail? detail;
  AppSettings? settings;
  final Object? error;

  final List<String> markedAsRead = <String>[];
  final List<String> createdChildNames = <String>[];
  final List<int> createdChildAges = <int>[];
  @override
  String? selectedChildId;

  @override
  Future<void> createChild({required String name, required int age}) async {
    if (error != null) throw error!;
    createdChildNames.add(name);
    createdChildAges.add(age);
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
      hasNewReport: current.hasNewReport,
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
  Future<void> markAsRead(String sessionId) async =>
      markedAsRead.add(sessionId);

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
  hasNewReport: true,
);

const MyPageSummary _noChild = MyPageSummary(
  childCount: 0,
  completedStories: 0,
  stardust: 0,
  hasNewReport: false,
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

ReportList _list() => const ReportList(
  childName: '하늘이',
  totalCount: 2,
  newCount: 1,
  reports: <ReportSummary>[
    ReportSummary(
      sessionId: '104',
      storyTitle: '방귀 뀌는 며느리',
      completedAt: null,
      isNew: true,
      playCount: 2,
      highlightUtterance: '며느리가 참으면 배가 아프니까',
    ),
    ReportSummary(
      sessionId: '103',
      storyTitle: '해와 달이 된 오누이',
      completedAt: null,
      isNew: false,
      playCount: 1,
      highlightUtterance: '손을 보여 달라고 할 거예요',
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
      askedWords: <String>['며느리'],
    ),
  ],
  highlight: ReportHighlight(utterance: '부끄러웠을 것 같아요.', reason: '이유를 붙였어요.'),
  questionGroups: <QuestionGroup>[
    QuestionGroup(title: '이야기 주제 이어가기', questions: <String>['너라면?']),
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
  group('MyPageViewModel', () {
    test('아이가 있으면 hasChild 가 true 다', () async {
      final vm = MyPageViewModel(
        GetMyPageSummaryUseCase(_Stub(summary: _summary)),
        CreateMyPageChildUseCase(_Stub(summary: _summary)),
        GetMyPageChildrenUseCase(_Stub(summary: _summary)),
        SelectMyPageChildUseCase(_Stub(summary: _summary)),
      );

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.hasChild, isTrue);
      expect(vm.summary?.canSwitchChild, isTrue);
    });

    test('아이가 없으면 리포트 메뉴를 잠글 근거가 생긴다', () async {
      final vm = MyPageViewModel(
        GetMyPageSummaryUseCase(_Stub(summary: _noChild)),
        CreateMyPageChildUseCase(_Stub(summary: _noChild)),
        GetMyPageChildrenUseCase(_Stub(summary: _noChild)),
        SelectMyPageChildUseCase(_Stub(summary: _noChild)),
      );

      await vm.load();

      expect(vm.hasChild, isFalse);
      expect(vm.summary?.canSwitchChild, isFalse);
    });

    test('실패하면 error 와 메시지가 남는다', () async {
      final vm = MyPageViewModel(
        GetMyPageSummaryUseCase(
          _Stub(error: const NetworkFailure('연결이 끊겼습니다.')),
        ),
        CreateMyPageChildUseCase(_Stub()),
        GetMyPageChildrenUseCase(_Stub()),
        SelectMyPageChildUseCase(_Stub()),
      );

      await vm.load();

      expect(vm.state, ViewState.error);
      expect(vm.errorMessage, '연결이 끊겼습니다.');
    });

    test('아이 프로필을 저장하고 목록을 다시 불러온다', () async {
      final _Stub stub = _Stub(summary: _summary);
      final MyPageViewModel vm = MyPageViewModel(
        GetMyPageSummaryUseCase(stub),
        CreateMyPageChildUseCase(stub),
        GetMyPageChildrenUseCase(stub),
        SelectMyPageChildUseCase(stub),
      );

      final bool saved = await vm.addChild(name: '새봄', age: 7);

      expect(saved, isTrue);
      expect(stub.createdChildNames, <String>['새봄']);
      expect(stub.createdChildAges, <int>[7]);
      expect(vm.summary, same(_summary));
    });

    test('등록된 아이 중 선택한 프로필로 전환한다', () async {
      final _Stub stub = _Stub(
        summary: const MyPageSummary(
          child: _skyChild,
          childCount: 2,
          completedStories: 0,
          stardust: 0,
          hasNewReport: false,
        ),
        childProfiles: _twoChildren,
      );
      final MyPageViewModel vm = MyPageViewModel(
        GetMyPageSummaryUseCase(stub),
        CreateMyPageChildUseCase(stub),
        GetMyPageChildrenUseCase(stub),
        SelectMyPageChildUseCase(stub),
      );
      await vm.load();

      final bool switched = await vm.switchChild('child-2');

      expect(switched, isTrue);
      expect(stub.selectedChildId, 'child-2');
      expect(vm.summary?.child?.name, '바다');
      expect(vm.children, hasLength(2));
    });
  });

  group('ReportListViewModel', () {
    test('목록을 불러온다', () async {
      final _Stub stub = _Stub(list: _list());
      final vm = ReportListViewModel(
        GetReportListUseCase(stub),
        MarkReportAsReadUseCase(stub),
      );

      await vm.load();

      expect(vm.reports, hasLength(2));
      expect(vm.isEmpty, isFalse);
    });

    test('읽으면 그 카드의 NEW 만 사라지고 개수가 줄어든다', () async {
      final _Stub stub = _Stub(list: _list());
      final vm = ReportListViewModel(
        GetReportListUseCase(stub),
        MarkReportAsReadUseCase(stub),
      );
      await vm.load();

      await vm.markAsRead('104');

      expect(stub.markedAsRead, <String>['104']);
      expect(vm.reports.first.isNew, isFalse);
      expect(vm.list?.newCount, 0);
      // 총 개수는 줄지 않습니다 — 읽었다고 리포트가 사라지진 않습니다.
      expect(vm.list?.totalCount, 2);
    });

    test('리포트가 없으면 빈 상태다', () async {
      final _Stub stub = _Stub(
        list: const ReportList(
          childName: '하늘이',
          totalCount: 0,
          newCount: 0,
          reports: <ReportSummary>[],
        ),
      );
      final vm = ReportListViewModel(
        GetReportListUseCase(stub),
        MarkReportAsReadUseCase(stub),
      );

      await vm.load();

      expect(vm.isEmpty, isTrue);
    });
  });

  group('ReportDetailViewModel', () {
    test('리포트가 있으면 pending 이 아니다', () async {
      final vm = ReportDetailViewModel(
        GetReportDetailUseCase(_Stub(detail: _detail)),
        sessionId: '104',
      );

      await vm.load();

      expect(vm.isPending, isFalse);
      expect(vm.report?.skills, hasLength(1));
    });

    test('아직 리포트가 없으면 error 가 아니라 pending 이다', () async {
      final vm = ReportDetailViewModel(
        GetReportDetailUseCase(_Stub()),
        sessionId: '999',
      );

      await vm.load();

      // 완주 직후 생성 지연과 로드 실패는 화면이 달라야 합니다.
      expect(vm.state, ViewState.success);
      expect(vm.isPending, isTrue);
    });
  });

  group('SettingsViewModel', () {
    SettingsViewModel viewModelOf(_Stub stub) => SettingsViewModel(
      GetSettingsUseCase(stub),
      SetReportNotificationUseCase(stub),
      SetMarketingConsentUseCase(stub),
    );

    test('토글이 즉시 반영된다', () async {
      final vm = viewModelOf(_Stub(settings: _settings));
      await vm.load();

      await vm.setReportNotification(enabled: false);

      expect(vm.settings?.reportNotification, isFalse);
      expect(vm.settings?.marketingConsent, isFalse);
    });

    test('마케팅 동의는 토스트를 한 번만 낸다', () async {
      final vm = viewModelOf(_Stub(settings: _settings));
      await vm.load();

      await vm.setMarketingConsent(enabled: true);

      expect(vm.takeMarketingToast(), isTrue);
      // 두 번째 읽기에서는 없어야 합니다 — 리빌드마다 토스트가 뜨면 안 됩니다.
      expect(vm.takeMarketingToast(), isNull);
    });

    test('리포트 알림 토글은 토스트를 내지 않는다', () async {
      final vm = viewModelOf(_Stub(settings: _settings));
      await vm.load();

      await vm.setReportNotification(enabled: false);

      expect(vm.takeMarketingToast(), isNull);
    });
  });

  group('GuardianGate', () {
    test('통과하면 다시 묻지 않고, 로그아웃하면 다시 잠긴다', () {
      final GuardianGate gate = GuardianGate();

      expect(gate.isPassed, isFalse);
      gate.pass();
      expect(gate.isPassed, isTrue);
      gate.reset();
      expect(gate.isPassed, isFalse);
    });
  });
}
