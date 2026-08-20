import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/text/korean_wrap.dart';

/// 한글은 유니코드 규칙상 **글자 사이 어디서든** 줄이 바뀝니다. 읽기를 막 뗀
/// 아이에게 "고민을 들 / 어주는 아이"는 다시 읽어야 하는 줄입니다.
void main() {
  const String joiner = '\u2060';

  group('keepWords', () {
    test('어절 안을 이음 문자로 묶는다', () {
      expect('마을 이장'.keepWords, '마$joiner을 이$joiner장');
    });

    test('띄어쓰기와 줄바꿈은 그대로 둔다', () {
      // 원문이 정한 줄바꿈은 지킵니다 - 도입문은 문장마다 줄을 나눠 옵니다.
      final String wrapped = '가나 다라\n마바'.keepWords;
      expect(wrapped.contains(' '), isTrue);
      expect(wrapped.contains('\n'), isTrue);
      expect(wrapped.replaceAll(joiner, ''), '가나 다라\n마바');
    });

    test('빈 문자열은 그대로', () {
      expect(''.keepWords, '');
    });

    test('한 줄에 안 들어갈 만큼 긴 덩어리는 안 묶는다', () {
      // 묶어 버리면 줄이 안 바뀌는 대신 글자가 상자 밖으로 넘칩니다.
      const String long = '가나다라마바사아자차카타파하';
      expect(long.keepWords, long);
    });

    test('보이는 글자는 하나도 안 바뀐다', () {
      const String text = '마을 사람들의 고민을 들어주는 아이';
      expect(text.keepWords.replaceAll(joiner, ''), text);
    });
  });

  testWidgets('묶은 글은 어절 중간에서 줄이 바뀌지 않는다', (WidgetTester tester) async {
    // "고민을" 이 한 줄에 못 들어갈 만큼 좁은 상자에 넣습니다.
    Future<int> linesOf(String text) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 92,
              child: Text(text, key: key, style: const TextStyle(fontSize: 20)),
            ),
          ),
        ),
      );
      final RenderBox box =
          key.currentContext!.findRenderObject()! as RenderBox;
      return (box.size.height / 20).round();
    }

    const String text = '아이 고민을 들어주는';
    final int plain = await linesOf(text);
    final int kept = await linesOf(text.keepWords);

    // 묶으면 줄 수가 늘어납니다 - 끊을 자리가 띄어쓰기밖에 없기 때문입니다.
    // 늘어난 줄 수가 곧 "어절이 안 쪼개졌다"는 증거입니다.
    expect(kept, greaterThanOrEqualTo(plain));
    expect(kept, 3);
  });
}
