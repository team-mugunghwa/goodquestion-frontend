import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/repositories/word_repository.dart';
import '../datasources/word_local_data_source.dart';

/// 서버가 준비되기 전까지 단어장을 번들 더미에서 읽는 구현.
///
/// 좋아요는 **메모리에만** 남습니다. 앱을 다시 켜면 더미 값으로 돌아가는데,
/// 그게 목업의 정직한 동작입니다. 로컬 저장소에 흉내를 내 두면 나중에
/// 서버 값과 어긋나는 걸 디버깅하게 됩니다.
class WordRepositoryMock implements WordRepository {
  WordRepositoryMock(
    this._localDataSource, {
    this.latency = const Duration(milliseconds: 400),
  });

  final WordLocalDataSource _localDataSource;
  final Duration latency;

  /// wordId → 좋아요. 더미 값 위에 덮어씁니다.
  final Map<int, bool> _likeOverrides = <int, bool>{};

  @override
  Future<WordBook> getWordBook() async {
    await Future<void>.delayed(latency);
    try {
      final WordBook book = (await _localDataSource.fetchWordBook()).toEntity();
      if (_likeOverrides.isEmpty) return book;
      return _applyOverrides(book);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }

  @override
  Future<bool> toggleLike(int wordId) async {
    final WordBook book = await getWordBook();
    final bool current = book.groups
        .expand((WordGroup g) => g.words)
        .firstWhere(
          (SavedWord w) => w.wordId == wordId,
          orElse: () => const SavedWord(
            wordId: -1,
            word: '',
            meaning: '',
            sentence: '',
            liked: false,
          ),
        )
        .liked;
    final bool next = !current;
    _likeOverrides[wordId] = next;
    return next;
  }

  WordBook _applyOverrides(WordBook book) => WordBook(
    totalCount: book.totalCount,
    childName: book.childName,
    childAvatar: book.childAvatar,
    groups: book.groups
        .map(
          (WordGroup group) => WordGroup(
            storyId: group.storyId,
            storyTitle: group.storyTitle,
            storyImage: group.storyImage,
            words: group.words
                .map(
                  (SavedWord word) => _likeOverrides.containsKey(word.wordId)
                      ? word.copyWith(liked: _likeOverrides[word.wordId])
                      : word,
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
  );
}
