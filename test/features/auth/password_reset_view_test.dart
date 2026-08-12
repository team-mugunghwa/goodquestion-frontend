import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/features/auth/presentation/views/password_reset_view.dart';

void main() {
  testWidgets('일치하는 새 비밀번호를 서버에 전달하고 완료 상태를 표시한다', (WidgetTester tester) async {
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetPage(
          token: 'reset-token',
          confirmPasswordReset: (String token, String password) async {
            expect(token, 'reset-token');
            submittedPassword = password;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'new-password');
    await tester.enterText(find.byType(TextField).at(1), 'new-password');
    await tester.tap(find.text(AuthRecoveryStrings.changePassword));
    await tester.pumpAndSettle();

    expect(submittedPassword, 'new-password');
    expect(find.text(AuthRecoveryStrings.passwordChanged), findsOneWidget);
  });
}
