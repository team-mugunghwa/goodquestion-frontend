import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/helpdesk_dto.dart';

/// 고객 지원 HTTP 호출. 엔드포인트 문자열은 여기에만 둡니다.
///
/// → `docs/API.md`
class HelpdeskRemoteDataSource {
  const HelpdeskRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<NoticeDto>> getNotices() =>
      _client.get('/notices', parse: (data) => _list(data, NoticeDto.fromJson));

  Future<NoticeDto> getNotice(String noticeId) => _client.get(
    '/notices/$noticeId',
    parse: (data) => NoticeDto.fromJson(_map(data)),
  );

  Future<List<GuideDto>> getGuides() =>
      _client.get('/guides', parse: (data) => _list(data, GuideDto.fromJson));

  Future<List<InquiryDto>> getInquiries() => _client.get(
    '/inquiries',
    // 목록만 봉투에 담겨 옵니다({inquiries: [...]}).
    parse: (data) => _list(_map(data)['inquiries'], InquiryDto.fromJson),
  );

  Future<InquiryDto> getInquiry(String inquiryId) => _client.get(
    '/inquiries/$inquiryId',
    parse: (data) => InquiryDto.fromJson(_map(data)),
  );

  Future<InquiryDto> createInquiry(Map<String, dynamic> body) => _client.post(
    '/inquiries',
    body: body,
    parse: (data) => InquiryDto.fromJson(_map(data)),
  );

  Future<InquiryDto> updateInquiry(
    String inquiryId,
    Map<String, dynamic> body,
  ) => _client.patch(
    '/inquiries/$inquiryId',
    body: body,
    parse: (data) => InquiryDto.fromJson(_map(data)),
  );

  Future<void> deleteInquiry(String inquiryId) =>
      _client.delete('/inquiries/$inquiryId');

  Future<NotificationListDto> getNotifications() => _client.get(
    '/notifications',
    parse: (data) => NotificationListDto.fromJson(_map(data)),
  );

  Future<int> getUnreadCount() => _client.get(
    '/notifications/unread-count',
    parse: (data) => (_map(data)['unreadCount'] as num?)?.toInt() ?? 0,
  );

  Future<void> markRead(String notificationId) =>
      _client.patch<void>('/notifications/$notificationId/read', parse: (_) {});

  Future<void> markAllRead() =>
      _client.post<void>('/notifications/read-all', parse: (_) {});

  Future<void> registerDevice(String token, String platform) =>
      _client.post<void>(
        '/notifications/devices',
        body: {'token': token, 'platform': platform},
        parse: (_) {},
      );

  Future<void> unregisterDevice(String token) =>
      _client.delete('/notifications/devices/$token');

  static Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const ParseException();
  }

  static List<T> _list<T>(
    Object? data,
    T Function(Map<String, dynamic> json) parse,
  ) => data is List
      ? data.whereType<Map<String, dynamic>>().map(parse).toList()
      : const [];
}
