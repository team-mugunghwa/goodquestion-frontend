import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/usecases/get_word_book_use_case.dart';
import '../../domain/usecases/toggle_word_like_use_case.dart';

/// 단어장의 상태. 데이터 하나 + 선택된 이야기 하나.
class WordListViewModel extends BaseViewModel {
  WordListViewModel(this._getWordBook, this._toggleLike);

  /// 이야기 필터의 "전체". 실제 storyId(UUID·빈 문자열)와 겹치지 않는 값.
  static const String allStoryId = 'all';

  final GetWordBookUseCase _getWordBook;
  final ToggleWordLikeUseCase _toggleLike;

  WordBook? _book;
  String _selectedStoryId = allStoryId;

  WordBook? get book => _book;
  String get selectedStoryId => _selectedStoryId;

  int get totalCount => _book?.totalCount ?? 0;
  String? get childName => _book?.childName;
  String? get childAvatar => _book?.childAvatar;

  List<WordGroup> get allGroups => _book?.groups ?? const <WordGroup>[];

  /// 화면에 그릴 그룹들. 이야기 필터가 이미 적용돼 있습니다.
  List<WordGroup> get visibleGroups => _selectedStoryId == allStoryId
      ? allGroups
      : allGroups
            .where((WordGroup g) => g.storyId == _selectedStoryId)
            .toList(growable: false);

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
