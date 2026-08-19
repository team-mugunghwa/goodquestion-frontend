import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../../domain/entities/story_catalog.dart';
import '../../domain/entities/story_detail.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_remote_data_source.dart';

/// 이야기 목록·상세·세션 시작을 서버에 붙입니다. mypage 패턴을 따릅니다.
/// → `lib/features/mypage/data/repositories/my_page_repository_impl.dart`
class StoryRepositoryImpl implements StoryRepository {
  const StoryRepositoryImpl(this._remote, this._childProfileRepository);

  final StoryRemoteDataSource _remote;
  final ChildProfileRepository _childProfileRepository;

  @override
  Future<StoryCatalog> getCatalog() =>
      _guard(() async => (await _remote.fetchCatalog()).toEntity());

  /// 없는 storyId 는 404(`NOT_FOUND`) 로 온다 — 예외가 아니라 `null` 로 바꿔
  /// 돌려줍니다. (`StoryRepository.getStoryDetail` 계약)
  @override
  Future<StoryDetail?> getStoryDetail(String storyId) async {
    try {
      return (await _remote.fetchDetail(storyId)).toEntity();
    } on ServerException catch (e) {
      if (e.statusCode == 404) return null;
      throw Failure.fromException(e);
    } on Failure {
      rethrow;
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }

  @override
  Future<Set<String>> getCompletedStoryIds() => _guard(() async {
    final String childId = await _resolveChildId();
    return (await _remote.fetchCompletedStoryIds(childId)).toSet();
  });

  @override
  Future<String> startSession(String storyId) => _guard(() async {
    final String childId = await _resolveChildId();
    return _remote.startSession(childId: childId, storyId: storyId);
  });

  /// 세션은 아이 소유라 childId 가 필요합니다. 홈과 같은 방식으로 고릅니다 —
  /// selectedChildId 가 있으면 그 아이, 없으면 첫 번째 아이.
  Future<String> _resolveChildId() async {
    final List<MyPageChild> children = await _childProfileRepository
        .getChildren();
    if (children.isEmpty) {
      throw const UnknownFailure('아이 프로필을 먼저 만들어 주세요.');
    }
    final String? selectedId = _childProfileRepository.selectedChildId;
    MyPageChild selected = children.first;
    if (selectedId != null) {
      for (final MyPageChild child in children) {
        if (child.childId == selectedId) {
          selected = child;
          break;
        }
      }
    } else {
      await _childProfileRepository.selectChild(selected.childId);
    }
    return selected.childId;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
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
}
