import 'saved_word.dart';

/// 한 이야기에서 담은 단어들.
///
/// 그룹 기준이 **이야기**인 건 의도입니다. 아이의 기억 단서는 "언제 담았나"가
/// 아니라 "어떤 이야기에서 만났나"입니다.
///
/// **묶는 일은 앱이 합니다.** 서버는 평면 목록을 최신순으로 주고, 이야기별
/// 묶음은 `WordRepositoryImpl` 이 만듭니다. → `docs/API.md` 2.12
class WordGroup {
  const WordGroup({
    required this.storyId,
    required this.storyTitle,
    required this.words,
    this.storyImage,
  });

  /// 이야기 UUID. 장면 없이 담긴 단어는 `null` 입니다.
  final String? storyId;

  final String storyTitle;
  final String? storyImage;
  final List<SavedWord> words;

  /// 필터 칩이 쓰는 값. 이야기가 없는 묶음도 고를 수 있어야 해서 `null` 을
  /// 고정 문자열로 바꿉니다 — 서버 ID 는 UUID 라 이 값과 겹치지 않습니다.
  String get filterKey => storyId ?? noStory;

  /// 어느 이야기에서 왔는지 아는가.
  ///
  /// 모르면 화면은 **묶음 헤더도 필터 칩도 그리지 않습니다.** 붙일 이름이
  /// 없는데 지어내면 아이가 그걸 이야기 제목으로 읽습니다.
  bool get hasStory => storyId != null && storyTitle.isNotEmpty;

  /// 이야기 없이 담긴 묶음의 [filterKey].
  static const String noStory = '-';
}
