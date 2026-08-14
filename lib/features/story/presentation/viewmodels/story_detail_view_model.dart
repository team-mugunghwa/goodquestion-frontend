import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/story_detail.dart';
import '../../domain/usecases/get_story_detail_use_case.dart';
import '../../domain/usecases/start_story_session_use_case.dart';

/// 이야기 상세의 상태.
///
/// 이 화면에는 상태가 셋 있습니다 — 데이터 로딩, **없는 이야기**, 그리고
/// 시작하기의 처리 중. 앞의 둘을 뭉뚱그리면 잘못된 주소로 들어온 아이에게
/// "다시 불러오기"를 권하게 되는데, 눌러도 영원히 안 됩니다.
class StoryDetailViewModel extends BaseViewModel {
  StoryDetailViewModel(
    this._getStoryDetail,
    this._startSession, {
    required this.storyId,
  });

  final GetStoryDetailUseCase _getStoryDetail;
  final StartStorySessionUseCase _startSession;
  final String storyId;

  StoryDetail? _story;
  bool _starting = false;

  StoryDetail? get story => _story;

  /// 로드는 성공했는데 그런 이야기가 없는 경우.
  bool get isNotFound => state.isSuccess && _story == null;

  /// 시작하기를 누른 뒤 화면이 넘어가기 전까지. 버튼을 잠급니다.
  bool get isStarting => _starting;

  Future<void> load() => guard(() async {
    _story = await _getStoryDetail(storyId);
  });

  /// 세션을 만들고 sessionId 를 돌려줍니다. 실패하면 `null`.
  ///
  /// **ViewModel 이 화면을 옮기지 않습니다.** 값만 주고, 이동은 View 가 합니다.
  /// (`docs/ARCHITECTURE.md` 4장)
  Future<String?> start() async {
    if (_starting || _story == null) return null;
    _starting = true;
    safeNotify();
    try {
      return await _startSession(storyId);
    } catch (e) {
      setError(e);
      return null;
    } finally {
      _starting = false;
      safeNotify();
    }
  }
}
