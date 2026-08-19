import '../../../../core/error/failure.dart';
import '../../../home/domain/entities/home_summary.dart';
import '../../../home/domain/entities/in_progress_session.dart';
import '../../../home/domain/repositories/home_repository.dart';
import '../repositories/story_repository.dart';

/// 이야기를 시작합니다. **이미 진행 중이던 세션이 있으면 그 세션으로
/// 이어갑니다.**
///
/// `POST /children/{childId}/sessions` 는 부를 때마다 새 세션을 만듭니다 -
/// 서버에는 "있으면 이어받고 없으면 만들기"가 없습니다. 그래서 목록에서
/// 같은 이야기로 다시 들어와 시작하기를 누르면 듣던 이야기가 통째로
/// 사라졌습니다. 진행 중 세션 확인은 여기서 합니다 - 화면에 흩뿌리면
/// 반드시 한 군데를 빠뜨립니다.
///
/// **묻지 않고 이어갑니다.** 저학년 아이에게 "이어하기 / 처음부터"를
/// 물으면 되돌릴 수 없는 선택(처음부터 = 듣던 이야기 폐기)을 글로 읽고
/// 판단해야 합니다. 홈의 이어하기 카드와도 같은 동작이라 앱 안에서 규칙이
/// 하나로 유지됩니다. 처음부터 다시 하고 싶으면 재생 화면 멈춤 카드의
/// "처음부터 다시하기"를 쓰면 됩니다 - 듣던 세션을 끝내고
/// [StoryRepository.startSession] 으로 새 세션을 만듭니다.
/// → `features/play/presentation/views/play_view.dart`
class StartStorySessionUseCase {
  const StartStorySessionUseCase(this._repository, this._homeRepository);

  final StoryRepository _repository;

  /// 진행 중 세션은 홈 응답에만 실려 옵니다(`inProgressSession`).
  final HomeRepository _homeRepository;

  Future<String> call(String storyId) async =>
      await _resumableSessionId(storyId) ??
      await _repository.startSession(storyId);

  /// 이 이야기의 진행 중 세션 id. 없으면 `null`.
  ///
  /// 홈은 **가장 최근 진행 중 세션 하나만** 줍니다. 다른 이야기를 진행
  /// 중이면 storyId 가 달라 매칭되지 않고, 그때는 새로 시작하는 것이 맞습니다.
  Future<String?> _resumableSessionId(String storyId) async {
    try {
      final HomeSummary home = await _homeRepository.getHomeSummary();
      final InProgressSession? session = home.inProgressSession;
      if (session == null || session.storyId != storyId) return null;
      return session.sessionId;
    } on Failure {
      // 확인에 실패했다고 시작하기를 막지는 않습니다 - 최악의 경우 세션이
      // 하나 더 생길 뿐이라, 아이를 못 들어가게 하는 것보다 안전한 실패입니다.
      return null;
    }
  }
}
