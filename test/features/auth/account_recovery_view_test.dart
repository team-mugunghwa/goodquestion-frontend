import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/auth/presentation/views/account_recovery_view.dart';

void main() {
  Future<void> pump(WidgetTester tester, AccountRecoveryMode mode) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountRecoveryPage(
          mode: mode,
          requestPasswordReset: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ID 찾기는 보호자 이름과 생년월일을 받는다', (WidgetTester tester) async {
    await pump(tester, AccountRecoveryMode.findId);

    expect(find.text(AuthRecoveryStrings.findIdTitle), findsOneWidget);
    expect(find.text(AuthRecoveryStrings.guardianName), findsOneWidget);
    expect(find.text(AuthRecoveryStrings.birthDate), findsOneWidget);

    await tester.tap(find.text(AuthRecoveryStrings.findIdAction));
    await tester.pump();
    expect(find.text(AuthRecoveryStrings.requiredFields), findsOneWidget);
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
