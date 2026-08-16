import 'saved_word.dart';

/// 한 이야기에서 담은 단어들.
///
/// 그룹 기준이 **이야기**인 건 의도입니다. 저장 시각순 평면 리스트로 만들지
/// 마세요 — 아이의 기억 단서는 "언제 담았나"가 아니라 "어떤 이야기에서
/// 만났나"입니다. (PRD F-10)
class WordGroup {
  const WordGroup({
    required this.storyId,
    required this.storyTitle,
    required this.words,
    this.storyImage,
  });

  /// 이야기 UUID. 이야기 없이 담긴 단어는 빈 문자열로 묶입니다.
  final String storyId;

  /// 이야기 제목. 이야기 없이 담긴 단어면 빈 문자열입니다 - 화면이
  /// 대체 문구(`WordStrings.noStory`)로 바꿔 보여 줍니다.
  final String storyTitle;
  final String? storyImage;
  final List<SavedWord> words;
}
