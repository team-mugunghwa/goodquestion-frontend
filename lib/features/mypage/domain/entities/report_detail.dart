/// 세션 1건의 리포트 전체.
///
/// ## 이 엔티티의 톤이 곧 제품입니다
///
/// PRD F-09 의 규칙이 여기 그대로 걸려 있습니다 —
/// **잘한 점 먼저, 단정적 부정 표현 금지, 내부 태그(DECISION·REASON 등) 미노출.**
/// 더미 텍스트 단계에서부터 지키지 않으면 나중에 전부 다시 씁니다.
class ReportDetail {
  const ReportDetail({
    required this.sessionId,
    required this.childName,
    required this.storyTitle,
    required this.summary,
    required this.skills,
    required this.highlight,
    required this.questionGroups,
    this.axisScores = const <AxisScore>[],
    this.storyImage,
    this.completedAt,
  });

  final String sessionId;
  final String childName;
  final String storyTitle;
  final String? storyImage;
  final DateTime? completedAt;

  /// 한 줄 총평. **잘한 점 중심**으로, 최상단에 둡니다 — 보호자가 스크롤을
  /// 끝까지 안 내려도 "아이가 잘했다"는 인상을 먼저 받아야 합니다.
  final String summary;

  /// 어휘 · 표현 · 논리 세 영역.
  final List<SkillReport> skills;

  final ReportHighlight highlight;

  /// 이야기 이어가기 / 일상 연결.
  final List<QuestionGroup> questionGroups;

  /// 6각 그래프용 축 점수. 정확히 6개, 고정 순서
  /// (이유대기·결과예측·판단력·해결력·관점이해·감정표현).
  ///
  /// 서버 DTO(`ReportDetailResponseDto`)에는 아직 없는 필드라 기본값은
  /// 빈 목록입니다 — 화면은 비어 있으면 그래프 섹션 자체를 숨깁니다.
  /// 지금은 [ReportRepositoryMock] 경로에서만 채워집니다.
  /// → 기획 문서: claude/보호자리포트_6축그래프_설계안_D6.md (D6)
  final List<AxisScore> axisScores;
}

/// 6각 그래프의 축 하나.
///
/// **엔진 태그(REASON 등)를 담지 않습니다** — [label]은 이미 보호자용
/// 한글 표현으로 바뀐 값입니다. (PRD F-09, 내부 태그 미노출 규칙)
class AxisScore {
  const AxisScore({
    required this.label,
    required this.description,
    required this.active,
    this.score,
    this.previousScore,
    this.evidence,
  });

  final String label;

  /// 축 설명 한 줄.
  final String description;

  /// 이번 이야기의 목표 사고 요소가 아니면 false.
  ///
  /// **0점이 아니라 "측정 안 함"으로 표시합니다** — 0으로 찍으면 "못한
  /// 축"으로 오독됩니다. (D7 관련 — 1회차 리포트에서 특히 중요)
  final bool active;

  /// 0~100. [active]가 false면 항상 null.
  final int? score;

  /// 지난 회차 평균. 1회차이거나 [active]가 false면 null.
  final int? previousScore;

  /// 근거가 되는 아이 발화 원문 1건.
  final String? evidence;
}

/// 역량 카드 하나. **5단 순서를 재배열하지 마세요** —
/// 역량명 → 이번 활동의 특징 → 근거 발화 → 잘한 점 → 보완할 부분.
class SkillReport {
  const SkillReport({
    required this.name,
    required this.feature,
    required this.evidence,
    required this.strength,
    required this.improvement,
    required this.askedWords,
  });

  /// "어휘" · "표현" · "논리"
  final String name;

  /// 이번 활동의 특징 2~3문장.
  final String feature;

  /// 근거가 되는 아이 발화 원문. 접혀 있다가 펼치면 보입니다.
  final List<String> evidence;

  final String strength;

  /// 보완할 부분. **권유형 문장만** 옵니다. ("~해보면 좋아요")
  final String improvement;

  /// 어휘 영역 전용 — 아이가 단어장에 담은 낱말. 다른 영역은 빈 목록입니다.
  final List<String> askedWords;
}

/// 이번 세션에서 고른 아이 발화 1건.
///
/// **음성 재생 버튼을 두지 않습니다.** 음성 원본을 저장하지 않는 게 정책이라
/// 재생기를 만들면 지킬 수 없는 약속이 됩니다.
class ReportHighlight {
  const ReportHighlight({required this.utterance, required this.reason});

  final String utterance;
  final String reason;
}

/// 가정 연계 질문 묶음.
class QuestionGroup {
  const QuestionGroup({required this.title, required this.questions});

  final String title;
  final List<String> questions;
}
