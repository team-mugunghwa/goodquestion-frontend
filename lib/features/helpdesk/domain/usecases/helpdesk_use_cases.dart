import '../entities/helpdesk.dart';
import '../repositories/helpdesk_repository.dart';

/// 고객 지원 UseCase 모음.
///
/// 한 파일에 여러 UseCase 를 두는 것은 `auth_use_cases.dart` 와 같은 방식입니다.

class GetNoticesUseCase {
  const GetNoticesUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<List<Notice>> call() => _repository.getNotices();
}

class GetNoticeUseCase {
  const GetNoticeUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<Notice> call(String noticeId) => _repository.getNotice(noticeId);
}

class GetGuidesUseCase {
  const GetGuidesUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<List<Guide>> call() => _repository.getGuides();
}

class GetInquiriesUseCase {
  const GetInquiriesUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<List<Inquiry>> call() => _repository.getInquiries();
}

class GetInquiryUseCase {
  const GetInquiryUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<Inquiry> call(String inquiryId) => _repository.getInquiry(inquiryId);
}

class CreateInquiryUseCase {
  const CreateInquiryUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<Inquiry> call({
    required InquiryCategory category,
    required String title,
    required String content,
  }) => _repository.createInquiry(
    category: category,
    title: title,
    content: content,
  );
}

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<List<AppNotification>> call() => _repository.getNotifications();
}

class GetUnreadNotificationCountUseCase {
  const GetUnreadNotificationCountUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<int> call() => _repository.getUnreadNotificationCount();
}

class MarkNotificationReadUseCase {
  const MarkNotificationReadUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<void> call(String notificationId) =>
      _repository.markNotificationRead(notificationId);
}

class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<void> call() => _repository.markAllNotificationsRead();
}

class RegisterDeviceUseCase {
  const RegisterDeviceUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<void> call({required String token, required String platform}) =>
      _repository.registerDevice(token: token, platform: platform);
}

class UnregisterDeviceUseCase {
  const UnregisterDeviceUseCase(this._repository);
  final HelpdeskRepository _repository;

  Future<void> call(String token) => _repository.unregisterDevice(token);
}
