import '../../domain/entities/report_detail.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/repositories/my_page_repository.dart';

/// 6각 그래프 데모용 목업.
///
/// 서버 `/sessions/{id}/report` 는 아직 축 점수를 내려주지 않습니다
/// (→ `claude/보호자리포트_6축그래프_설계안_D6.md`). 진짜 DTO
/// (`ReportRepositoryImpl`)는 건드리지 않고, `injector.dart` 의
/// `_useMockRepository` 가 true 인 동안만 이 경로를 씁니다 —
/// 화면·ViewModel 코드는 한 줄도 바뀌지 않습니다.
class ReportRepositoryMock implements ReportRepository {
  ReportRepositoryMock({this.latency = const Duration(milliseconds: 350)});

  final Duration latency;

  @override
  Future<ReportList> getReportList() async {
    await Future<void>.delayed(latency);
    return ReportList(
      childName: _childName,
      totalCount: _sessions.length,
      reports: <ReportSummary>[
        for (final ReportDetail detail in _sessions.values)
          ReportSummary(
            sessionId: detail.sessionId,
            storyTitle: detail.storyTitle,
            completedAt: detail.completedAt,
            playCount: 1,
            highlightUtterance: detail.highlight.utterance,
          ),
      ],
    );
  }

  @override
  Future<ReportDetail?> getReportDetail(String sessionId) async {
    await Future<void>.delayed(latency);
    return _sessions[sessionId];
  }
}

const String _childName = '서준이';

/// 회차 4 — 방귀 뀌는 며느리. 6축 모두 이번 이야기의 목표 요소라 전부
/// active. 지난 회차 평균이 있어 그래프에 점선 비교선이 함께 뜹니다.
final ReportDetail _session4 = ReportDetail(
  sessionId: '4',
  childName: _childName,
  storyTitle: '방귀 뀌는 며느리',
  completedAt: DateTime(2026, 8, 18, 19, 20),
  summary: '자기 생각을 이유와 함께 말하는 힘이 크게 자란 회차였어요.',
  skills: <SkillReport>[
    const SkillReport(
      name: '어휘',
      feature:
          '이야기에 나온 낯선 낱말을 그냥 넘기지 않고 세 번 물어봤어요. '
          '뜻을 들은 뒤에는 자기 문장 안에서 다시 써 보려고 했어요.',
      evidence: <String>['며느리가 뭐예요? 아들이랑 결혼한 사람이에요?', '참으면 배가 아프니까 뀌는 게 맞아요'],
      strength: '모르는 낱말을 그냥 지나치지 않고 물어봤어요.',
      improvement: '새로 배운 낱말을 다음 문장에서 한 번 더 써 보면 오래 기억에 남아요.',
      askedWords: <String>['며느리', '참다', '소문'],
    ),
    const SkillReport(
      name: '표현',
      feature:
          '등장인물의 기분을 자기 말로 옮겨 말했어요. 상대가 어떻게 느꼈을지 '
          '먼저 떠올린 뒤에 자기 의견을 붙이는 순서로 이야기했어요.',
      evidence: <String>['며느리도 창피해서 말을 못 했을 거예요. 그래서 계속 참았나 봐요.'],
      strength: '인물의 마음을 자기 경험에 빗대어 말했어요.',
      improvement: '"나라면"으로 시작하는 문장을 곁들이면 자기 생각이 더 또렷해져요.',
      askedWords: <String>[],
    ),
    const SkillReport(
      name: '논리',
      feature:
          '의견을 말할 때 이유를 함께 붙이는 문장이 여러 번 나왔어요. '
          '이유를 물어보기 전에 스스로 덧붙인 경우도 있었어요.',
      evidence: <String>['며느리를 내보내는 건 잘못한 거예요', '문을 조금 열어놓고 뀌면 괜찮을 것 같아요'],
      strength: '생각과 이유를 이어서 말했어요.',
      improvement: '그다음엔 어떻게 될지도 함께 말해 보면 생각이 더 단단해져요.',
      askedWords: <String>[],
    ),
  ],
  highlight: const ReportHighlight(
    utterance: '며느리도 창피해서 말을 못 했을 거예요. 그래서 계속 참았나 봐요.',
    reason: '인물의 마음을 헤아리고 자기 말로 풀어서 표현했어요.',
  ),
  questionGroups: <QuestionGroup>[
    const QuestionGroup(
      title: '이야기 주제 이어가기',
      questions: <String>[
        '며느리가 계속 참았으면 그다음엔 어떻게 됐을까?',
        '문을 열고 뀌면 정말 괜찮았을지 같이 상상해 볼까?',
      ],
    ),
    const QuestionGroup(
      title: '일상생활로 연결하기',
      questions: <String>[
        '너도 부끄러워서 하고 싶은 말을 못 한 적 있어?',
        '참았던 것 때문에 힘들었던 적 있어?',
      ],
    ),
  ],
  axisScores: <AxisScore>[
    const AxisScore(
      label: '이유대기',
      description: '왜 그렇게 생각했는지 근거를 붙여 말해요',
      active: true,
      score: 95,
      previousScore: 74,
      evidence: '왜냐면 계속 참으면 배가 아프니까 참지 말라고 해야 돼요',
    ),
    const AxisScore(
      label: '결과예측',
      description: '그 행동 다음에 벌어질 일을 미리 그려봐요',
      active: true,
      score: 28,
      previousScore: 22,
      evidence: '그러면 병이 날 것 같아요',
    ),
    const AxisScore(
      label: '판단력',
      description: '상황을 보고 스스로 판단·선택을 말해요',
      active: true,
      score: 85,
      previousScore: 70,
      evidence: '며느리를 내보내는 건 잘못한 거예요',
    ),
    const AxisScore(
      label: '해결력',
      description: '문제를 줄일 방법이나 바람을 제안해요',
      active: true,
      score: 64,
      previousScore: 55,
      evidence: '문을 조금 열어놓고 뀌면 괜찮을 것 같아요',
    ),
    const AxisScore(
      label: '관점이해',
      description: '다른 인물의 입장과 마음을 헤아려요',
      active: true,
      score: 68,
      previousScore: 58,
      evidence: '며느리도 창피해서 말을 못 했을 거예요',
    ),
    const AxisScore(
      label: '감정표현',
      description: '자기 감정을 자기 말로 표현해요',
      active: true,
      score: 100,
      previousScore: 82,
      evidence: '저는 며느리가 불쌍해서 속상했어요',
    ),
  ],
);

