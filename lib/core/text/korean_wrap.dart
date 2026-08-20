/// 한글을 **어절 단위로** 줄바꿈하게 만듭니다.
///
/// ## 왜 필요한가
///
/// Flutter 는 유니코드 줄바꿈 규칙(UAX #14)을 그대로 따릅니다. 한글 음절은
/// `ID`(Ideographic) 계열이라 **글자 사이 어디서든 끊깁니다** — 중국어·일본어에
/// 맞는 규칙인데 한글에도 그대로 걸립니다. 그래서 이런 줄이 나옵니다.
///
/// ```
/// "마을 사람들의 고민을 들
///  어주는 아이"야!
/// ```
///
/// 초1~3 은 읽기를 막 뗀 아이들입니다. 어절이 두 줄에 걸쳐 쪼개지면 눈이
/// 한 번 멈추고, 그 자리에서 읽기를 포기합니다. 이 앱에서 글은 대부분
/// **아이에게 읽히려고** 있는 것이라 그냥 둘 수 없습니다.
///
/// ## 어떻게
///
/// 어절 안의 글자들을 `U+2060 WORD JOINER` 로 묶습니다. 보이지 않는 문자이고
/// 폭도 0 이라 화면에는 아무 흔적이 없지만, 줄바꿈 알고리즘은 그 사이를 끊지
/// 못합니다. 결과적으로 **띄어쓰기에서만** 줄이 바뀝니다.
///
/// 텍스트를 다루는 다른 방법(직접 줄바꿈 계산, 어절별 위젯)은 폰트 크기·
/// 글자 확대 설정이 바뀔 때마다 어긋납니다. 이건 문자열만 바꾸므로 레이아웃
/// 계산은 Flutter 가 그대로 합니다.
library;

/// 어절 하나를 통째로 묶을 최대 길이.
///
/// 이보다 긴 덩어리는 **일부러 안 묶습니다.** 좁은 폰에서 한 줄에 안 들어가는
/// 어절까지 묶어 버리면 줄이 안 바뀌는 대신 글자가 상자 밖으로 넘칩니다.
/// 그때는 어절 중간에서 끊기는 편이 낫습니다 — 안 보이는 것보다는 낫습니다.
///
/// 12 는 가장 좁은 자리(폰 390dp 의 역할 카드) 기준입니다. 한글 24sp 로
/// 12 글자면 약 290dp 라 카드 안쪽 폭에 들어갑니다.
const int _maxJoinedWord = 12;

/// 보이지 않는 이음 문자(U+2060 WORD JOINER). 폭이 0 이고 그려지지 않지만
/// 줄바꿈 알고리즘이 이 자리를 끊지 못합니다. `\u200B`(ZERO WIDTH SPACE)는
/// 반대로 **끊을 수 있는** 자리라 여기 쓰면 안 됩니다.
const String _wordJoiner = '\u2060';

extension KoreanWrap on String {
  /// 어절 중간에서 줄이 바뀌지 않게 묶은 문자열.
  ///
  /// ```dart
  /// Text('마을 사람들의 고민을 들어주는 아이'.keepWords)
  /// ```
  ///
  /// 줄바꿈(`\n`)과 띄어쓰기는 그대로 둡니다 — 원문이 정한 줄바꿈은 지킵니다.
  String get keepWords {
    if (isEmpty) return this;
    final StringBuffer out = StringBuffer();
    final StringBuffer word = StringBuffer();

    void flush() {
      if (word.isEmpty) return;
      final String text = word.toString();
      final List<String> glyphs = <String>[
        for (final int rune in text.runes) String.fromCharCode(rune),
      ];
      out.write(
        glyphs.length <= _maxJoinedWord ? glyphs.join(_wordJoiner) : text,
      );
      word.clear();
    }

    for (final int rune in runes) {
      final String char = String.fromCharCode(rune);
      // 띄어쓰기·줄바꿈이 어절의 경계입니다.
      if (char == ' ' || char == '\n' || char == '\t') {
        flush();
        out.write(char);
      } else {
        word.write(char);
      }
    }
    flush();
    return out.toString();
  }
}
