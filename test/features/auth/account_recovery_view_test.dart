import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/auth/presentation/views/account_recovery_view.dart';

void main() {
  /// 마지막으로 서버에 간 값. 화면이 무엇을 보냈는지 봅니다.
  Map<String, Object?>? sent;

  Future<void> pump(
    WidgetTester tester,
    AccountRecoveryMode mode, {
    List<String> emails = const <String>['de***@goodquestion.kr'],
  }) async {
    sent = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountRecoveryPage(
          mode: mode,
          requestPasswordReset: (_) async {},
          findEmails:
              ({
                required String parentName,
                String? childName,
                int? childAge,
              }) async {
                sent = <String, Object?>{
                  'parentName': parentName,
                  'childName': childName,
                  'childAge': childAge,
                };
                return emails;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// ID 찾기 폼을 채웁니다. 필드 순서: 보호자 이름 · 아이 이름 · 나이.
  Future<void> fillFindId(
    WidgetTester tester, {
    String parentName = '김보호',
    String childName = '지우',
    String childAge = '8',
  }) async {
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), parentName);
    await tester.enterText(fields.at(1), childName);
    await tester.enterText(fields.at(2), childAge);
  }

  testWidgets('ID 찾기는 보호자 이름과 아이 이름·나이를 받는다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.findId);

    expect(find.text(AuthRecoveryStrings.findIdTitle), findsOneWidget);
    expect(find.text(AuthRecoveryStrings.guardianName), findsOneWidget);
    expect(find.text(AuthRecoveryStrings.childName), findsOneWidget);
    // 아이 등록과 같은 기준(나이)입니다. 두 화면에서 다른 값을 다루게 하면
    // 변환이 어긋나 못 찾습니다.
    expect(find.text(AuthRecoveryStrings.childAge), findsOneWidget);
    expect(find.text('보호자 생년월일'), findsNothing);
    expect(find.text('아이 출생연도'), findsNothing);

    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pump();
    expect(find.text(AuthRecoveryStrings.requiredFields), findsOneWidget);
    expect(sent, isNull, reason: '보낼 수 없는 요청은 보내지 않습니다');
  });

  testWidgets('아이 정보를 비우면 보내지 않고 먼저 안내한다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.findId);

    // 아이 정보가 하나라도 비면 서버는 아이가 등록된 계정을 결과에서 뺍니다
    // - 실사용자는 전원 아이가 있으니 사실상 항상 빈 결과입니다.
    await fillFindId(tester, childName: '', childAge: '');
    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pump();

    expect(find.text(AuthRecoveryStrings.requiredFields), findsOneWidget);
    expect(sent, isNull);
    // 왜 필요한지 화면에 늘 적혀 있어야 합니다.
    expect(find.text(AuthRecoveryStrings.childInfoNotice), findsOneWidget);
  });

  testWidgets('나이는 숫자로만 받는다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.findId);

    // 출생연도를 넣던 화면이라 2018 같은 값을 그대로 적을 수 있습니다.
    await fillFindId(tester, childAge: '2018');
    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pump();
    expect(find.text(AuthRecoveryStrings.invalidChildAge), findsOneWidget);
    expect(sent, isNull);

    await fillFindId(tester, childAge: '여덟');
    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pump();
    expect(find.text(AuthRecoveryStrings.invalidChildAge), findsOneWidget);
    expect(sent, isNull);
  });

  testWidgets('찾으면 서버가 가려 준 이메일을 그대로 보여준다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.findId);

    await fillFindId(tester);
    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pumpAndSettle();

    expect(sent, <String, Object?>{
      'parentName': '김보호',
      'childName': '지우',
      'childAge': 8,
    });
    expect(find.text(AuthRecoveryStrings.findIdDoneTitle), findsOneWidget);
    // 마스킹은 서버가 합니다 - 화면에서 또 가리지 않습니다.
    expect(find.text('de***@goodquestion.kr'), findsOneWidget);
  });

  testWidgets('여러 개가 오면 모두 보여준다', (WidgetTester tester) async {
    await pump(
      tester,
      AccountRecoveryMode.findId,
      emails: const <String>['de***@goodquestion.kr', 'mi***@example.com'],
    );

    await fillFindId(tester);
    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pumpAndSettle();

    // 형제가 있거나 동명이인이면 여러 개가 옵니다.
    expect(find.text('de***@goodquestion.kr'), findsOneWidget);
    expect(find.text('mi***@example.com'), findsOneWidget);
  });

  testWidgets('못 찾아도 오류 화면이 아니라 안내다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.findId, emails: const <String>[]);

    await fillFindId(tester);
    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pumpAndSettle();

    // 서버도 404 가 아니라 200 + 빈 목록을 줍니다.
    expect(find.text(AuthRecoveryStrings.findIdEmptyTitle), findsOneWidget);
    expect(find.text(AuthRecoveryStrings.requestFailed), findsNothing);

    // 다시 입력할 통로가 있어야 합니다. 보낸 것이 없으니 "다시 보내기"가
    // 아니라 "다시 찾기" 입니다.
    await tester.tap(find.text(AuthRecoveryStrings.findIdRetry));
    await tester.pumpAndSettle();
    expect(find.text(AuthRecoveryStrings.findIdAction), findsOneWidget);
  });

  testWidgets('ID 찾기의 하단 안내는 PW 찾기 문구를 쓰지 않는다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.findId);

    // "가입 여부와 관계없이 같은 안내"는 결과가 갈리는 이 화면의 말이 아닙니다.
    expect(find.text(AuthRecoveryStrings.securityNotice), findsNothing);
  });

  testWidgets('PW 찾기는 이메일 검증 후 발송 완료 상태를 보여준다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.resetPassword);

    await tester.enterText(find.byType(TextField), 'parent@example.com');
    await tester.tap(find.text(AuthRecoveryStrings.resetAction));
    await tester.pumpAndSettle();

    expect(find.text(AuthRecoveryStrings.resetDoneTitle), findsOneWidget);
    expect(find.text(AuthRecoveryStrings.backToLogin), findsWidgets);
  });
}
