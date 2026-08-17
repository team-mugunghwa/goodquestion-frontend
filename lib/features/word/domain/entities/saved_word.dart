import 'sentence_practice.dart';

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
    this.sentenceDaily,
    this.sentenceAdvanced,
    this.audio,
    this.savedAt,
  });

  /// 서버가 주는 UUID 문자열입니다.
  final String wordId;

  /// 표제어. 목록 카드에서 가장 큰 글씨입니다.
  final String word;

  /// 쉬운 뜻. 모달에서만 보여 줍니다.
  ///
  /// **비어 있을 수 있습니다.** 서버가 LLM 으로 만들어 주지만 실패하거나
  /// 아직 안 만든 단어가 있습니다 — 화면은 빈 칸 대신 안내 문구를 그립니다.
  final String meaning;

  /// 이야기 속에서 이 단어가 나온 문장. 모달에서만 보여 줍니다.
  final String sentence;

  /// 일상 예문 - 이야기 밖 쓰임 (서버 exampleSentenceDaily). 예문 3종
  /// 체계(V14) 이전에 담긴 단어는 null이라 모달이 칸을 그리지 않습니다.
  final String? sentenceDaily;

  /// 심화 예문 - 일상 예문보다 한 단계 어려운 문장 (exampleSentenceAdvanced).
  final String? sentenceAdvanced;

  final String? audio;

  /// 좋아요 여부. **토글은 상세 모달의 책임**이고 목록은 표시만 합니다.
  final bool liked;

  final DateTime? savedAt;

  /// 뜻이 아직 없는 단어인가. 서버가 만들어 주기 전이거나 생성에 실패한 경우.
  bool get hasMeaning => meaning.trim().isNotEmpty;

  /// 종류별 예문. 이야기 예문은 [sentence] 이고, 없으면 빈 문자열이라
  /// 호출부는 `trim().isNotEmpty` 로 거릅니다.
  String? sentenceOf(SentenceType type) => switch (type) {
    SentenceType.story => sentence,
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
    sentence: sentence,
    sentenceDaily: sentenceDaily,
    sentenceAdvanced: sentenceAdvanced,
    liked: liked ?? this.liked,
    audio: audio,
    savedAt: savedAt,
  );
}
