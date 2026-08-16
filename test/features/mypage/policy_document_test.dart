import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/widgets/policy_document_view.dart';

/// 약관·정책 문서 시트.
///
/// 문서 본문은 `assets/policies/*.md` 에서 읽는다. 파일이 등록에서 빠지거나
/// 비면 시트가 "준비 중" 시절로 되돌아간 것처럼 보이므로, 세 문서 모두
/// 실제 조문이 화면에 뜨는지 확인한다.
void main() {
  Future<void> open(WidgetTester tester, String title, String asset) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PolicyDocumentView(title: title, assetPath: asset),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('서비스 이용약관은 제1조 본문을 보여준다', (WidgetTester tester) async {
    await open(tester, '서비스 이용약관', 'assets/policies/terms.md');

    expect(find.text('제1조 (목적)'), findsOneWidget);
    expect(find.textContaining('굿퀘스천 팀'), findsWidgets);
    expect(find.text('문서 내용은 준비 중입니다.'), findsNothing);
  });

  testWidgets('개인정보 처리방침은 수집 항목 표를 보여준다', (WidgetTester tester) async {
    await open(tester, '개인정보 처리방침', 'assets/policies/privacy.md');

    expect(find.textContaining('처리하는 개인정보의 항목과 목적'), findsOneWidget);
    // 표의 헤더 행이 실제 Table 로 그려졌는지 확인한다.
    expect(find.byType(Table), findsWidgets);
    expect(find.text('아동 등록'), findsOneWidget);
  });

  testWidgets('아동 개인정보 처리방침은 음성 미저장 조항을 보여준다', (WidgetTester tester) async {
    await open(tester, '아동 개인정보 처리방침', 'assets/policies/child_privacy.md');

    expect(find.textContaining('음성은 저장하지 않습니다'), findsOneWidget);
    expect(find.textContaining('법정대리인'), findsWidgets);
  });

  testWidgets('없는 문서 경로면 오류 안내를 보여준다', (WidgetTester tester) async {
    await open(tester, '없는 문서', 'assets/policies/none.md');

    expect(find.text('문서를 불러오지 못했어요.'), findsOneWidget);
  });
}
