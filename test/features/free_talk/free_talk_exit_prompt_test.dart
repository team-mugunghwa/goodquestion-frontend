import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/features/free_talk/presentation/widgets/free_talk_farewell.dart';

/// 종료 확인 카드의 **라벨이 잘리지 않는지**를 재는 테스트.
///
/// 이 카드의 버튼 셋은 [KidPrimaryButton]/[KidSecondaryButton] 이고, 그 안의
/// Text 는 `maxLines: 1` + `TextOverflow.ellipsis` 다. 넘쳐도 예외가 나지 않고
/// **조용히 "인사하고 나…" 로 줄어든다** — 눈으로 보고 넘어가면 못 잡는다.
/// 그래서 렌더된 문단에 직접 물어본다.
///
/// 나가는 두 갈래를 가르는 말은 머리(`인사하고` / `바로`)에 있어서 꼬리가 잘려도
/// 뜻이 통째로 사라지지는 않지만, 아이 화면에서 말줄임표는 그 자체로 읽기 비용이다.
void main() {
  /// 화면에 보이는 모든 문단 중 **잘린 것**의 글을 모은다.
  List<String> truncatedLabels(WidgetTester tester) {
    final List<String> cut = <String>[];
    for (final Element element in find.byType(Text).evaluate()) {
      final RenderObject? render = element.renderObject;
      if (render is RenderParagraph && render.didExceedMaxLines) {
        cut.add((element.widget as Text).data ?? '(null)');
      }
    }
    return cut;
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: FreeTalkExitPrompt(
            onKeep: () {},
            onFarewell: () {},
            onLeaveNow: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('세 갈래가 모두 보인다', (WidgetTester tester) async {
    await pumpCard(tester, size: const Size(390, 844));

    expect(find.text(FreeTalkStrings.exitKeep), findsOneWidget);
    expect(find.text(FreeTalkStrings.exitFarewell), findsOneWidget);
    expect(find.text(FreeTalkStrings.exitLeave), findsOneWidget);
  });

  // 아래 셋이 이 테스트의 본론이다. 폭·글자확대의 조합마다 따로 잰다 -
  // 하나로 묶으면 어느 조합에서 깨졌는지 실패 메시지만 보고는 알 수 없다.

  testWidgets('보통 폰(390dp)에서 라벨이 잘리지 않는다', (WidgetTester tester) async {
    await pumpCard(tester, size: const Size(390, 844));

    expect(truncatedLabels(tester), isEmpty);
  });

  testWidgets('작은 폰(320dp)에서 라벨이 잘리지 않는다', (WidgetTester tester) async {
    // 320dp 는 카드가 화면에 눌려 라벨 상자가 가장 좁아지는 자리다.
    // 카드 여백을 좁은 화면에서 줄이는 처리가 없으면 여기서 잘린다.
    await pumpCard(tester, size: const Size(320, 480));

    expect(truncatedLabels(tester), isEmpty);
  });

  testWidgets('글자를 1.3배로 키워도(390dp) 라벨이 잘리지 않는다', (WidgetTester tester) async {
    // 기기 글자 확대는 실제로 켜고 쓰는 설정이다. 폭에 맞춘 라벨 스타일을
    // 넘기지 않으면 여기서 잘린다.
    await pumpCard(tester, size: const Size(390, 844), textScale: 1.3);

    expect(truncatedLabels(tester), isEmpty);
  });

  /// 대조군. 위 세 건이 "아무것도 안 재고 통과"하는 것이 아님을 못박는다 —
  /// 라벨을 억지로 길게 만들면 잘림이 **실제로 검출되어야** 한다.
  testWidgets('대조군 — 라벨이 길어지면 잘림이 잡힌다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 128,
            child: Text(
              '아주 아주 아주 긴 라벨입니다',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(truncatedLabels(tester), isNotEmpty);
  });
}
