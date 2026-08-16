import '../../domain/entities/saved_word.dart';

/// 서버 `WordResponse` 의 모양 그대로. (`docs/API.md` 3.11)
///
/// `json_serializable` 대신 손으로 씁니다. 대신 **모든 캐스팅을 방어적으로** -
/// 더미는 컴파일러가 검사하지 않습니다. -> `docs/SCREEN_RECIPE.md`
class WordResponseDto {
  const WordResponseDto({
    required this.id,
    required this.word,
    required this.entryType,
    this.meaning,
    this.exampleSentence,
    this.exampleSentenceDaily,
    this.exampleSentenceAdvanced,
    this.storyId,
    this.storyTitle,
    this.storyImageUrl,
    this.createdAt,
  });

  factory WordResponseDto.fromJson(Map<String, dynamic> json) =>
      WordResponseDto(
        id: json['id'] as String? ?? '',
        word: json['word'] as String? ?? '',
        meaning: json['meaning'] as String?,
        exampleSentence: json['exampleSentence'] as String?,
        exampleSentenceDaily: json['exampleSentenceDaily'] as String?,
        exampleSentenceAdvanced: json['exampleSentenceAdvanced'] as String?,
        entryType: json['entryType'] as String? ?? 'UNKNOWN',
        storyId: json['storyId'] as String?,
        storyTitle: json['storyTitle'] as String?,
        storyImageUrl: json['storyImageUrl'] as String?,
        createdAt: json['createdAt'] as String?,
      );

  final String id;
  final String word;
  final String? meaning;
  final String? exampleSentence;
  final String? exampleSentenceDaily;
  final String? exampleSentenceAdvanced;

  /// `UNKNOWN` / `FAVORITE`. 좋아요 여부가 이 값 하나에 실려 옵니다.
  final String entryType;
  final String? storyId;
  final String? storyTitle;
  final String? storyImageUrl;

  /// ISO 8601 문자열.
  final String? createdAt;

  SavedWord toEntity() => SavedWord(
    wordId: id,
    word: word,
    meaning: meaning,
    sentenceStory: exampleSentence,
    sentenceDaily: exampleSentenceDaily,
    sentenceAdvanced: exampleSentenceAdvanced,
    storyId: storyId,
    storyTitle: storyTitle,
    storyImage: storyImageUrl,
    liked: entryType == 'FAVORITE',
    // 타임존 없는 문자열이 와도 화면이 죽지 않게 방어합니다.
    savedAt: createdAt == null
        ? null
        : DateTime.tryParse(createdAt!)?.toLocal(),
  );
}
