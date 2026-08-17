import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/usecases/get_word_book_use_case.dart';
import '../../domain/usecases/toggle_word_like_use_case.dart';

/// 단어장의 상태. 데이터 하나 + 선택된 이야기 하나.
class WordListViewModel extends BaseViewModel {
  WordListViewModel(this._getWordBook, this._toggleLike);

  /// 이야기 필터의 "전체". 서버 ID 는 UUID 라 이 값과 겹치지 않습니다.
  static const String allStoryId = '*';

  final GetWordBookUseCase _getWordBook;
  final ToggleWordLikeUseCase _toggleLike;

  WordBook? _book;
  String _selectedStoryId = allStoryId;
  bool _likedOnly = false;

  WordBook? get book => _book;
  String get selectedStoryId => _selectedStoryId;

  /// 좋아요한 단어만 볼지. 하트를 누르는 이유가 여기 있습니다 —
  /// 켜고 끌 곳이 없으면 하트는 그냥 눌리는 그림입니다.
  bool get likedOnly => _likedOnly;

  /// 좋아요한 단어 수. 0 이면 필터 버튼을 숨깁니다 —
  /// 눌러도 빈 화면만 나오는 버튼은 고장으로 보입니다.
  int get likedCount => allGroups
      .expand((WordGroup g) => g.words)
      .where((SavedWord w) => w.liked)
      .length;

  int get totalCount => _book?.totalCount ?? 0;
  String? get childName => _book?.childName;
  String? get childAvatar => _book?.childAvatar;

  List<WordGroup> get allGroups => _book?.groups ?? const <WordGroup>[];

  /// 화면에 그릴 그룹들. 이야기 필터와 좋아요 필터가 이미 적용돼 있습니다.
  ///
  /// 좋아요 필터는 그룹이 아니라 **단어**를 거릅니다. 걸러 낸 뒤 빈 그룹은
  /// 통째로 빼서, 제목만 남은 이야기 머리글이 떠 있지 않게 합니다.
  List<WordGroup> get visibleGroups {
    final Iterable<WordGroup> byStory = _selectedStoryId == allStoryId
        ? allGroups
        : allGroups.where((WordGroup g) => g.filterKey == _selectedStoryId);
    if (!_likedOnly) return byStory.toList(growable: false);
    return byStory
        .map(
          (WordGroup g) => WordGroup(
            storyId: g.storyId,
            storyTitle: g.storyTitle,
            storyImage: g.storyImage,
            words: g.words
                .where((SavedWord w) => w.liked)
                .toList(growable: false),
          ),
        )
        .where((WordGroup g) => g.words.isNotEmpty)
        .toList(growable: false);
  }

  /// 아직 아무것도 담지 않음. 필터 결과 0건과 **다른 상태**입니다 —
  /// 이때는 필터 칩 자체를 숨기고 이야기로 보냅니다.
  bool get isEmpty => state.isSuccess && (_book?.isEmpty ?? true);

  /// 담은 건 있는데 고른 이야기에 없는 경우.
  bool get isEmptyByFilter =>
      state.isSuccess && !isEmpty && visibleGroups.isEmpty;

  Future<void> load() => guard(() async {
    _book = await _getWordBook();
  });

  void selectStory(String storyId) {
    if (_selectedStoryId == storyId) return;
    _selectedStoryId = storyId;
    safeNotify();
  }

  void toggleLikedOnly() {
    _likedOnly = !_likedOnly;
    safeNotify();
  }

  /// 상세 모달에서 좋아요를 바꿨을 때. 목록 카드에 즉시 반영합니다.
  ///
  /// 다시 불러오지 않고 **손에 있는 값만 갈아 끼웁니다** — 모달을 닫을 때마다
  /// 스켈레톤이 번쩍이면 아이가 자기가 뭘 망가뜨린 줄 압니다.
  Future<void> toggleLike(String wordId) async {
    final bool liked = await _toggleLike(wordId);
    final WordBook? current = _book;
    if (current == null) return;
    _book = WordBook(
      totalCount: current.totalCount,
      childName: current.childName,
      childAvatar: current.childAvatar,
      groups: current.groups
          .map(
            (WordGroup group) => WordGroup(
              storyId: group.storyId,
              storyTitle: group.storyTitle,
              storyImage: group.storyImage,
              words: group.words
                  .map(
                    (SavedWord word) => word.wordId == wordId
                        ? word.copyWith(liked: liked)
                        : word,
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
    safeNotify();
  }

  /// 모달이 최신 좋아요 상태를 읽을 수 있게 합니다.
  SavedWord? wordOf(String wordId) {
    for (final WordGroup group in allGroups) {
      for (final SavedWord word in group.words) {
        if (word.wordId == wordId) return word;
      }
    }
    return null;
  }
}
