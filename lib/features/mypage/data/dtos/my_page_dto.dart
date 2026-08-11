/// 보호자 화면 4개의 DTO. 손으로 쓴 `fromJson` 입니다.
/// → `docs/SCREEN_RECIPE.md`
library;

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/entities/report_detail.dart';
import '../../domain/entities/report_summary.dart';

class MyPageSummaryDto {
  const MyPageSummaryDto({
    required this.childCount,
    required this.completedStories,
    required this.stardust,
    required this.hasNewReport,
    this.child,
  });

  factory MyPageSummaryDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> activity =
        json['activity'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Object? child = json['child'];
    return MyPageSummaryDto(
      child: child is Map<String, dynamic>
          ? MyPageChildDto.fromJson(child)
          : null,
      childCount: json['childCount'] as int? ?? 0,
      completedStories: activity['completedStories'] as int? ?? 0,
      stardust: activity['stardust'] as int? ?? 0,
      hasNewReport: json['hasNewReport'] as bool? ?? false,
    );
  }

  final MyPageChildDto? child;
  final int childCount;
  final int completedStories;
  final int stardust;
  final bool hasNewReport;

  MyPageSummary toEntity() => MyPageSummary(
    child: child?.toEntity(),
    childCount: childCount,
    completedStories: completedStories,
    stardust: stardust,
    hasNewReport: hasNewReport,
  );
}

class MyPageChildDto {
  const MyPageChildDto({
    required this.childId,
    required this.name,
    required this.age,
    this.avatar,
  });

  factory MyPageChildDto.fromJson(Map<String, dynamic> json) => MyPageChildDto(
    childId: json['childId']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    age: json['age'] as int? ?? 0,
    avatar: json['avatar'] as String?,
  );

  final String childId;
  final String name;
  final int age;
  final String? avatar;

  MyPageChild toEntity() =>
      MyPageChild(childId: childId, name: name, age: age, avatar: avatar);
}

class ReportListDto {
  const ReportListDto({
    required this.childName,
    required this.totalCount,
    required this.newCount,
    required this.reports,
  });

  factory ReportListDto.fromJson(Map<String, dynamic> json) => ReportListDto(
    childName: json['childName'] as String? ?? '',
    totalCount: json['totalCount'] as int? ?? 0,
    newCount: json['newCount'] as int? ?? 0,
    reports: (json['reports'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ReportSummaryDto.fromJson)
        .toList(growable: false),
  );

  final String childName;
  final int totalCount;
  final int newCount;
  final List<ReportSummaryDto> reports;

  ReportList toEntity() => ReportList(
    childName: childName,
    totalCount: totalCount,
    newCount: newCount,
    reports: reports
        .map((ReportSummaryDto dto) => dto.toEntity())
        .toList(growable: false),
  );
}

class ReportSummaryDto {
  const ReportSummaryDto({
    required this.sessionId,
    required this.storyTitle,
    required this.isNew,
    required this.playCount,
    required this.highlightUtterance,
    this.storyImage,
    this.completedAt,
  });

  factory ReportSummaryDto.fromJson(Map<String, dynamic> json) =>
      ReportSummaryDto(
        sessionId: json['sessionId'] as int? ?? 0,
        storyTitle: json['storyTitle'] as String? ?? '',
        storyImage: json['storyImage'] as String?,
        completedAt: json['completedAt'] as String?,
        isNew: json['isNew'] as bool? ?? false,
        playCount: json['playCount'] as int? ?? 1,
        highlightUtterance: json['highlightUtterance'] as String? ?? '',
      );

  final int sessionId;
  final String storyTitle;
  final String? storyImage;
  final String? completedAt;
  final bool isNew;
  final int playCount;
  final String highlightUtterance;

  ReportSummary toEntity() => ReportSummary(
    sessionId: sessionId,
    storyTitle: storyTitle,
    storyImage: storyImage,
    completedAt: _parseDate(completedAt),
    isNew: isNew,
    playCount: playCount,
    highlightUtterance: highlightUtterance,
  );
}

class ReportDetailDto {
  const ReportDetailDto({
    required this.sessionId,
    required this.childName,
    required this.storyTitle,
    required this.summary,
    required this.skills,
    required this.highlight,
    required this.questionGroups,
    this.storyImage,
    this.completedAt,
  });