/// 회차 1 — 토끼와 거북이. 짧은 이야기라 요소 4개만 목표로 잡혀 있어서,
/// 결과예측·관점이해 두 축은 비활성(회색 빗금)입니다. 첫 회차라
/// 지난 평균 비교선도 없습니다.
final ReportDetail _session1 = ReportDetail(
  sessionId: '1',
  childName: _childName,
  storyTitle: '토끼와 거북이',
  completedAt: DateTime(2026, 8, 8, 19, 5),
  summary: '처음 만난 이야기인데도 자기 생각을 이유와 함께 씩씩하게 말했어요.',
  skills: <SkillReport>[
    const SkillReport(
      name: '어휘',
      feature: '이야기에 나온 낱말의 뜻을 스스로 물어보고, 들은 뜻을 자기 문장에 담아 봤어요.',
      evidence: <String>['낮잠이 뭐예요? 낮에 자는 잠이에요?'],
      strength: '모르는 낱말을 그냥 지나치지 않고 물어봤어요.',
      improvement: '새로 배운 낱말을 다음에 또 써 보면 오래 기억에 남아요.',
      askedWords: <String>['낮잠', '꾸준히'],
    ),
    const SkillReport(
      name: '표현',
      feature: '경기를 지켜본 자기 기분을 스스럼없이 말로 표현했어요.',
      evidence: <String>['거북이가 이겨서 저도 기분이 좋았어요'],
      strength: '자기 감정을 자기 말로 편하게 표현했어요.',
      improvement: '다른 인물의 마음도 함께 상상해 보면 이야기가 더 풍성해져요.',
      askedWords: <String>[],
    ),
    const SkillReport(
      name: '논리',
      feature: '판단을 말할 때 이유를 붙이는 문장이 나왔어요. 첫 이야기치고 자연스러운 시작이에요.',
      evidence: <String>['거북이가 안 쉬고 간 건 잘한 거예요. 느려도 계속 갔으니까요.'],
      strength: '생각과 이유를 이어서 말했어요.',
      improvement: '다음엔 그다음에 어떤 일이 생길지도 붙여 보면 좋아요.',
      askedWords: <String>[],
    ),
  ],
  highlight: const ReportHighlight(
    utterance: '거북이가 안 쉬고 간 건 잘한 거예요. 느려도 계속 갔으니까요.',
    reason: '판단과 그 이유를 한 문장으로 자연스럽게 이었어요.',
  ),
  questionGroups: <QuestionGroup>[
    const QuestionGroup(
      title: '이야기 주제 이어가기',
      questions: <String>['토끼가 어떻게 했으면 안 졌을까?', '거북이처럼 꾸준히 해서 좋았던 적 있어?'],
    ),
    const QuestionGroup(
      title: '일상생활로 연결하기',
      questions: <String>['너무 자신 있어서 방심했던 적 있어?', '느려도 끝까지 해낸 적 있어?'],
    ),
  ],
  axisScores: <AxisScore>[
    const AxisScore(
      label: '이유대기',
      description: '왜 그렇게 생각했는지 근거를 붙여 말해요',
      active: true,
      score: 85,
      evidence: '토끼가 자기가 빠르다고 생각해서 잤어요',
    ),
    const AxisScore(
      label: '결과예측',
      description: '그 행동 다음에 벌어질 일을 미리 그려봐요',
      active: false,
    ),
    const AxisScore(
      label: '판단력',
      description: '상황을 보고 스스로 판단·선택을 말해요',
      active: true,
      score: 43,
      evidence: '거북이가 안 쉬고 간 건 잘한 거예요',
    ),
    const AxisScore(
      label: '해결력',
      description: '문제를 줄일 방법이나 바람을 제안해요',
      active: true,
      score: 28,
      evidence: '토끼가 알람을 맞춰 놓으면 돼요',
    ),
    const AxisScore(
      label: '관점이해',
      description: '다른 인물의 입장과 마음을 헤아려요',
      active: false,
    ),
    const AxisScore(
      label: '감정표현',
      description: '자기 감정을 자기 말로 표현해요',
      active: true,
      score: 100,
      evidence: '거북이가 이겨서 저도 기분이 좋았어요',
    ),
  ],
);

final Map<String, ReportDetail> _sessions = <String, ReportDetail>{
  '4': _session4,
  '1': _session1,
};
