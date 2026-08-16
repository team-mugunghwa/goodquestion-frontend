import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/helpdesk.dart';
import '../../domain/usecases/helpdesk_use_cases.dart';

/// 고객 지원 화면들의 ViewModel.
///
/// 넷 다 "불러와서 보여준다"가 전부라 파일을 나누지 않았습니다. 문의 작성만
/// 상태를 만들어 서버로 보냅니다.

class NoticeListViewModel extends BaseViewModel {
  NoticeListViewModel(this._getNotices);

  final GetNoticesUseCase _getNotices;

  List<Notice> _notices = const <Notice>[];
  List<Notice> get notices => _notices;

  Future<void> load() => guard(() async {
    _notices = await _getNotices();
  });
}

class NoticeDetailViewModel extends BaseViewModel {
  NoticeDetailViewModel(this._getNotice, this.noticeId);

  final GetNoticeUseCase _getNotice;
  final String noticeId;

  Notice? _notice;
  Notice? get notice => _notice;

  Future<void> load() => guard(() async {
    _notice = await _getNotice(noticeId);
  });
}

class GuideListViewModel extends BaseViewModel {
  GuideListViewModel(this._getGuides);

  final GetGuidesUseCase _getGuides;

  List<Guide> _guides = const <Guide>[];
  List<Guide> get guides => _guides;

  /// 분류별로 묶은 목록. 서버가 이미 (분류, 순서)로 정렬해 주므로 나누기만 합니다.
  Map<GuideCategory, List<Guide>> get grouped {
    final Map<GuideCategory, List<Guide>> map = <GuideCategory, List<Guide>>{};
    for (final Guide guide in _guides) {
      map.putIfAbsent(guide.category, () => <Guide>[]).add(guide);
    }
    return map;
  }

  Future<void> load() => guard(() async {
    _guides = await _getGuides();
  });
}

class InquiryListViewModel extends BaseViewModel {
  InquiryListViewModel(this._getInquiries);

  final GetInquiriesUseCase _getInquiries;

  List<Inquiry> _inquiries = const <Inquiry>[];
  List<Inquiry> get inquiries => _inquiries;

  Future<void> load() => guard(() async {
    _inquiries = await _getInquiries();
  });
}

class InquiryDetailViewModel extends BaseViewModel {
  InquiryDetailViewModel(this._getInquiry, this.inquiryId);

  final GetInquiryUseCase _getInquiry;
  final String inquiryId;

  Inquiry? _inquiry;
  Inquiry? get inquiry => _inquiry;

  Future<void> load() => guard(() async {
    _inquiry = await _getInquiry(inquiryId);
  });
}

class InquiryWriteViewModel extends BaseViewModel {
  InquiryWriteViewModel(this._createInquiry);

  final CreateInquiryUseCase _createInquiry;

  InquiryCategory _category = InquiryCategory.etc;
  bool _submitting = false;

  InquiryCategory get category => _category;
  bool get isSubmitting => _submitting;

  void changeCategory(InquiryCategory category) {
    _category = category;
    safeNotify();
  }

  /// @return 등록된 문의. 실패하면 null 이고 [errorMessage] 에 이유가 담깁니다.
  Future<Inquiry?> submit({
    required String title,
    required String content,
  }) async {
    _submitting = true;
    safeNotify();
    try {
      return await _createInquiry(
        category: _category,
        title: title,
        content: content,
      );
    } catch (e) {
      setError(e);
      return null;
    } finally {
      _submitting = false;
      safeNotify();
    }
  }
}

class NotificationListViewModel extends BaseViewModel {
  NotificationListViewModel({
    required GetNotificationsUseCase getNotifications,
    required MarkNotificationReadUseCase markRead,
    required MarkAllNotificationsReadUseCase markAllRead,
  }) : // 이름 있는 매개변수는 밑줄로 시작할 수 없어 초기화 형식 매개변수를 못 씁니다.
       // ignore: prefer_initializing_formals
       _getNotifications = getNotifications,
       // ignore: prefer_initializing_formals
       _markRead = markRead,
       // ignore: prefer_initializing_formals
       _markAllRead = markAllRead;

  final GetNotificationsUseCase _getNotifications;
  final MarkNotificationReadUseCase _markRead;
  final MarkAllNotificationsReadUseCase _markAllRead;

  List<AppNotification> _notifications = const <AppNotification>[];
  List<AppNotification> get notifications => _notifications;

  int get unreadCount =>
      _notifications.where((AppNotification n) => !n.read).length;

  Future<void> load() => guard(() async {
    _notifications = await _getNotifications();
  });

  /// 알림을 누르면 읽음으로 바꿉니다.
  ///
  /// 서버 응답을 기다리지 않고 화면부터 바꿉니다. 실패해도 다시 열면 서버 상태로
  /// 돌아가고, 읽음 표시가 한 박자 늦게 반영되면 이미 누른 알림이 계속 새 것처럼
  /// 보입니다.
  Future<void> markRead(AppNotification notification) async {
    if (notification.read) return;
    _notifications = _notifications
        .map(
          (AppNotification item) => item.id == notification.id
              ? AppNotification(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  body: item.body,
                  read: true,
                  linkPath: item.linkPath,
                  createdAt: item.createdAt,
                )
              : item,
        )
        .toList();
    safeNotify();
    try {
      await _markRead(notification.id);
    } catch (_) {
      // 화면은 그대로 둡니다. 다음에 목록을 열면 서버 상태로 맞춰집니다.
    }
  }

  Future<void> markAllRead() async {
    try {
      await _markAllRead();
      await load();
    } catch (e) {
      setError(e);
    }
  }
}
