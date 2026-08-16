import 'sentence_practice.dart';

/// 아이가 이야기 도중 담아 둔 단어 하나.
///
/// [meaning] 과 예문은 **목록에 노출하지 않습니다.** 상세 모달의
/// 몫입니다. 목록에서 뜻까지 보여 주면 텍스트 밀도가 올라가 저학년이
/// 이탈합니다 — 단어장은 "읽는 화면"이 아니라 "다시 만나는 화면"입니다.
class SavedWord {
  const SavedWord({
    required this.wordId,
    required this.word,
    required this.liked,
    this.meaning,
    this.sentenceStory,
    this.sentenceDaily,
    this.sentenceAdvanced,
    this.storyId,
    this.storyTitle,
    this.storyImage,
    this.audio,
    this.savedAt,
  });

  /// 서버 `WordResponse.id`. UUID 문자열입니다.
  final String wordId;

  /// 표제어. 목록 카드에서 가장 큰 글씨입니다.
  final String word;

  /// 쉬운 뜻. 모달에서만 보여 줍니다. 서버가 아직 못 만들었으면 `null`.
  final String? meaning;

  /// 이야기 속에서 이 단어가 나온 문장. (`exampleSentence`)
  final String? sentenceStory;

  /// 일상 대화 예문. 예문 확장 전에 담은 단어는 `null` 일 수 있습니다.
  final String? sentenceDaily;

  /// 심화 예문. 예문 확장 전에 담은 단어는 `null` 일 수 있습니다.
  final String? sentenceAdvanced;

  /// 이 단어를 만난 이야기. 목록이 이야기별로 묶는 기준입니다.
  final String? storyId;
  final String? storyTitle;
  final String? storyImage;

  /// 발음 음성. 서버가 아직 내려주지 않아 지금은 늘 `null` 입니다.
  final String? audio;

  /// 좋아요 여부. **토글은 상세 모달의 책임**이고 목록은 표시만 합니다.
  final bool liked;

  final DateTime? savedAt;

  /// 종류별 예문. 없으면 `null`.
  String? sentenceOf(SentenceType type) => switch (type) {
    SentenceType.story => sentenceStory,
    SentenceType.daily => sentenceDaily,
    SentenceType.advanced => sentenceAdvanced,
  };

  /// 따라 말할 수 있는 예문이 하나라도 있는가. 상세 모달이 이 값으로
  /// "따라 말하기" 버튼을 보여 줄지 정합니다.
  bool get hasPracticeSentence => SentenceType.values.any(
    (SentenceType type) => (sentenceOf(type) ?? '').trim().isNotEmpty,
  );

  SavedWord copyWith({bool? liked}) => SavedWord(
    wordId: wordId,
    word: word,
    meaning: meaning,
    sentenceStory: sentenceStory,
    sentenceDaily: sentenceDaily,
    sentenceAdvanced: sentenceAdvanced,
    storyId: storyId,
    storyTitle: storyTitle,
    storyImage: storyImage,
    liked: liked ?? this.liked,
    audio: audio,
    savedAt: savedAt,
  );
}
