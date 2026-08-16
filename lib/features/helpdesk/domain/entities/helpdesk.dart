/// 고객 지원 영역의 도메인 모델.
///
/// 공지 / 이용 안내 / 문의 / 알림은 화면이 다르지만 하나의 흐름입니다 -
/// 공지를 읽다 궁금해서 문의를 쓰고, 답변이 오면 알림으로 돌아옵니다.
/// 그래서 feature 를 넷으로 쪼개지 않고 `helpdesk` 하나에 담았습니다.
///
/// 이 데이터를 만드는 것은 **관리자 콘솔**입니다(문의와 기기 토큰만 예외).
/// 앱은 읽기만 하므로 엔티티에 상태를 바꾸는 메서드가 없습니다.
library;

enum NoticeCategory {
  general('GENERAL', '일반'),
  update('UPDATE', '업데이트'),
  event('EVENT', '이벤트'),
  maintenance('MAINTENANCE', '점검');

  const NoticeCategory(this.code, this.label);

  final String code;
  final String label;

  static NoticeCategory fromCode(String? code) => NoticeCategory.values
      .firstWhere((c) => c.code == code, orElse: () => NoticeCategory.general);
}

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.category,
    required this.pinned,
    this.content,
    this.publishedAt,
  });

  final String id;
  final String title;
  final NoticeCategory category;

  /// 목록 맨 위 고정. 점검 안내처럼 먼저 봐야 하는 공지입니다.
  final bool pinned;

  /// 목록 응답에는 없습니다. 상세를 열 때 채워집니다.
  final String? content;
  final DateTime? publishedAt;

  Notice withContent(String content) => Notice(
    id: id,
    title: title,
    category: category,
    pinned: pinned,
    content: content,
    publishedAt: publishedAt,
  );
}

enum GuideCategory {
  basic('BASIC', '서비스 소개'),
  account('ACCOUNT', '계정/아이 프로필'),
  play('PLAY', '이야기 진행'),
  reward('REWARD', '별가루/행성'),
  trouble('TROUBLE', '문제 해결');

  const GuideCategory(this.code, this.label);

  final String code;
  final String label;

  static GuideCategory fromCode(String? code) => GuideCategory.values
      .firstWhere((c) => c.code == code, orElse: () => GuideCategory.basic);
}

class Guide {
  const Guide({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
  });

  final String id;
  final GuideCategory category;
  final String title;
  final String content;
}

enum InquiryCategory {
  account('ACCOUNT', '계정'),
  payment('PAYMENT', '결제'),
  content('CONTENT', '이야기 내용'),
  bug('BUG', '오류 신고'),
  suggestion('SUGGESTION', '제안'),
  etc('ETC', '기타');

  const InquiryCategory(this.code, this.label);

  final String code;
  final String label;

  static InquiryCategory fromCode(String? code) => InquiryCategory.values
      .firstWhere((c) => c.code == code, orElse: () => InquiryCategory.etc);
}

enum InquiryStatus {
  pending('PENDING', '답변 대기'),
  answered('ANSWERED', '답변 완료'),
  closed('CLOSED', '종료');

  const InquiryStatus(this.code, this.label);

  final String code;
  final String label;

  static InquiryStatus fromCode(String? code) =>
      InquiryStatus.values.firstWhere(
        (status) => status.code == code,
        orElse: () => InquiryStatus.pending,
      );
}

class InquiryAnswer {
  const InquiryAnswer({
    required this.adminName,
    required this.content,
    this.answeredAt,
  });

  final String adminName;
  final String content;
  final DateTime? answeredAt;
}

class Inquiry {
  const Inquiry({
    required this.id,
    required this.category,
    required this.title,
    required this.status,
    required this.answered,
    this.content,
    this.createdAt,
    this.answer,
  });

  final String id;
  final InquiryCategory category;
  final String title;
  final InquiryStatus status;

  /// 답변 여부. 목록에서 배지 하나로 쓰려고 상태와 별개로 받습니다.
  final bool answered;

  /// 목록 응답에는 없습니다. 상세를 열 때 채워집니다.
  final String? content;
  final DateTime? createdAt;

  /// 아직 답변이 없으면 null.
  final InquiryAnswer? answer;
}

enum NotificationType {
  inquiryAnswered('INQUIRY_ANSWERED'),
  notice('NOTICE'),
  system('SYSTEM');

  const NotificationType(this.code);

  final String code;

  static NotificationType fromCode(String? code) => NotificationType.values
      .firstWhere((t) => t.code == code, orElse: () => NotificationType.system);
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.linkPath,
    this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool read;

  /// 누르면 이동할 앱 안의 경로. 관리자 콘솔이 만들 때 넣어 줍니다.
  final String? linkPath;
  final DateTime? createdAt;
}
