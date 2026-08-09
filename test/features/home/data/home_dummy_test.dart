import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/home/data/datasources/home_local_data_source.dart';
import 'package:goodquestion/features/home/data/repositories/home_repository_mock.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';

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
}
