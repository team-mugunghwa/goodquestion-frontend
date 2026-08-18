import '../../../../core/error/exceptions.dart';
import '../../domain/entities/free_talk.dart';

/// 자유 대화 응답 파서.
///
/// **없어도 되는 값에는 예외를 던지지 않습니다.** 썸네일·감정·마지막 대화
/// 시각이 비어 와도 화면은 그대로 굴러가야 합니다. 반대로 식별자와 대사
/// 본문이 없으면 그 응답으로는 아무것도 할 수 없으므로 [ParseException] 을
/// 던져 화면이 에러로 갈라지게 둡니다.
class FreeTalkDto {
  const FreeTalkDto._();

  static List<FreeTalkCharacter> characters(Object? data) {
    if (data is! List) {
      throw const ParseException('인물 목록 응답 형식이 올바르지 않습니다.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(character)
        .toList(growable: false);
  }

  static FreeTalkCharacter character(Map<String, dynamic> json) {
    final String id = json['characterId']?.toString() ?? '';
    final String name = (json['name'] as String? ?? '').trim();
    if (id.isEmpty || name.isEmpty) {
      throw const ParseException('인물 정보 응답 형식이 올바르지 않습니다.');
    }
    return FreeTalkCharacter(
      characterId: id,
      name: name,
      characterKey: json['characterKey'] as String? ?? '',
      thumbnailUrl: _trimmedOrNull(json['thumbnailUrl']),
      lastTalkedAt: _dateTime(json['lastTalkedAt']),
    );
  }

  static FreeTalkSession session(Object? data, {FreeTalkCharacter? requested}) {
    if (data is! Map<String, dynamic>) {
      throw const ParseException('자유 대화 시작 응답 형식이 올바르지 않습니다.');
    }
    final String id = data['freeTalkId']?.toString() ?? '';
    if (id.isEmpty) {
      throw const ParseException('자유 대화 식별자가 없습니다.');
    }
    final Object? characterValue = data['character'];
    // 시작 응답의 인물 정보가 비어 와도 화면은 우리가 고른 인물을 이미
    // 알고 있습니다. 이름을 잃고 "이야기 친구"로 되돌아가는 것보다 낫습니다.
    final FreeTalkCharacter resolved = characterValue is Map<String, dynamic>
        ? character(characterValue)
        : (requested ?? (throw const ParseException('자유 대화 인물 정보가 없습니다.')));
    return FreeTalkSession(
      freeTalkId: id,
      character: resolved,
      opening: speech(data['opening'], what: '첫 대사'),
      maxTurns: (data['maxTurns'] as num?)?.toInt() ?? 0,
    );
  }

  static FreeTalkTurn turn(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ParseException('대화 응답 형식이 올바르지 않습니다.');
    }
    return FreeTalkTurn(
      characterMessage: speech(data['characterMessage'], what: '대사'),
      turnCount: (data['turnCount'] as num?)?.toInt() ?? 0,
      ended: data['ended'] as bool? ?? false,
    );
  }

  /// `POST .../end` 응답. 본문이 `{ closing: {...} }` 입니다.
  static FreeTalkSpeech closing(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ParseException('마무리 인사 응답 형식이 올바르지 않습니다.');
    }
    return speech(data['closing'], what: '마무리 인사');
  }

  static FreeTalkSpeech speech(Object? value, {required String what}) {
    if (value is Map<String, dynamic>) {
      final String text = (value['text'] as String? ?? '').trim();
      if (text.isNotEmpty) {
        return FreeTalkSpeech(
          text: text,
          audioUrl: _trimmedOrNull(value['audioUrl']),
          emotion: _trimmedOrNull(value['emotion']),
        );
      }
    }
    throw ParseException('$what 응답 형식이 올바르지 않습니다.');
  }

  static String? _trimmedOrNull(Object? value) {
    final String? text = value as String?;
    if (text == null) return null;
    final String trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 파싱에 실패해도 예외를 올리지 않습니다. 마지막 대화 시각은 카드에
  /// 한 줄 덧붙이는 값이라, 이것 때문에 인물 목록 전체가 막히면 안 됩니다.
  static DateTime? _dateTime(Object? value) {
    final String? raw = _trimmedOrNull(value);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }
}
