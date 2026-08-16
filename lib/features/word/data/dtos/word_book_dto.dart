import '../../domain/entities/saved_word.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';

/// 서버 응답(지금은 더미 JSON)의 모양 그대로.
///
/// `json_serializable` 대신 손으로 씁니다. 대신 **모든 캐스팅을 방어적으로** —
/// 더미는 컴파일러가 검사하지 않습니다. → `docs/SCREEN_RECIPE.md`
class WordBookDto {
  const WordBookDto({
    required this.totalCount,
    required this.groups,
    this.childName,
    this.childAvatar,
  });

  factory WordBookDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> child =
        json['child'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return WordBookDto(
      totalCount: json['totalCount'] as int? ?? 0,
      childName: child['name'] as String?,
      childAvatar: child['avatar'] as String?,
      groups: (json['groups'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(WordGroupDto.fromJson)
          .toList(growable: false),
    );
  }

  final int totalCount;
  final String? childName;
  final String? childAvatar;
  final List<WordGroupDto> groups;

  WordBook toEntity() => WordBook(
    totalCount: totalCount,
    childName: childName,
    childAvatar: childAvatar,
    groups: groups
        .map((WordGroupDto dto) => dto.toEntity())
        .toList(growable: false),
  );
}

class WordGroupDto {
  const WordGroupDto({
    required this.storyId,
    required this.storyTitle,
    required this.words,
    this.storyImage,
  });

  // 더미 JSON 은 ID 가 숫자입니다. 서버는 UUID 문자열이라, 읽는 자리에서
  // 문자열로 맞춥니다 — 더미를 고치는 것보다 여기가 한 곳입니다.
  factory WordGroupDto.fromJson(Map<String, dynamic> json) => WordGroupDto(
    storyId: json['storyId']?.toString(),
    storyTitle: json['storyTitle'] as String? ?? '',
    storyImage: json['storyImage'] as String?,
    words: (json['words'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SavedWordDto.fromJson)
        .toList(growable: false),
  );

  final String? storyId;
  final String storyTitle;
  final String? storyImage;
  final List<SavedWordDto> words;

  WordGroup toEntity() => WordGroup(
    storyId: storyId,
    storyTitle: storyTitle,
    storyImage: storyImage,
    words: words
        .map((SavedWordDto dto) => dto.toEntity())
        .toList(growable: false),
  );
}

class SavedWordDto {
  const SavedWordDto({
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

  factory SavedWordDto.fromJson(Map<String, dynamic> json) => SavedWordDto(
    wordId: json['wordId']?.toString() ?? '',
    word: json['word'] as String? ?? '',
    meaning: json['meaning'] as String? ?? '',
    sentence: json['sentence'] as String? ?? '',
    // 서버 응답 필드명과 같은 키를 쓴다(exampleSentenceDaily/Advanced) -
    // 실서버 연동 시 매핑이 그대로 이어지게. 예문 3종(V14) 이전 데이터는 null.
    sentenceDaily: json['exampleSentenceDaily'] as String?,
    sentenceAdvanced: json['exampleSentenceAdvanced'] as String?,
    audio: json['audio'] as String?,
    liked: json['liked'] as bool? ?? false,
    savedAt: json['savedAt'] as String?,
  );

  final String wordId;
  final String word;
  final String meaning;
  final String sentence;
  final String? sentenceDaily;
  final String? sentenceAdvanced;
  final String? audio;
  final bool liked;

  /// ISO 8601 문자열. (`docs/API.md` 2장)
  final String? savedAt;

  SavedWord toEntity() => SavedWord(
    wordId: wordId,
    word: word,
    meaning: meaning,
    sentence: sentence,
    sentenceDaily: sentenceDaily,
    sentenceAdvanced: sentenceAdvanced,
    audio: audio,
    liked: liked,
    // 타임존 없는 문자열이 와도 화면이 죽지 않게 방어합니다.
    savedAt: savedAt == null ? null : DateTime.tryParse(savedAt!)?.toLocal(),
  );
}
