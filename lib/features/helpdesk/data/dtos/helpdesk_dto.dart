/// 서버 JSON 을 Entity 로 옮깁니다.
///
/// 서버 필드명이 바뀌어도 `toEntity()` 한 곳만 고치면 화면 코드는 그대로입니다.
library;

import '../../domain/entities/helpdesk.dart';

class NoticeDto {
  const NoticeDto({
    required this.id,
    required this.title,
    required this.category,
    required this.pinned,
    this.content,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String category;
  final bool pinned;
  final String? content;
  final String? publishedAt;

  factory NoticeDto.fromJson(Map<String, dynamic> json) => NoticeDto(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    pinned: json['pinned'] as bool? ?? false,
    content: json['content'] as String?,
    publishedAt: json['publishedAt'] as String?,
  );

  Notice toEntity() => Notice(
    id: id,
    title: title,
    category: NoticeCategory.fromCode(category),
    pinned: pinned,
    content: content,
    publishedAt: DateTime.tryParse(publishedAt ?? '')?.toLocal(),
  );
}

class GuideDto {
  const GuideDto({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
  });

  final String id;
  final String category;
  final String title;
  final String content;

  factory GuideDto.fromJson(Map<String, dynamic> json) => GuideDto(
    id: json['id'] as String,
    category: json['category'] as String? ?? '',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
  );

  Guide toEntity() => Guide(
    id: id,
    category: GuideCategory.fromCode(category),
    title: title,
    content: content,
  );
}

class InquiryDto {
  const InquiryDto({
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
  final String category;
  final String title;
  final String status;
  final bool answered;
  final String? content;
  final String? createdAt;
  final Map<String, dynamic>? answer;

  factory InquiryDto.fromJson(Map<String, dynamic> json) {
    final answer = json['answer'];
    return InquiryDto(
      id: json['id'] as String,
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      // 목록에는 answered 가 오고 상세에는 answer 객체가 옵니다.
      answered: json['answered'] as bool? ?? answer != null,
      content: json['content'] as String?,
      createdAt: json['createdAt'] as String?,
      answer: answer is Map<String, dynamic> ? answer : null,
    );
  }

  Inquiry toEntity() => Inquiry(
    id: id,
    category: InquiryCategory.fromCode(category),
    title: title,
    status: InquiryStatus.fromCode(status),
    answered: answered,
    content: content,
    createdAt: DateTime.tryParse(createdAt ?? '')?.toLocal(),
    answer: answer == null
        ? null
        : InquiryAnswer(
            adminName: answer!['adminName'] as String? ?? '고객센터',
            content: answer!['content'] as String? ?? '',
            answeredAt: DateTime.tryParse(
              answer!['answeredAt'] as String? ?? '',
            )?.toLocal(),
          ),
  );
}

class NotificationListDto {
  const NotificationListDto({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;

  factory NotificationListDto.fromJson(Map<String, dynamic> json) {
    final raw = json['notifications'];
    return NotificationListDto(
      notifications: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => AppNotification(
                    id: item['id'] as String,
                    type: NotificationType.fromCode(item['type'] as String?),
                    title: item['title'] as String? ?? '',
                    body: item['body'] as String? ?? '',
                    read: item['read'] as bool? ?? false,
                    linkPath: item['linkPath'] as String?,
                    createdAt: DateTime.tryParse(
                      item['createdAt'] as String? ?? '',
                    )?.toLocal(),
                  ),
                )
                .toList()
          : const [],
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
