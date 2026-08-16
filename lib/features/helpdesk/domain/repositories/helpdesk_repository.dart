import '../entities/helpdesk.dart';

/// 공지 / 이용 안내 / 문의 / 알림.
///
/// 앱이 쓰는 것은 문의 작성과 기기 토큰 등록뿐입니다. 나머지는 관리자 콘솔이
/// 만들고 여기서는 읽습니다.
abstract class HelpdeskRepository {
  /// 공개된 공지만. 고정 공지가 먼저 옵니다.
  Future<List<Notice>> getNotices();

  Future<Notice> getNotice(String noticeId);

  /// 이용 안내 전체. 본문까지 함께 옵니다 - 문서가 짧고 화면이 아코디언이라
  /// 펼칠 때마다 요청을 보내면 펼침이 한 박자씩 늦습니다.
  Future<List<Guide>> getGuides();

  Future<List<Inquiry>> getInquiries();

  Future<Inquiry> getInquiry(String inquiryId);

  Future<Inquiry> createInquiry({
    required InquiryCategory category,
    required String title,
    required String content,
  });

  Future<List<AppNotification>> getNotifications();

  /// 안 읽은 개수만. 홈이 뜰 때마다 부르는 값이라 목록 전체를 받지 않습니다.
  Future<int> getUnreadNotificationCount();

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead();

  /// 푸시 기기 등록. 앱이 뜰 때마다 부릅니다 - 토큰은 재설치나 미사용으로
  /// 바뀌고, 바뀐 것을 서버가 알 방법이 이 호출뿐입니다.
  Future<void> registerDevice({
    required String token,
    required String platform,
  });

  /// 로그아웃할 때. 이 기기로는 더 이상 알림이 가지 않습니다.
  Future<void> unregisterDevice(String token);
}
