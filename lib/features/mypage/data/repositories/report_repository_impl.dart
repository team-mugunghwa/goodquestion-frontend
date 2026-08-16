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
/// 서버 DTO에 없는 분석 태그명은 화면에 내보내지 않고, 태그는 오직
/// 어휘·표현·논리 영역을 고르는 데만 사용합니다.
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
    final List<RepresentativeUtteranceResponseDto> utterances = response
        .representativeUtterances
        .where(
          (RepresentativeUtteranceResponseDto item) => item.text.isNotEmpty,
        )
        .toList(growable: false);
    final RepresentativeUtteranceResponseDto? highlight = _highlight(
      response,
      utterances,
    );
    return ReportDetail(
      sessionId: response.sessionId,
      childName: childName,
      storyTitle: response.storyTitle,
      completedAt: response.createdAt,
      summary: response.summary,
      skills: <SkillReport>[
        _vocabularySkill(utterances),
        _skill(
          name: '표현',
          elements: _expressionElements,
          strengths: response.strengths,
          nextFocus: response.nextFocus,
          utterances: utterances,
        ),
        _skill(
          name: '논리',
          elements: _logicElements,
          strengths: response.strengths,
          nextFocus: response.nextFocus,
          utterances: utterances,
        ),
      ],
      highlight: ReportHighlight(
        utterance: highlight?.text ?? '아이의 대표 발화를 준비하고 있어요.',
        reason: highlight == null
            ? '신뢰할 수 있는 실제 발화가 더 모이면 이곳에 소개할게요.'
            : _highlightReason(highlight.element),
      ),
      questionGroups: _questionGroups(response.storyTitle, response.nextFocus),
    );
  }

  SkillReport _vocabularySkill(
    List<RepresentativeUtteranceResponseDto> utterances,
  ) => SkillReport(
    name: '어휘',
    feature: utterances.isEmpty
        ? '이번 활동의 어휘 기록을 준비하고 있어요.'
        : '이야기 맥락에 맞는 낱말을 사용해 자기 생각을 문장으로 표현했어요.',
    evidence: utterances
        .take(2)
        .map((item) => item.text)
        .toList(growable: false),
    strength: utterances.isEmpty
        ? '새로운 발화가 쌓이면 아이가 사용한 표현을 함께 살펴볼 수 있어요.'
        : '떠올린 생각을 익숙한 낱말로 자연스럽게 말했어요.',
    improvement: '다음에는 같은 생각을 다른 낱말로도 표현해 보면 좋아요.',
    askedWords: const <String>[],
  );

  SkillReport _skill({
    required String name,
    required Set<String> elements,
    required List<ReportItemResponseDto> strengths,
    required List<ReportItemResponseDto> nextFocus,
    required List<RepresentativeUtteranceResponseDto> utterances,
  }) {
    final List<String> positive = strengths
        .where((ReportItemResponseDto item) => elements.contains(item.element))
        .map((ReportItemResponseDto item) => item.comment)
        .where((String text) => text.isNotEmpty)
        .toList(growable: false);
    final List<String> next = nextFocus
        .where((ReportItemResponseDto item) => elements.contains(item.element))
        .map((ReportItemResponseDto item) => item.comment)
        .where((String text) => text.isNotEmpty)
        .toList(growable: false);
    final List<String> evidence = utterances
        .where(
          (RepresentativeUtteranceResponseDto item) =>
              elements.contains(item.element),
        )
        .map((RepresentativeUtteranceResponseDto item) => item.text)
        .take(2)
        .toList(growable: false);
    final String defaultStrength = name == '표현'
        ? '인물의 마음과 자기 생각을 자연스럽게 표현했어요.'
        : '생각의 흐름을 문장으로 이어 말했어요.';
    final String defaultNext = name == '표현'
        ? '다음에는 다른 인물의 마음도 함께 상상해 보면 좋아요.'
        : '다음에는 생각에 까닭이나 예상 결과를 덧붙여 보면 좋아요.';
    return SkillReport(
      name: name,
      feature: positive.isEmpty
          ? '$name의 특징은 실제 발화가 더 모이면 자세히 살펴볼 수 있어요.'
          : positive.join(' '),
      evidence: evidence,
      strength: positive.isEmpty ? defaultStrength : positive.join(' '),
      improvement: next.isEmpty ? defaultNext : next.join(' '),
      askedWords: const <String>[],
    );
  }

  RepresentativeUtteranceResponseDto? _highlight(
    ReportDetailResponseDto response,
    List<RepresentativeUtteranceResponseDto> utterances,
  ) {
    for (final ReportItemResponseDto strength in response.strengths) {
      for (final RepresentativeUtteranceResponseDto utterance in utterances) {
        if (utterance.element == strength.element) return utterance;
      }
    }
    return utterances.isEmpty ? null : utterances.first;
  }

  String _highlightReason(String element) {
    if (_expressionElements.contains(element)) {
      return '인물의 마음이나 상황을 이해하고 자기 말로 표현한 점이 잘 드러나요.';
    }
    if (_logicElements.contains(element)) {
      return '자기 생각을 까닭이나 해결 방법과 자연스럽게 연결했어요.';
    }
    return '이야기의 맥락에 맞게 자기 생각을 자연스럽게 말했어요.';
  }

  List<QuestionGroup> _questionGroups(
    String storyTitle,
    List<ReportItemResponseDto> nextFocus,
  ) {
    final bool isBanggui =
        storyTitle.contains('방귀') || storyTitle.contains('며느리');
    final bool needsReason = nextFocus.any(
      (ReportItemResponseDto item) =>
          item.element == 'REASON' || item.element == 'RESULT',
    );
    return <QuestionGroup>[
      QuestionGroup(
        title: '이야기 주제 이어가기',
        questions: isBanggui
            ? <String>[
                '시아버지는 며느리에게 어떤 말을 해 주면 좋을까?',
                needsReason
                    ? '며느리가 방귀를 계속 숨겼다면 어떤 일이 생겼을까? 왜 그렇게 생각해?'
                    : '며느리의 특별한 능력을 어디에 또 활용할 수 있을까?',
              ]
            : <String>[
                '$storyTitle 속 인물에게 어떤 말을 해 주고 싶어?',
                '이야기의 다음 장면에는 어떤 일이 생길까? 왜 그렇게 생각해?',
              ],
      ),
      const QuestionGroup(
        title: '일상생활로 연결하기',
        questions: <String>[
          '너도 부끄러워서 하고 싶은 말을 하지 못한 적이 있어?',
          '친구가 자기 특징 때문에 속상해한다면 어떤 말을 해 주고 싶어?',
        ],
      ),
    ];
  }

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

const Set<String> _expressionElements = <String>{
  'PERSPECTIVE',
  'EMPATHY',
  'EMOTION',
  'REQUEST',
};
const Set<String> _logicElements = <String>{
  'DECISION',
  'REASON',
  'RESULT',
  'SOLUTION',
};
