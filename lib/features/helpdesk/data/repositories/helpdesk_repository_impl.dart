import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/helpdesk.dart';
import '../../domain/repositories/helpdesk_repository.dart';
import '../datasources/helpdesk_remote_data_source.dart';

/// data 예외를 domain 실패로 번역합니다.
class HelpdeskRepositoryImpl implements HelpdeskRepository {
  const HelpdeskRepositoryImpl(this._remote);

  final HelpdeskRemoteDataSource _remote;

  @override
  Future<List<Notice>> getNotices() => _guard(
    () async =>
        (await _remote.getNotices()).map((dto) => dto.toEntity()).toList(),
  );

  @override
  Future<Notice> getNotice(String noticeId) =>
      _guard(() async => (await _remote.getNotice(noticeId)).toEntity());

  @override
  Future<List<Guide>> getGuides() => _guard(
    () async =>
        (await _remote.getGuides()).map((dto) => dto.toEntity()).toList(),
  );

  @override
  Future<List<Inquiry>> getInquiries() => _guard(
    () async =>
        (await _remote.getInquiries()).map((dto) => dto.toEntity()).toList(),
  );

  @override
  Future<Inquiry> getInquiry(String inquiryId) =>
      _guard(() async => (await _remote.getInquiry(inquiryId)).toEntity());

  @override
  Future<Inquiry> createInquiry({
    required InquiryCategory category,
    required String title,
    required String content,
  }) => _guard(
    () async => (await _remote.createInquiry({
      'category': category.code,
      'title': title,
      'content': content,
    })).toEntity(),
  );

  @override
  Future<Inquiry> updateInquiry(
    String inquiryId, {
    required InquiryCategory category,
    required String title,
    required String content,
  }) => _guard(
    () async => (await _remote.updateInquiry(inquiryId, {
      'category': category.code,
      'title': title,
      'content': content,
    })).toEntity(),
  );

  @override
  Future<void> deleteInquiry(String inquiryId) =>
      _guard(() => _remote.deleteInquiry(inquiryId));

  @override
  Future<List<AppNotification>> getNotifications() =>
      _guard(() async => (await _remote.getNotifications()).notifications);

  @override
  Future<int> getUnreadNotificationCount() => _guard(_remote.getUnreadCount);

  @override
  Future<void> markNotificationRead(String notificationId) =>
      _guard(() => _remote.markRead(notificationId));

  @override
  Future<void> markAllNotificationsRead() => _guard(_remote.markAllRead);

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) => _guard(() => _remote.registerDevice(token, platform));

  @override
  Future<void> unregisterDevice(String token) =>
      _guard(() => _remote.unregisterDevice(token));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException catch (e) {
      throw Failure.fromException(e);
    }
  }
}
