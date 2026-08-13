/// 아이가 이야기 도중 담아 둔 단어 하나.
///
/// [meaning] 과 [sentence] 는 **목록에 노출하지 않습니다.** 상세 모달의
/// 몫입니다. 목록에서 뜻까지 보여 주면 텍스트 밀도가 올라가 저학년이
/// 이탈합니다 — 단어장은 "읽는 화면"이 아니라 "다시 만나는 화면"입니다.
class SavedWord {
  const SavedWord({
    required this.wordId,
    required this.word,
    required this.meaning,
    required this.sentence,
    required this.liked,
    this.audio,
    this.savedAt,
  });

  final String wordId;

  /// 표제어. 목록 카드에서 가장 큰 글씨입니다.
  final String word;

  /// 쉬운 뜻. 모달에서만 보여 줍니다.
  final String meaning;

  /// 이야기 속에서 이 단어가 나온 문장. 모달에서만 보여 줍니다.
  final String sentence;

  final String? audio;

  /// 좋아요 여부. **토글은 상세 모달의 책임**이고 목록은 표시만 합니다.
  final bool liked;

  final DateTime? savedAt;

  SavedWord copyWith({bool? liked}) => SavedWord(
    wordId: wordId,
    word: word,
    meaning: meaning,
    sentence: sentence,
    liked: liked ?? this.liked,
    audio: audio,
    savedAt: savedAt,
  );
}
