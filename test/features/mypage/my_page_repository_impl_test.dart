import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/exceptions.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/network/dio_client.dart';
import 'package:goodquestion/core/storage/selected_child_store.dart';
import 'package:goodquestion/features/mypage/data/datasources/child_profile_remote_data_source.dart';
import 'package:goodquestion/features/mypage/data/dtos/my_page_dto.dart';
import 'package:goodquestion/features/mypage/data/repositories/my_page_repository_impl.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';

class _Remote extends ChildProfileRemoteDataSource {
  _Remote({this.children = _twoChildren, this.error}) : super(DioClient());

  static const List<Map<String, dynamic>> _twoChildren = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'child-1', 'name': '지우', 'age': 8},
    <String, dynamic>{'id': 'child-2', 'name': '하늘', 'age': 6},
  ];

  final List<Map<String, dynamic>> children;
  final AppException? error;

  /// 서버가 준 별가루 잔액.
  static const int balance = 12;

  /// 어떤 아이로 물어봤는지. 아이가 없으면 아예 부르지 말아야 합니다.
  final List<String> activityCalls = <String>[];

  /// 만든 아이와 동의를 남긴 아이. **동의 없이 아이만 남으면 안 됩니다.**
  final List<String> createdNames = <String>[];
  final List<String> consented = <String>[];

  /// 동의 호출이 몇 번째까지 실패하는가. 1 이면 첫 번째만 실패합니다.
  int consentFailures = 0;

  @override
  Future<List<Map<String, dynamic>>> getChildren() async => children;

  @override
  Future<Map<String, dynamic>> createChild({
    required String name,
    required int birthYear,
  }) async {
    createdNames.add(name);
    return <String, dynamic>{'id': 'child-new', 'name': name, 'age': 8};
  }

  @override
  Future<void> saveConsent(String childId) async {
    if (consentFailures > 0) {
      consentFailures--;
      throw const NetworkException();
    }
    consented.add(childId);
  }

  @override
  Future<ChildActivityDto> getActivity(String childId) async {
    activityCalls.add(childId);
    final AppException? failure = error;
    if (failure != null) throw failure;
    return const ChildActivityDto(completedStories: 3, stardust: balance);
  }
}

/// 기기 저장소 대신 메모리에 들고 있는 가짜. 단위 테스트에는 플러그인
/// 채널이 없어 진짜 보안 저장소를 쓸 수 없습니다.
class _MemoryChildStore extends SelectedChildStore {
  String? _id;

  @override
  String? get value => _id;

  @override
  Future<String?> load() async => _id;

  @override
  Future<void> save(String childId) async => _id = childId;

  @override
  Future<void> clear() async => _id = null;
}

