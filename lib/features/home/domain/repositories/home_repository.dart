import '../entities/home_summary.dart';

/// 홈 화면 데이터의 출처.
///
/// **추상입니다.** 구현이 더미 JSON 이든 서버든 화면은 알 필요가 없습니다.
/// 서버가 나오면 `HomeRepositoryImpl` 을 만들어 DI 한 줄만 바꿉니다.
/// → `docs/ARCHITECTURE.md` 8장
abstract class HomeRepository {
  /// 상단 바·이어하기·추천·행성 위젯에 필요한 값을 한 번에 가져옵니다.
  Future<HomeSummary> getHomeSummary();
}