  factory ReportDetailDto.fromJson(Map<String, dynamic> json) =>
      ReportDetailDto(
        sessionId: json['sessionId'] as int? ?? 0,
        childName: json['childName'] as String? ?? '',
        storyTitle: json['storyTitle'] as String? ?? '',
        storyImage: json['storyImage'] as String?,
        completedAt: json['completedAt'] as String?,
        summary: json['summary'] as String? ?? '',
        skills: (json['skills'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(SkillReportDto.fromJson)
            .toList(growable: false),
        highlight: ReportHighlightDto.fromJson(
          json['highlight'] as Map<String, dynamic>? ?? <String, dynamic>{},
        ),
        questionGroups:
            (json['questionGroups'] as List<dynamic>? ?? <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(QuestionGroupDto.fromJson)
                .toList(growable: false),
      );

  final int sessionId;
  final String childName;
  final String storyTitle;
  final String? storyImage;
  final String? completedAt;
  final String summary;
  final List<SkillReportDto> skills;
  final ReportHighlightDto highlight;
  final List<QuestionGroupDto> questionGroups;

  ReportDetail toEntity() => ReportDetail(
    sessionId: sessionId,
    childName: childName,
    storyTitle: storyTitle,
    storyImage: storyImage,
    completedAt: _parseDate(completedAt),
    summary: summary,
    skills: skills
        .map((SkillReportDto dto) => dto.toEntity())
        .toList(growable: false),
    highlight: highlight.toEntity(),
    questionGroups: questionGroups
        .map((QuestionGroupDto dto) => dto.toEntity())
        .toList(growable: false),
  );
}

class SkillReportDto {
  const SkillReportDto({
    required this.name,
    required this.feature,
    required this.evidence,
    required this.strength,
    required this.improvement,
    required this.askedWords,
  });

  factory SkillReportDto.fromJson(Map<String, dynamic> json) => SkillReportDto(
    name: json['name'] as String? ?? '',
    feature: json['feature'] as String? ?? '',
    evidence: _strings(json['evidence']),
    strength: json['strength'] as String? ?? '',
    improvement: json['improvement'] as String? ?? '',
    askedWords: _strings(json['askedWords']),
  );

  final String name;
  final String feature;
  final List<String> evidence;
  final String strength;
  final String improvement;
  final List<String> askedWords;

  SkillReport toEntity() => SkillReport(
    name: name,
    feature: feature,
    evidence: evidence,
    strength: strength,
    improvement: improvement,
    askedWords: askedWords,
  );
}

class ReportHighlightDto {
  const ReportHighlightDto({required this.utterance, required this.reason});

  factory ReportHighlightDto.fromJson(Map<String, dynamic> json) =>
      ReportHighlightDto(
        utterance: json['utterance'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
      );

  final String utterance;
  final String reason;

  ReportHighlight toEntity() =>
      ReportHighlight(utterance: utterance, reason: reason);
}

class QuestionGroupDto {
  const QuestionGroupDto({required this.title, required this.questions});

  factory QuestionGroupDto.fromJson(Map<String, dynamic> json) =>
      QuestionGroupDto(
        title: json['title'] as String? ?? '',
        questions: _strings(json['questions']),
      );

  final String title;
  final List<String> questions;

  QuestionGroup toEntity() => QuestionGroup(title: title, questions: questions);
}

class AppSettingsDto {
  const AppSettingsDto({
    required this.reportNotification,
    required this.marketingConsent,
    required this.accountType,
    required this.accountLabel,
    required this.hasNewNotice,
    required this.appVersion,
    this.consentAt,
  });

  factory AppSettingsDto.fromJson(Map<String, dynamic> json) => AppSettingsDto(
    reportNotification: json['reportNotification'] as bool? ?? false,
    marketingConsent: json['marketingConsent'] as bool? ?? false,
    consentAt: json['consentAt'] as String?,
    accountType: json['accountType'] as String? ?? '',
    accountLabel: json['accountLabel'] as String? ?? '',
    hasNewNotice: json['hasNewNotice'] as bool? ?? false,
    appVersion: json['appVersion'] as String? ?? '',
  );

  final bool reportNotification;
  final bool marketingConsent;
  final String? consentAt;
  final String accountType;
  final String accountLabel;
  final bool hasNewNotice;
  final String appVersion;

  AppSettings toEntity() => AppSettings(
    reportNotification: reportNotification,
    marketingConsent: marketingConsent,
    consentAt: _parseDate(consentAt),
    accountType: accountType,
    accountLabel: accountLabel,
    hasNewNotice: hasNewNotice,
    appVersion: appVersion,
  );
}

/// 타임존 없는 문자열이 와도 화면이 죽지 않게 방어합니다. (`docs/API.md` 2장)
DateTime? _parseDate(String? raw) =>
    raw == null ? null : DateTime.tryParse(raw)?.toLocal();

List<String> _strings(Object? raw) => (raw as List<dynamic>? ?? <dynamic>[])
    .whereType<String>()
    .toList(growable: false);
