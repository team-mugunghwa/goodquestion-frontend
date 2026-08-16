import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/di/injector.dart';
import 'package:goodquestion/features/helpdesk/domain/entities/helpdesk.dart';
import 'package:goodquestion/features/helpdesk/domain/repositories/helpdesk_repository.dart';
import 'package:goodquestion/features/helpdesk/domain/usecases/helpdesk_use_cases.dart';
import 'package:goodquestion/features/helpdesk/presentation/views/inquiry_detail_view.dart';
import 'package:goodquestion/features/helpdesk/presentation/views/inquiry_write_view.dart';

/// 문의 수정/삭제.
///
/// 답변 전(PENDING) 문의만 고칠 수 있다 - 답변이 달린 문의의 내용이 바뀌면
/// 답변이 무엇에 대한 것인지 어긋난다(서버도 409로 막는다). 화면은 그 규칙을
/// 버튼 노출로 표현한다.
void main() {
  late _FakeHelpdeskRepository repository;

  Inquiry inquiry({
    InquiryStatus status = InquiryStatus.pending,
    InquiryAnswer? answer,
  }) => Inquiry(
    id: 'inq-1',
    category: InquiryCategory.etc,
    title: '소리가 안 나요',
    content: '이야기 소리가 들리지 않아요.',
    status: status,
    answered: answer != null,
    createdAt: DateTime(2026, 8, 16),
    answer: answer,
  );

  setUp(() async {
    await getIt.reset();
    repository = _FakeHelpdeskRepository();
    getIt
      ..registerLazySingleton<HelpdeskRepository>(() => repository)
      ..registerLazySingleton<GetInquiryUseCase>(
        () => GetInquiryUseCase(getIt<HelpdeskRepository>()),
      )
      ..registerLazySingleton<CreateInquiryUseCase>(
        () => CreateInquiryUseCase(getIt<HelpdeskRepository>()),
      )
      ..registerLazySingleton<UpdateInquiryUseCase>(
        () => UpdateInquiryUseCase(getIt<HelpdeskRepository>()),
      )
      ..registerLazySingleton<DeleteInquiryUseCase>(
        () => DeleteInquiryUseCase(getIt<HelpdeskRepository>()),
      );
  });

  Future<void> openDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: InquiryDetailPage(inquiryId: 'inq-1')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('답변 전 문의에는 수정/삭제 버튼이 보인다', (WidgetTester tester) async {
    repository.detail = inquiry();
    await openDetail(tester);

    expect(find.text('수정하기'), findsOneWidget);
    expect(find.text('삭제하기'), findsOneWidget);
  });

  testWidgets('답변된 문의에는 수정/삭제 버튼이 없다', (WidgetTester tester) async {
    repository.detail = inquiry(
      status: InquiryStatus.answered,
      answer: const InquiryAnswer(
        adminName: '고객센터',
        content: '기기 볼륨을 확인해 주세요.',
      ),
    );
    await openDetail(tester);

    expect(find.text('수정하기'), findsNothing);
    expect(find.text('삭제하기'), findsNothing);
    expect(find.textContaining('기기 볼륨'), findsOneWidget);
  });

  testWidgets('삭제하기는 확인을 거쳐 저장소 삭제를 부른다', (WidgetTester tester) async {
    repository.detail = inquiry();
    await openDetail(tester);

    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    expect(find.text('문의를 삭제할까요?'), findsOneWidget);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, <String>['inq-1']);
  });

  testWidgets('삭제 확인에서 취소하면 아무 일도 없다', (WidgetTester tester) async {
    repository.detail = inquiry();
    await openDetail(tester);

    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, isEmpty);
    expect(find.text('수정하기'), findsOneWidget, reason: '상세 화면이 그대로여야 합니다');
  });

  testWidgets('수정 모드는 기존 내용을 채워 열고 PATCH 로 저장한다', (WidgetTester tester) async {
    final Inquiry target = inquiry();
    await tester.pumpWidget(
      MaterialApp(home: InquiryWritePage(initial: target)),
    );
    await tester.pumpAndSettle();

    // 기존 내용이 채워져 있고 제목이 수정 모드다.
    expect(find.text('문의 수정'), findsOneWidget);
    expect(find.text('소리가 안 나요'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '소리가 안 나요 (수정)');
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();

    expect(repository.updatedIds, <String>['inq-1']);
    expect(repository.lastUpdateTitle, '소리가 안 나요 (수정)');
  });
}

class _FakeHelpdeskRepository implements HelpdeskRepository {
  Inquiry? detail;
  final List<String> deletedIds = <String>[];
  final List<String> updatedIds = <String>[];
  String? lastUpdateTitle;

  @override
  Future<Inquiry> getInquiry(String inquiryId) async => detail!;

  @override
  Future<Inquiry> updateInquiry(
    String inquiryId, {
    required InquiryCategory category,
    required String title,
    required String content,
  }) async {
    updatedIds.add(inquiryId);
    lastUpdateTitle = title;
    return detail!;
  }

  @override
  Future<void> deleteInquiry(String inquiryId) async {
    deletedIds.add(inquiryId);
  }

  @override
  Future<Inquiry> createInquiry({
    required InquiryCategory category,
    required String title,
    required String content,
  }) async => detail!;

  @override
  Future<List<Inquiry>> getInquiries() async => <Inquiry>[];

  @override
  Future<List<Notice>> getNotices() async => <Notice>[];

  @override
  Future<Notice> getNotice(String noticeId) async => throw UnimplementedError();

  @override
  Future<List<Guide>> getGuides() async => <Guide>[];

  @override
  Future<List<AppNotification>> getNotifications() async => <AppNotification>[];

  @override
  Future<int> getUnreadNotificationCount() async => 0;

  @override
  Future<void> markNotificationRead(String notificationId) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {}

  @override
  Future<void> unregisterDevice(String token) async {}
}
