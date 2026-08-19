import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/home/domain/entities/child_profile.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/home/domain/entities/planet_summary.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
import 'package:goodquestion/features/home/domain/usecases/get_home_summary_use_case.dart';
import 'package:goodquestion/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';
import 'package:goodquestion/features/mypage/domain/usecases/my_page_use_cases.dart';

class _StubRepository implements HomeRepository {
  _StubRepository({this.summary, this.error});

  final HomeSummary? summary;
  final Object? error;

  @override
  Future<HomeSummary> getHomeSummary() async {
    if (error != null) throw error!;
    return summary!;
  }
}

HomeSummary _summary({ChildProfile? child}) => HomeSummary(
  child: child,
  recommendedStories: const [],
  planet: const PlanetSummary(stardustBalance: 7),
);

void main() {
  HomeViewModel viewModelOf(HomeRepository repository) => HomeViewModel(
    GetHomeSummaryUseCase(repository),
    const GetMyPageChildrenUseCase(_StubChildren()),
    const SelectMyPageChildUseCase(_StubChildren()),
  );

  test('처음에는 idle 이고 데이터가 없다', () {
    final vm = viewModelOf(_StubRepository(summary: _summary()));

    expect(vm.state, ViewState.idle);
    expect(vm.summary, isNull);
    expect(vm.hasChild, isFalse);
  });

  test('load 하면 loading 을 거쳐 success 가 된다', () async {
    final vm = viewModelOf(
      _StubRepository(
        summary: _summary(child: const ChildProfile(name: '하늘이')),
      ),
    );

    final states = <ViewState>[];
    vm.addListener(() => states.add(vm.state));

    await vm.load();

    // 스켈레톤을 그릴 기회 없이 success 로 건너뛰면 화면이 덜컹입니다.
    expect(states, <ViewState>[ViewState.loading, ViewState.success]);
    expect(vm.summary?.child?.name, '하늘이');
    expect(vm.hasChild, isTrue);
  });

  test('실패하면 error 와 사람이 읽을 메시지가 남는다', () async {
    final vm = viewModelOf(
      _StubRepository(error: const NetworkFailure('연결이 끊겼습니다.')),
    );

    await vm.load();

    expect(vm.state, ViewState.error);
    expect(vm.errorMessage, '연결이 끊겼습니다.');
    expect(vm.summary, isNull);
  });

  test('아이 프로필이 없으면 hasChild 가 false 다', () async {
    final vm = viewModelOf(_StubRepository(summary: _summary()));

    await vm.load();

    // 그래도 화면은 성공 상태입니다 — 홈은 보여 주고, 진입할 때만 막습니다.
    expect(vm.state, ViewState.success);
    expect(vm.hasChild, isFalse);
  });
}

/// 아이 목록·전환은 홈의 곁가지라 테스트용 고정 저장소를 씁니다.
class _StubChildren implements ChildProfileRepository {
  @override
  Future<void> updateChild({
    required String childId,
    required String name,
    required int age,
  }) async {}
  const _StubChildren();

  @override
  String? get selectedChildId => 'c1';

  @override
  Future<void> createChild({required String name, required int age}) async {}

  @override
  Future<List<MyPageChild>> getChildren() async => const <MyPageChild>[
    MyPageChild(childId: 'c1', name: '하늘이', age: 8),
  ];

  @override
  Future<void> selectChild(String childId) async {}
}
