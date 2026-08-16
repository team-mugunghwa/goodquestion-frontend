/// 리포트 목록의 카드 한 장.
class ReportSummary {
  const ReportSummary({
    required this.sessionId,
    required this.storyTitle,
    required this.completedAt,
    required this.playCount,
    required this.highlightUtterance,
    this.storyImage,
  });

  /// 백엔드 세션 UUID. 숫자로 바꾸면 UUID 라우트가 손실됩니다.
  final String sessionId;
  final String storyTitle;
  final String? storyImage;
  final DateTime? completedAt;

  /// 같은 이야기를 몇 번째 하는지. **회차 표기가 없으면** 같은 제목의 카드가
  /// 여러 장 쌓였을 때 보호자에게 중복으로 보입니다.
  final int playCount;

  /// 대표 발화 한 줄 미리보기.
  final String highlightUtterance;
}

/// 리포트 목록 화면이 한 번에 받는 것.
class ReportList {
  const ReportList({
    required this.childName,
    required this.totalCount,
    required this.reports,
  });

  /// 헤더의 읽기 전용 라벨. **이 화면에서 아이를 바꾸지 않습니다** —
  /// 전환은 마이페이지의 몫이고, 여기서 허용하면 게이트 통과 상태와
  /// child_id 동기화가 꼬입니다.
  final String childName;

  final int totalCount;

  /// 최신순. 서버 순서를 그대로 씁니다.
  final List<ReportSummary> reports;

  bool get isEmpty => reports.isEmpty;
}
