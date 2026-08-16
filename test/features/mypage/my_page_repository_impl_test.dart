import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/exceptions.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/network/dio_client.dart';
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

  @override
  Future<List<Map<String, dynamic>>> getChildren() async => children;

  @override
  Future<ChildActivityDto> getActivity(String childId) async {
    activityCalls.add(childId);
    final AppException? failure = error;
    if (failure != null) throw failure;
    return const ChildActivityDto(completedStories: 3, stardust: balance);
  }
}

void main() {
  test('완주 편수와 별가루는 선택된 아이의 활동 요약에서 온다', () async {
    final _Remote remote = _Remote();
    final MyPageRepositoryImpl repository = MyPageRepositoryImpl(remote);
    await repository.selectChild('child-2');

    final MyPageSummary summary = await repository.getSummary();

    expect(summary.completedStories, 3);
    expect(summary.stardust, 12);
    expect(remote.activityCalls, <String>[
      'child-2',
    ], reason: '선택된 아이 기준입니다 - 목록 첫 아이로 물어보면 다른 아이의 숫자가 뜹니다');
    expect(summary.child?.name, '하늘');
  });

  test('아이가 없으면 활동 요약을 부르지 않고 두 값 모두 0으로 둔다', () async {
    final _Remote remote = _Remote(children: const <Map<String, dynamic>>[]);

    final MyPageSummary summary = await MyPageRepositoryImpl(
      remote,
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
