import '../../../../core/error/exceptions.dart';

class ReportListResponseDto {
  const ReportListResponseDto({
    required this.sessionId,
    required this.storyTitle,
    required this.createdAt,
  });

  factory ReportListResponseDto.fromJson(Map<String, dynamic> json) {
    final String sessionId = json['sessionId']?.toString() ?? '';
    final String storyTitle = json['storyTitle'] as String? ?? '';
    if (sessionId.isEmpty || storyTitle.isEmpty) {
      throw const ParseException('리포트 목록 응답 형식이 올바르지 않습니다.');
    }
    return ReportListResponseDto(
      sessionId: sessionId,
      storyTitle: storyTitle,
      createdAt: _date(json['createdAt']),
    );
  }

  final String sessionId;
  final String storyTitle;
  final DateTime? createdAt;
}

/// 세션 1건의 리포트 상세 응답.
///
/// 서버가 이미 강점/보완점을 요소 코드가 아니라 보호자가 읽을 문장으로 다듬어
/// [competencies]·[vocabulary]·[homeGuide]에 담아서 내려준다. 프론트는 그걸
/// 그대로 옮기기만 하면 되고, 내부 요소 코드(REASON 등)를 조합해서 문장을
/// 새로 짓지 않는다 — PRD F-09(내부 태그 미노출)가 서버 쪽에서 이미 지켜진다.
class ReportDetailResponseDto {
  const ReportDetailResponseDto({
    required this.sessionId,
    required this.storyTitle,
    required this.summary,
    required this.vocabulary,
    required this.competencies,
    required this.representativeUtterance,
    required this.homeGuide,
    required this.createdAt,
  });

  factory ReportDetailResponseDto.fromJson(Map<String, dynamic> json) {
    final String sessionId = json['sessionId']?.toString() ?? '';
    final String storyTitle = json['storyTitle'] as String? ?? '';
    final String summary = json['summary'] as String? ?? '';
    if (sessionId.isEmpty || storyTitle.isEmpty || summary.isEmpty) {
      throw const ParseException('리포트 상세 응답 형식이 올바르지 않습니다.');
    }
    return ReportDetailResponseDto(
      sessionId: sessionId,
      storyTitle: storyTitle,
      summary: summary,
      vocabulary: VocabularyResponseDto.fromJson(
        json['vocabulary'] as Map<String, dynamic>?,
      ),
      competencies: _objects(
        json['competencies'],
      ).map(CompetencyResponseDto.fromJson).toList(growable: false),
      representativeUtterance: RepresentativeUtteranceResponseDto.fromJson(
        json['representativeUtterance'] as Map<String, dynamic>?,
      ),
      homeGuide: HomeGuideResponseDto.fromJson(
        json['homeGuide'] as Map<String, dynamic>?,
      ),
      createdAt: _date(json['createdAt']),
    );
  }

  final String sessionId;
  final String storyTitle;
  final String summary;
  final VocabularyResponseDto vocabulary;
  final List<CompetencyResponseDto> competencies;
  final RepresentativeUtteranceResponseDto representativeUtterance;
  final HomeGuideResponseDto homeGuide;
  final DateTime? createdAt;
}

/// 역량 카드 하나(관점과 공감 · 감정 표현 · 상호작용 · 생각과 이유 · 결과와 해결).
/// name은 이미 보호자가 읽을 한글 역량명이다.
class CompetencyResponseDto {
  const CompetencyResponseDto({
    required this.name,
    required this.finding,
    required this.evidenceUtterance,
    required this.strength,
    required this.nextFocus,
  });

  factory CompetencyResponseDto.fromJson(Map<String, dynamic> json) =>
      CompetencyResponseDto(
        name: json['name'] as String? ?? '',
        finding: json['finding'] as String? ?? '',
        evidenceUtterance: json['evidenceUtterance'] as String? ?? '',
        strength: json['strength'] as String? ?? '',
        nextFocus: json['nextFocus'] as String? ?? '',
      );

  final String name;
  final String finding;
  final String evidenceUtterance;
  final String strength;
  final String nextFocus;
}

/// 어휘 분석. 강점/보완이 나뉘어 있지 않고 [feedback] 한 덩어리로 온다 —
/// 특징이 뚜렷하지 않을 때는 다양한 어휘를 권하는 문구가 이 자리에 들어간다.
class VocabularyResponseDto {
  const VocabularyResponseDto({
    required this.mainWords,
    required this.askedWords,
    required this.repeatedExpressions,
    required this.feedback,
  });

  factory VocabularyResponseDto.fromJson(Map<String, dynamic>? json) =>
      VocabularyResponseDto(
        mainWords: _strings(json?['mainWords']),
        askedWords: _strings(json?['askedWords']),
        repeatedExpressions: _strings(json?['repeatedExpressions']),
        feedback: json?['feedback'] as String? ?? '',
      );

  final List<String> mainWords;
  final List<String> askedWords;
  final List<String> repeatedExpressions;
  final String feedback;
}

/// 이번 세션에서 고른 대표 발화 1건 (세션당 1개, 목록이 아니다).
class RepresentativeUtteranceResponseDto {
  const RepresentativeUtteranceResponseDto({
    required this.text,
    required this.reason,
  });

  factory RepresentativeUtteranceResponseDto.fromJson(
    Map<String, dynamic>? json,
  ) => RepresentativeUtteranceResponseDto(
    text: json?['text'] as String? ?? '',
    reason: json?['reason'] as String? ?? '',
  );

  final String text;
  final String reason;
}

/// 가정 연계 대화 가이드. 이야기 질문 2~3개 + 일상 연결 질문 2~3개.
class HomeGuideResponseDto {
  const HomeGuideResponseDto({
    required this.storyQuestions,
    required this.dailyLifeQuestions,
  });

  factory HomeGuideResponseDto.fromJson(Map<String, dynamic>? json) =>
      HomeGuideResponseDto(
        storyQuestions: _strings(json?['storyQuestions']),
        dailyLifeQuestions: _strings(json?['dailyLifeQuestions']),
      );

  final List<String> storyQuestions;
  final List<String> dailyLifeQuestions;
}

/// 6각 그래프 축 하나. `GET /sessions/{id}/report/axis-scores` 응답 —
/// [ReportDetailResponseDto]와 별도 API다 (D6 0-1절: 그래프는 서버
/// 결정론적 집계 전용, LLM 미사용이라 응답 자체가 분리돼 있다).
class AxisScoreResponseDto {
  const AxisScoreResponseDto({
    required this.label,
    required this.description,
    required this.active,
    this.score,
    this.previousScore,
    this.evidence,
  });

  factory AxisScoreResponseDto.fromJson(Map<String, dynamic> json) =>
      AxisScoreResponseDto(
        label: json['label'] as String? ?? '',
        description: json['description'] as String? ?? '',
        active: json['active'] as bool? ?? false,
        score: json['score'] as int?,
        previousScore: json['previousScore'] as int?,
        evidence: json['evidence'] as String?,
      );

  final String label;
  final String description;
  final bool active;
  final int? score;
  final int? previousScore;
  final String? evidence;
}

List<Map<String, dynamic>> _objects(Object? raw) =>
    (raw as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

List<String> _strings(Object? raw) => (raw as List<dynamic>? ?? <dynamic>[])
    .whereType<String>()
    .toList(growable: false);

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