void main() {
  test('완주 편수와 별가루는 선택된 아이의 활동 요약에서 온다', () async {
    final _Remote remote = _Remote();
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(
      remote,
      selectedChild: _MemoryChildStore(),
    );
    await repository.selectChild('child-2');

    final MyPageSummary summary = await repository.getSummary();

    expect(summary.completedStories, 3);
    expect(summary.stardust, 12);
    expect(remote.activityCalls, <String>[
      'child-2',
    ], reason: '선택된 아이 기준입니다 - 목록 첫 아이로 물어보면 다른 아이의 숫자가 뜹니다');
    expect(summary.child?.name, '하늘');
  });

  test('아이를 추가하면 동의도 함께 기록한다', () async {
    // 동의 기록이 없으면 그 아이로 이야기를 시작할 때 서버가 409 로 막습니다.
    final _Remote remote = _Remote();
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(
      remote,
      selectedChild: _MemoryChildStore(),
    );

    await repository.createChild(name: '새봄', age: 7);

    expect(remote.createdNames, <String>['새봄']);
    expect(remote.consented, <String>['child-new']);
    expect(repository.selectedChildId, 'child-new');
  });

  test('동의가 한 번 실패해도 다시 시도해 끝낸다', () async {
    final _Remote remote = _Remote()..consentFailures = 1;
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(
      remote,
      selectedChild: _MemoryChildStore(),
    );

    await repository.createChild(name: '새봄', age: 7);

    expect(remote.consented, <String>['child-new']);
  });

  test('동의를 끝내 못 남기면 실패로 올리고 그 아이를 고르지 않는다', () async {
    // 반쯤 만들어진 아이로 화면을 바꿔 두면 보호자가 그 아이로 이야기를
    // 시작했다가 409 를 만납니다.
    final _Remote remote = _Remote()..consentFailures = 2;
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(
      remote,
      selectedChild: _MemoryChildStore(),
    );
    await repository.selectChild('child-2');

    await expectLater(
      repository.createChild(name: '새봄', age: 7),
      throwsA(isA<Failure>()),
    );
    expect(remote.consented, isEmpty);
    expect(repository.selectedChildId, 'child-2');
  });

  test('고른 아이는 저장소에 남아 다음 실행에서 되살아난다', () async {
    final _MemoryChildStore store = _MemoryChildStore();
    await MyPageRepositoryImpl(
      _Remote(),
      selectedChild: store,
    ).selectChild('child-2');

    // 앱을 다시 켠 상황: 새 리포지토리가 같은 저장소를 읽습니다.
    final MyPageRepositoryImpl reopened = MyPageRepositoryImpl(
      _Remote(),
      selectedChild: store,
    );

    expect(reopened.selectedChildId, 'child-2');
    expect((await reopened.getSummary()).child?.name, '하늘');
  });

  test('저장된 아이가 목록에 없으면 첫 번째 아이로 되돌린다', () async {
    // 그 아이가 지워졌거나 다른 계정으로 로그인한 경우입니다. 그대로 쓰면
    // 남의 아이를 부릅니다.
    final _MemoryChildStore store = _MemoryChildStore();
    await store.save('child-gone');
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(
      _Remote(),
      selectedChild: store,
    );

    final MyPageSummary summary = await repository.getSummary();

    expect(summary.child?.childId, 'child-1');
    expect(store.value, 'child-1', reason: '되돌린 선택도 저장돼야 합니다');
  });

  test('목록에 없는 아이는 고를 수 없고 저장도 안 된다', () async {
    final _MemoryChildStore store = _MemoryChildStore();
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(
      _Remote(),
      selectedChild: store,
    );

    await expectLater(
      repository.selectChild('child-gone'),
      throwsA(isA<Failure>()),
    );
    expect(store.value, isNull);
  });

  test('아이가 없으면 활동 요약을 부르지 않고 두 값 모두 0으로 둔다', () async {
    final _Remote remote = _Remote(children: const <Map<String, dynamic>>[]);

    final MyPageSummary summary = await MyPageRepositoryImpl(
      remote,
      selectedChild: _MemoryChildStore(),
    ).getSummary();

    expect(summary.completedStories, 0);
    expect(summary.stardust, 0);
    expect(summary.child, isNull);
    expect(remote.activityCalls, isEmpty);
  });

  test('활동 요약 조회가 실패해도 마이페이지는 그려진다 - 숫자만 0', () async {
    // 이 화면은 프로필·리포트·설정으로 가는 허브입니다. 숫자 하나 때문에
    // 화면 전체가 에러가 되면 보호자는 아무 데도 가지 못합니다.
    final _Remote remote = _Remote(
      error: const NetworkException('네트워크에 연결할 수 없습니다.'),
    );

    final MyPageSummary summary = await MyPageRepositoryImpl(
      remote,
      selectedChild: _MemoryChildStore(),
    ).getSummary();

    expect(summary.completedStories, 0);
    expect(summary.stardust, 0);
    expect(summary.child?.name, '지우');
    expect(summary.childCount, 2);
  });

  test('활동 응답은 activity 래퍼 없이 두 필드가 최상위에 온다', () {
    final ChildActivityDto activity = ChildActivityDto.fromJson(
      <String, dynamic>{'completedStories': 1, 'stardust': 12},
    );
    expect(activity.completedStories, 1);
    expect(activity.stardust, 12);

    // 번들 더미(MyPageSummaryDto)의 모양으로 파싱하면 두 값이 조용히 0이 됩니다.
    expect(
      () => ChildActivityDto.fromJson(<String, dynamic>{
        'activity': <String, dynamic>{'completedStories': 1, 'stardust': 12},
      }),
      throwsA(isA<ParseException>()),
    );
  });

  test('아이 목록 조회가 실패하면 그대로 실패한다 - 없는 화면을 그릴 수는 없다', () async {
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(
      _FailingChildrenRemote(),
      selectedChild: _MemoryChildStore(),
    );

    await expectLater(repository.getSummary(), throwsA(isA<Failure>()));
  });
}

class _FailingChildrenRemote extends ChildProfileRemoteDataSource {
  _FailingChildrenRemote() : super(DioClient());

  @override
  Future<List<Map<String, dynamic>>> getChildren() async =>
      throw const NetworkException('네트워크에 연결할 수 없습니다.');
}
