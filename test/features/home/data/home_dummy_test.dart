import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/features/home/data/datasources/home_local_data_source.dart';
import 'package:goodquestion/features/home/data/repositories/home_repository_mock.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';

class _ChildProfiles implements ChildProfileRepository {
  _ChildProfiles(this.children, this.selectedChildId);

  final List<MyPageChild> children;

  @override
  String? selectedChildId;

  @override
  Future<void> createChild({required String name, required int age}) async {}

  @override
  Future<List<MyPageChild>> getChildren() async => children;

  @override
  Future<void> selectChild(String childId) async {
    selectedChildId = childId;
  }
}

class _UnexpectedChildProfiles implements ChildProfileRepository {
  @override
  String? get selectedChildId => null;

  @override
  Future<void> createChild({required String name, required int age}) async =>
      throw StateError('Child API must not be called without a token.');

  @override
  Future<List<MyPageChild>> getChildren() async =>
      throw StateError('Child API must not be called without a token.');

  @override
  Future<void> selectChild(String childId) async =>
      throw StateError('Child API must not be called without a token.');
}

class _UnauthorizedChildProfiles implements ChildProfileRepository {
  @override
  String? get selectedChildId => null;

  @override
  Future<void> createChild({required String name, required int age}) async =>
      throw const UnauthorizedFailure();

  @override
  Future<List<MyPageChild>> getChildren() async =>
      throw const UnauthorizedFailure();

  @override
  Future<void> selectChild(String childId) async =>
      throw const UnauthorizedFailure();
}

/// `assets/dummy/home.json` 이 화면이 기대하는 모양인지 검사합니다.
///
/// 더미가 코드가 아니라 파일이라 **오타가 컴파일에서 안 잡힙니다.** 필드
/// 이름을 하나 잘못 쓰면 앱을 켜야 알게 되는데, 이 테스트가 그걸 대신합니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const HomeRepositoryMock repository = HomeRepositoryMock(
    HomeLocalDataSource(),
    // 테스트에서까지 스켈레톤을 기다릴 이유는 없습니다.
    latency: Duration.zero,
  );

  test('더미가 홈 화면 데이터로 파싱된다', () async {
    final HomeSummary summary = await repository.getHomeSummary();

    expect(summary.child?.name, isNotEmpty);
    expect(summary.hasInProgressSession, isTrue);
    // 홈의 선택지는 3개 이하 — 추천이 4개가 되면 이 테스트가 먼저 웁니다.
    expect(summary.recommendedStories, hasLength(inInclusiveRange(2, 3)));
    expect(summary.planet.stardustBalance, greaterThanOrEqualTo(0));
  });

  test('진행률은 0~1 밖으로 나가지 않는다', () async {
    final HomeSummary summary = await repository.getHomeSummary();
    final session = summary.inProgressSession!;

    expect(session.progress, inInclusiveRange(0, 1));
    expect(session.lastCompletedScene, lessThanOrEqualTo(session.totalScenes));
  });

  test('마이페이지에서 선택한 아이가 홈 프로필에 반영된다', () async {
    final _ChildProfiles profiles = _ChildProfiles(const <MyPageChild>[
      MyPageChild(childId: 'child-1', name: '하늘이', age: 7),
      MyPageChild(childId: 'child-2', name: '바다', age: 10),
    ], 'child-2');
    final HomeRepositoryMock linkedRepository = HomeRepositoryMock(
      const HomeLocalDataSource(),
      childProfileRepository: profiles,
      latency: Duration.zero,
    );

    final HomeSummary summary = await linkedRepository.getHomeSummary();

    expect(summary.child?.name, '바다');
  });

  test('로그인 토큰이 없으면 보호된 아이 API를 호출하지 않는다', () async {
    final HomeRepositoryMock loggedOutRepository = HomeRepositoryMock(
      const HomeLocalDataSource(),
      childProfileRepository: _UnexpectedChildProfiles(),
      tokenProvider: () async => null,
      latency: Duration.zero,
    );

    final HomeSummary summary = await loggedOutRepository.getHomeSummary();

    expect(summary.child, isNull);
    expect(summary.recommendedStories, isNotEmpty);
  });

  test('저장된 토큰이 만료됐어도 홈 기본 콘텐츠를 표시한다', () async {
    final HomeRepositoryMock expiredSessionRepository = HomeRepositoryMock(
      const HomeLocalDataSource(),
      childProfileRepository: _UnauthorizedChildProfiles(),
      tokenProvider: () async => 'expired-token',
      latency: Duration.zero,
    );

    final HomeSummary summary = await expiredSessionRepository.getHomeSummary();

    expect(summary.child, isNull);
    expect(summary.recommendedStories, isNotEmpty);
  });
}
