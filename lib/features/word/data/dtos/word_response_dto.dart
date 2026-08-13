import '../../domain/entities/saved_word.dart';

/// `WordResponse` — 실제 서버 응답. → `docs/API.md` 3.15
///
/// 서버는 `entryType`(`UNKNOWN`/`FAVORITE`) 만 알고 "좋아요" 라는 개념이
/// 없습니다. `liked` 는 `entryType == FAVORITE` 로 여기서 만듭니다.
///
/// **`storyId`·`storyTitle` 이 없습니다.** `sourceSceneId`(장면) 만 내려오고
/// 그 장면이 어느 이야기인지는 이 응답만으로 알 수 없습니다 — 그룹핑은
/// `WordRepositoryImpl` 이 대신 담당합니다. → `docs/BACKEND_REQUESTS.md`
class WordResponseDto {
  const WordResponseDto({
    required this.id,
    required this.word,
    required this.meaning,
    required this.exampleSentence,
    required this.liked,
    this.createdAt,
  });

  factory WordResponseDto.fromJson(Map<String, dynamic> json) =>
      WordResponseDto(
        id: json['id'] as String? ?? '',
        word: json['word'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        exampleSentence: json['exampleSentence'] as String? ?? '',
        liked: json['entryType'] == 'FAVORITE',
        createdAt: json['createdAt'] as String?,
      );

  final String id;
  final String word;
  final String meaning;
  final String exampleSentence;
  final bool liked;

  /// ISO 8601 문자열.
  final String? createdAt;

  SavedWord toEntity() => SavedWord(
    wordId: id,
    word: word,
    meaning: meaning,
    sentence: exampleSentence,
    liked: liked,
    savedAt: createdAt == null ? null : DateTime.tryParse(createdAt!)?.toLocal(),
  );
}
