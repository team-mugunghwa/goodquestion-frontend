import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../../domain/entities/child_profile.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/entities/planet_summary.dart';
import '../../domain/entities/recommended_story.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_data_source.dart';
import '../dtos/home_response_dto.dart';

/// 서버 `GET /children/{childId}/home` 을 홈 화면 데이터로 바꿉니다.
///
/// `HomeResponse` 에는 아이 정보가 없어서, 여기서 [ChildProfileRepository]
/// 로 아이 목록을 먼저 받아 childId 를 정하고, 응답을 받은 뒤 선택된 아이로
/// [ChildProfile] 을 합성합니다. → `docs/ARCHITECTURE.md` 8장
class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._remote, this._childProfileRepository);

  final HomeRemoteDataSource _remote;
  final ChildProfileRepository _childProfileRepository;

  @override
  Future<HomeSummary> getHomeSummary() async {
    try {
      final List<MyPageChild> children = await _childProfileRepository
          .getChildren();
      if (children.isEmpty) {
        // 아이 프로필이 아직 없으면 /home 을 부를 대상이 없습니다.
        // 홈은 그대로 보여 주고, 진입할 때만 프로필 생성으로 유도합니다.
        return const HomeSummary(
          recommendedStories: <RecommendedStory>[],
          planet: PlanetSummary(stardustBalance: 0),
        );
      }

      final MyPageChild selected = _resolveSelected(children);
      if (_childProfileRepository.selectedChildId == null) {
        await _childProfileRepository.selectChild(selected.childId);
      }

      final HomeResponseDto dto = await _remote.fetchHome(selected.childId);
      return HomeSummary(
        child: ChildProfile(name: selected.name),
        inProgressSession: dto.inProgressSession?.toEntity(),
        recommendedStories: dto.recommendedStories
            .map((StoryCardResponseDto story) => story.toEntity())
            .toList(growable: false),
        planet: dto.planetWidget.toEntity(),
      );
    } on Failure {
      // ChildProfileRepository(mypage) 는 이미 Failure 를 던집니다.
      // 여기서 다시 AppException 으로 감싸면 이중 래핑입니다.
      rethrow;
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }

  /// selectedChildId 가 목록에 있으면 그 아이, 없으면 첫 번째 아이를
  /// **로컬에서** 고릅니다. `selectChild` 재호출로 왕복을 늘리지 않습니다.
  MyPageChild _resolveSelected(List<MyPageChild> children) {
    final String? selectedId = _childProfileRepository.selectedChildId;
    if (selectedId == null) return children.first;
    for (final MyPageChild child in children) {
      if (child.childId == selectedId) return child;
    }
    return children.first;
  }
}
