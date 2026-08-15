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

class ReportDetailResponseDto {
  const ReportDetailResponseDto({
    required this.sessionId,
    required this.storyTitle,
    required this.summary,
    required this.strengths,
    required this.nextFocus,
    required this.representativeUtterances,
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
      strengths: _objects(
        json['strengths'],
      ).map(ReportItemResponseDto.fromJson).toList(growable: false),
      nextFocus: _objects(
        json['nextFocus'],
      ).map(ReportItemResponseDto.fromJson).toList(growable: false),
      representativeUtterances: _objects(json['representativeUtterances'])
          .map(RepresentativeUtteranceResponseDto.fromJson)
          .toList(growable: false),
      createdAt: _date(json['createdAt']),
    );
  }

  final String sessionId;
  final String storyTitle;
  final String summary;
  final List<ReportItemResponseDto> strengths;
  final List<ReportItemResponseDto> nextFocus;
  final List<RepresentativeUtteranceResponseDto> representativeUtterances;
  final DateTime? createdAt;
}

class ReportItemResponseDto {
  const ReportItemResponseDto({required this.element, required this.comment});

  factory ReportItemResponseDto.fromJson(Map<String, dynamic> json) =>
      ReportItemResponseDto(
        element: json['element']?.toString() ?? '',
        comment: json['comment'] as String? ?? '',
      );

  final String element;
  final String comment;
}

class RepresentativeUtteranceResponseDto {
  const RepresentativeUtteranceResponseDto({
    required this.text,
    required this.element,
  });

  factory RepresentativeUtteranceResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => RepresentativeUtteranceResponseDto(
    text: json['text'] as String? ?? '',
    element: json['element']?.toString() ?? '',
  );

  final String text;
  final String element;
}

List<Map<String, dynamic>> _objects(Object? raw) =>
    (raw as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
