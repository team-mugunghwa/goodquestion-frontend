import '../../../../core/presentation/base_view_model.dart';
import '../../../free_talk/domain/entities/free_talk.dart';
import '../../../free_talk/domain/repositories/free_talk_repository.dart';
import '../../domain/entities/story_detail.dart';
import '../../domain/usecases/get_story_detail_use_case.dart';
import '../../domain/usecases/start_story_session_use_case.dart';

/// 이야기 상세의 상태.
///
/// 이 화면에는 상태가 셋 있습니다 — 데이터 로딩, **없는 이야기**, 그리고
/// 시작하기의 처리 중. 앞의 둘을 뭉뚱그리면 잘못된 주소로 들어온 아이에게
/// "다시 불러오기"를 권하게 되는데, 눌러도 영원히 안 됩니다.
///
/// 여기에 넷째가 하나 더 붙습니다 — **이미 완주한 이야기인지**. 완주한
/// 이야기에만 후속 자유 대화 진입점이 뜹니다. → [canFreeTalk]
class StoryDetailViewModel extends BaseViewModel {
  StoryDetailViewModel(
    this._getStoryDetail,
    this._startSession, {
    required this.storyId,
    this.freeTalk,
  });

  final GetStoryDetailUseCase _getStoryDetail;
  final StartStorySessionUseCase _startSession;

  /// 후속 자유 대화 진입점을 판별할 저장소. `null` 이면 진입점을 아예 찾지
  /// 않습니다 — 미리보기·위젯 테스트가 자유 대화 서버까지 세울 필요는 없습니다.
  ///
  /// 이름에 밑줄이 없는 건 `this.freeTalk` 로 받기 위해서일 뿐입니다
  /// (Dart 는 밑줄로 시작하는 이름 있는 매개변수를 금지합니다).
  /// **화면에서 직접 부르지 마세요** — 판정은 [canFreeTalk] 하나로 합니다.
  final FreeTalkRepository? freeTalk;

  final String storyId;

  StoryDetail? _story;
  bool _starting = false;
  List<FreeTalkCharacter> _freeTalkCharacters = const <FreeTalkCharacter>[];

  StoryDetail? get story => _story;

  /// 로드는 성공했는데 그런 이야기가 없는 경우.
  bool get isNotFound => state.isSuccess && _story == null;

  /// 시작하기를 누른 뒤 화면이 넘어가기 전까지. 버튼을 잠급니다.
  bool get isStarting => _starting;

  /// 이 이야기의 인물과 이어서 대화할 수 있는지. → [_probeFreeTalk]
  bool get canFreeTalk => _freeTalkCharacters.isNotEmpty;

  /// 친구들 카드에 얼굴로 늘어놓을 인물들. 서버가 준 순서를 그대로 씁니다 —
  /// 이야기에 나온 차례라 아이가 만난 순서와 같습니다.
  List<FreeTalkCharacter> get freeTalkCharacters => _freeTalkCharacters;

  /// **이미 완주한 이야기인지.** 지금은 [canFreeTalk] 와 같은 근거(인물 목록이
  /// 돌아왔는지)를 씁니다. 화면이 뜻이 다른 두 가지(완주 표시 · 대화 진입점)를
  /// 같은 이름으로 읽지 않도록 이름을 나눠 둡니다 — 서버가 완주 필드를 주면
  /// 이쪽만 그 값으로 갈아 끼웁니다.
  /// → `docs/BACKEND_REQUESTS_FREE_TALK_ENTRY.md`
  bool get isCompleted => _freeTalkCharacters.isNotEmpty;

  Future<void> load() async {
    await guard(() async {
      _story = await _getStoryDetail(storyId);
    });
    // 이야기가 그려진 **뒤에** 이어서 묻습니다. 위의 guard 가 이미 success 로
    // 알렸기 때문에, 여기서 기다려도 화면이 늦게 뜨지는 않습니다 — 진입점만
    // 한 박자 뒤에 나타납니다.
    await _probeFreeTalk();
  }

  /// 완주 여부를 **묻지 않고 찔러 봅니다.**
  ///
  /// 서버에는 "이 아이가 이 이야기를 끝냈나"를 알려 주는 값이 없습니다 —
  /// 이야기 상세에도 없고, 홈은 완주 **개수**만 주고, 리포트 목록은
  /// `storyId` 가 없어 이야기와 이어 붙일 수 없습니다. 그래서 인물 목록을
  /// 직접 불러 보고, **인물이 돌아온 이야기 = 완주한 이야기**로 봅니다.
  /// (완주 전이면 서버가 404 로 돌려세웁니다. → `docs/API.md` §2.10-1)
  ///
  /// 이 판정을 서버 필드 하나로 바꾸는 요청은
  /// `docs/BACKEND_REQUESTS_FREE_TALK_ENTRY.md` 에 있습니다. 그게 오면 이
  /// 메서드는 통째로 지웁니다.
  ///
  /// **실패는 전부 삼킵니다.** 이야기를 시작하는 일과 아무 관계가 없어서,
  /// 여기서 실패했다고 상세 화면을 에러로 만들면 안 됩니다 — 자유 대화가
  /// 아직 안 열린 서버(501)에서도 조용히 버튼만 안 생깁니다.
  Future<void> _probeFreeTalk() async {
    final FreeTalkRepository? repository = freeTalk;
    if (repository == null || _story == null) return;
    List<FreeTalkCharacter> characters = const <FreeTalkCharacter>[];
    try {
      characters = await repository.characters(storyId);
    } on Object {
      // 무시한다 — 못 물어봤으면 진입점이 없는 것으로 둡니다.
    }
    _freeTalkCharacters = characters;
    safeNotify();
  }

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
