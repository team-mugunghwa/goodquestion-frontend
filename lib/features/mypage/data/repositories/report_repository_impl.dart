import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/entities/report_detail.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/repositories/my_page_repository.dart';
import '../datasources/report_remote_data_source.dart';
import '../dtos/report_response_dto.dart';

/// 백엔드의 저장된 리포트를 보호자 화면 모델로 구성합니다.
///
/// 역량명·문장은 서버(`ReportPromptBuilder`)가 이미 보호자용으로 다듬어서
/// 내려주므로, 여기서는 응답을 [ReportDetail] 모양으로 옮기기만 합니다 —
/// 내부 분석 태그를 조합해 문장을 새로 짓지 않습니다.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._remote, this._children);

  final ReportRemoteDataSource _remote;
  final ChildProfileRepository _children;

  @override
  Future<ReportList> getReportList() => _guard(() async {
    final MyPageChild child = await _selectedChild();
    final List<ReportListResponseDto> responses = await _remote.fetchReports(
      child.childId,
    );
    final Map<String, int> rounds = _playRounds(responses);
    final List<ReportSummary> reports = responses
        .map(
          (ReportListResponseDto response) => ReportSummary(
            sessionId: response.sessionId,
            storyTitle: response.storyTitle,
            completedAt: response.createdAt,
            playCount: rounds[response.sessionId] ?? 1,
            // 목록 API에는 발화가 없습니다. 상세를 보지 않고 실제 발화를
            // 추측해서 표시하지 않습니다.
            highlightUtterance: '리포트를 열어 아이의 실제 발화를 확인해 보세요.',
          ),
        )
        .toList(growable: false);
    return ReportList(
      childName: child.name,
      totalCount: reports.length,
      reports: reports,
    );
  });

  @override
  Future<ReportDetail?> getReportDetail(String sessionId) async {
    try {
      final MyPageChild child = await _selectedChild();
      final ReportDetailResponseDto response = await _remote.fetchReport(
        sessionId,
      );
      return _toDetail(response, child.name);
    } on ServerException catch (error) {
      if (error.statusCode == 409 || error.code == 'REPORT_NOT_READY') {
        return null;
      }
      throw Failure.fromException(error);
    } on Failure {
      rethrow;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    } on Object catch (error) {
      throw Failure.fromException(ParseException('$error'));
    }
  }

  Future<MyPageChild> _selectedChild() async {
    final List<MyPageChild> children = await _children.getChildren();
    if (children.isEmpty) {
      throw const UnknownFailure('아이 프로필을 먼저 만들어 주세요.');
    }
    final String? selectedId = _children.selectedChildId;
    for (final MyPageChild child in children) {
      if (child.childId == selectedId) return child;
    }
    final MyPageChild child = children.first;
    await _children.selectChild(child.childId);
    return child;
  }

  Map<String, int> _playRounds(List<ReportListResponseDto> reports) {
    final Map<String, int> counts = <String, int>{};
    final Map<String, int> rounds = <String, int>{};
    // API는 최신순입니다. 오래된 항목부터 세야 각 카드의 실제 회차가 됩니다.
    for (final ReportListResponseDto report in reports.reversed) {
      final int round = (counts[report.storyTitle] ?? 0) + 1;
      counts[report.storyTitle] = round;
      rounds[report.sessionId] = round;
    }
    return rounds;
  }

  ReportDetail _toDetail(ReportDetailResponseDto response, String childName) {
    return ReportDetail(
      sessionId: response.sessionId,
      childName: childName,
      storyTitle: response.storyTitle,
      completedAt: response.createdAt,
      summary: response.summary,
      skills: <SkillReport>[
        _vocabularySkill(response.vocabulary),
        for (final CompetencyResponseDto competency in response.competencies)
          _competencySkill(competency),
      ],
      highlight: ReportHighlight(
        utterance: response.representativeUtterance.text.isEmpty
            ? '아이의 대표 발화를 준비하고 있어요.'
            : response.representativeUtterance.text,
        reason: response.representativeUtterance.reason.isEmpty
            ? '신뢰할 수 있는 실제 발화가 더 모이면 이곳에 소개할게요.'
            : response.representativeUtterance.reason,
      ),
      questionGroups: _questionGroups(response.homeGuide),
    );
  }

  /// 어휘는 역량 카드와 달리 강점/보완이 나뉘어 오지 않고 [VocabularyResponseDto.feedback]
  /// 한 덩어리로 온다 — 5단 카드 모양(feature/strength/improvement)에 맞춰 나눠 담는다.
  SkillReport _vocabularySkill(VocabularyResponseDto vocabulary) {
    final List<String> evidence = vocabulary.repeatedExpressions.isNotEmpty
        ? vocabulary.repeatedExpressions
        : vocabulary.mainWords;
    return SkillReport(
      name: '어휘',
      feature: vocabulary.feedback.isNotEmpty
          ? vocabulary.feedback
          : '이번 활동의 어휘 기록을 준비하고 있어요.',
      evidence: evidence,
      strength: vocabulary.mainWords.isNotEmpty
          ? '이야기 속 낱말을 자기 문장 안에서 자연스럽게 사용했어요.'
          : '새로운 발화가 쌓이면 아이가 사용한 표현을 함께 살펴볼 수 있어요.',
      improvement: vocabulary.feedback.isNotEmpty
          ? vocabulary.feedback
          : '다음에는 같은 생각을 다른 낱말로도 표현해 보면 좋아요.',
      askedWords: vocabulary.askedWords,
    );
  }

  /// 역량 카드는 서버가 이미 5단 순서(이름→특징→근거→잘한 점→보완)로 내려주므로
  /// 그대로 옮긴다.
  SkillReport _competencySkill(CompetencyResponseDto competency) =>
      SkillReport(
        name: competency.name,
        feature: competency.finding,
        evidence: competency.evidenceUtterance.isEmpty
            ? const <String>[]
            : <String>[competency.evidenceUtterance],
        strength: competency.strength,
        improvement: competency.nextFocus,
        askedWords: const <String>[],
      );

  List<QuestionGroup> _questionGroups(HomeGuideResponseDto homeGuide) =>
      <QuestionGroup>[
        QuestionGroup(
          title: '이야기 주제 이어가기',
          questions: homeGuide.storyQuestions,
        ),
        QuestionGroup(
          title: '일상생활로 연결하기',
          questions: homeGuide.dailyLifeQuestions,
        ),
      ];

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    } on Object catch (error) {
      throw Failure.fromException(ParseException('$error'));
    }
  }
}
