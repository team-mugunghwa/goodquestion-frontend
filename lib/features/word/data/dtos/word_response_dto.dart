import '../../../../core/error/exceptions.dart';

/// 서버가 주는 단어 하나. `GET·POST·PATCH /children/{childId}/words` 공용.
/// → `docs/API.md` 2.12
///
/// **평면입니다.** 이야기별 묶음은 서버가 만들지 않고 앱이 만듭니다
/// (`WordRepositoryImpl`). 서버는 최신순으로만 줍니다.
class WordResponseDto {
  const WordResponseDto({
    required this.id,
    required this.word,
    required this.entryType,
    this.meaning,
    this.exampleSentence,
    this.exampleSentenceDaily,
    this.exampleSentenceAdvanced,
    this.sourceSceneId,
    this.storyId,
    this.storyTitle,
    this.storyImageUrl,
    this.createdAt,
  });

  factory WordResponseDto.fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    if (id == null) {
      throw const ParseException('단어 응답에 id 가 없습니다.');
    }
    return WordResponseDto(
      id: '$id',
      word: json['word'] as String? ?? '',
      entryType: json['entryType'] as String? ?? unknownEntry,
      meaning: json['meaning'] as String?,
      exampleSentence: json['exampleSentence'] as String?,
      exampleSentenceDaily: json['exampleSentenceDaily'] as String?,
      exampleSentenceAdvanced: json['exampleSentenceAdvanced'] as String?,
      sourceSceneId: json['sourceSceneId']?.toString(),
      storyId: json['storyId']?.toString(),
      storyTitle: json['storyTitle'] as String?,
      storyImageUrl: json['storyImageUrl'] as String?,
      // 타임존 없는 문자열이 와도 화면이 죽지 않게 방어합니다.
      createdAt: DateTime.tryParse(
        json['createdAt'] as String? ?? '',
      )?.toLocal(),
    );
  }

  /// 모르는 말. 담을 때의 기본값입니다.
  static const String unknownEntry = 'UNKNOWN';

  /// 좋아하는 말. 화면의 하트가 켜진 상태입니다.
  static const String favoriteEntry = 'FAVORITE';

  final String id;
  final String word;

  /// `UNKNOWN` 또는 `FAVORITE`.
  final String entryType;

  /// 서버가 LLM 으로 만들어 주지만 **비어 있을 수 있습니다.**
  final String? meaning;

  final String? exampleSentence;

  /// 예문 3종 - 일상/심화 (서버 V14). 그 전에 담긴 단어는 null이라
  /// 상세 모달이 해당 칸을 그리지 않습니다.
  final String? exampleSentenceDaily;
  final String? exampleSentenceAdvanced;
  final String? sourceSceneId;

  /// 이야기 3필드는 백엔드 PR 반영 전까지 오지 않습니다. 없으면 앱이
  /// 한 묶음으로 그립니다 — 화면이 비지 않는 쪽을 택했습니다.
  final String? storyId;
  final String? storyTitle;
  final String? storyImageUrl;

  final DateTime? createdAt;

  /// 화면의 하트.
  bool get liked => entryType == favoriteEntry;
}
