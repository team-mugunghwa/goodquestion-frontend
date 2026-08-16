import 'saved_word.dart';
import 'word_group.dart';

/// 단어장 화면이 한 번에 받는 것.
class WordBook {
  const WordBook({
    required this.totalCount,
    required this.groups,
    this.childName,
    this.childAvatar,
  });

  /// 서버 `List<WordResponse>` (평면 목록)을 이야기별 그룹으로 묶습니다.
  ///
  /// 서버가 최근 담은 순으로 내려주므로 그룹 순서는 **처음 등장한 순서**를
  /// 그대로 따릅니다 - 최근 담은 이야기가 위로 옵니다. 그룹핑 기준이
  /// 이야기인 이유는 [WordGroup] 참고.
  factory WordBook.fromWords(
    List<SavedWord> words, {
    String? childName,
    String? childAvatar,
  }) {
    final Map<String, List<SavedWord>> byStory = <String, List<SavedWord>>{};
    final Map<String, SavedWord> firstOf = <String, SavedWord>{};
    for (final SavedWord word in words) {
      final String key = word.storyId ?? '';
      firstOf.putIfAbsent(key, () => word);
      byStory.putIfAbsent(key, () => <SavedWord>[]).add(word);
    }
    return WordBook(
      totalCount: words.length,
      childName: childName,
      childAvatar: childAvatar,
      groups: <WordGroup>[
        for (final MapEntry<String, List<SavedWord>> entry in byStory.entries)
          WordGroup(
            storyId: entry.key,
            storyTitle: firstOf[entry.key]!.storyTitle ?? '',
            storyImage: firstOf[entry.key]!.storyImage,
            words: List<SavedWord>.unmodifiable(entry.value),
          ),
      ],
    );
  }

  /// 헤더 배지에 크게 뜨는 숫자. 담은 단어 전체 개수입니다.
  final int totalCount;

  /// 최근 담은 이야기가 위. 서버 순서를 그대로 씁니다.
  final List<WordGroup> groups;

  final String? childName;
  final String? childAvatar;

  /// 아직 아무것도 담지 않았는가. 필터 결과 0건과는 다른 상태입니다.
  bool get isEmpty => groups.isEmpty;
}
