import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/theme/app_colors.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/confirm_actions.dart';

/// 확인 다이얼로그의 두 선택지가 **대등하게** 보이는지.
///
/// 기본 actions 는 취소를 작은 텍스트 버튼으로 흘려 두고 확인만 채워진
/// 버튼으로 강조합니다 - 되돌리기 어려운 동작에서 그 기울기가 위험합니다.
void main() {
  Future<void> pumpActions(
    WidgetTester tester, {
    bool danger = false,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ConfirmActions(
                cancelLabel: '취소',
                confirmLabel: '로그아웃',
                danger: danger,
                onCancel: onCancel ?? () {},
                onConfirm: onConfirm ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('취소와 확인이 같은 너비로 한 줄에 놓인다', (WidgetTester tester) async {
    await pumpActions(tester);

    final Size cancel = tester.getSize(find.byType(OutlinedButton));
    final Size confirm = tester.getSize(find.byType(FilledButton));
    expect(cancel.width, confirm.width, reason: '한쪽이 넓으면 그쪽으로 기웁니다');
    expect(
      tester.getTopLeft(find.byType(OutlinedButton)).dy,
      tester.getTopLeft(find.byType(FilledButton)).dy,
      reason: '취소가 위나 아래로 흩어지면 "잘못 놓인 것"처럼 보입니다',
    );
    // 취소도 테두리를 가진 버튼입니다 - 텍스트만 떠 있으면 눌러도 되는지
    // 아이가 아닌 보호자조차 잠깐 헷갈립니다.
    expect(find.widgetWithText(OutlinedButton, '취소'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '로그아웃'), findsOneWidget);
  });

  testWidgets('누르면 각각의 콜백이 불린다', (WidgetTester tester) async {
    int cancels = 0;
    int confirms = 0;
    await pumpActions(
      tester,
      onCancel: () => cancels++,
      onConfirm: () => confirms++,
    );

    await tester.tap(find.text('취소'));
    await tester.tap(find.text('로그아웃'));
    await tester.pump();

    expect(cancels, 1);
    expect(confirms, 1);
  });

  testWidgets('되돌릴 수 없는 동작은 확인 버튼이 경고색이다', (WidgetTester tester) async {
    await pumpActions(tester, danger: true);

    final Material confirm = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(confirm.color, AppColors.danger);
  });
}
