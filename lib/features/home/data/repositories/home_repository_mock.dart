import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../../domain/entities/child_profile.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_local_data_source.dart';

/// 서버가 준비되기 전까지 홈 데이터를 번들 더미에서 읽는 구현.
///
/// 서버가 나오면 `HomeRepositoryImpl`(RemoteDataSource 사용)을 만들고
/// `injector.dart` 등록 한 줄만 바꿉니다. **화면 코드는 손대지 않습니다.**
/// → `docs/ARCHITECTURE.md` 8장
class HomeRepositoryMock implements HomeRepository {
  const HomeRepositoryMock(
    this._localDataSource, {
    this.childProfileRepository,
    this.latency = const Duration(milliseconds: 500),
  });

  final HomeLocalDataSource _localDataSource;
  final ChildProfileRepository? childProfileRepository;

  /// 스켈레톤이 실제로 보이도록 일부러 지연을 줍니다.
  /// 지연이 없으면 로딩 상태를 아무도 확인하지 못한 채 머지됩니다.
  final Duration latency;

  @override
  Future<HomeSummary> getHomeSummary() async {
    await Future<void>.delayed(latency);
    try {
      final dto = await _localDataSource.fetchHomeSummary();
      final HomeSummary summary = dto.toEntity();
      final ChildProfileRepository? repository = childProfileRepository;
      if (repository == null) return summary;

      final List<MyPageChild> children = await repository.getChildren();
      if (children.isEmpty) {
        return HomeSummary(
          recommendedStories: summary.recommendedStories,
          planet: summary.planet,
          inProgressSession: summary.inProgressSession,
        );
      }

      final String? selectedId = repository.selectedChildId;
      final MyPageChild selected = children.firstWhere(
        (MyPageChild child) => child.childId == selectedId,
        orElse: () => children.first,
      );
      if (selectedId == null) {
        await repository.selectChild(selected.childId);
      }
      return HomeSummary(
        child: ChildProfile(name: selected.name),
        recommendedStories: summary.recommendedStories,
        planet: summary.planet,
        inProgressSession: summary.inProgressSession,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      // 더미 파일 누락(에셋 미등록)·필드 타입 불일치가 여기로 옵니다.
      throw Failure.fromException(ParseException('$e'));
    }
  }
}
