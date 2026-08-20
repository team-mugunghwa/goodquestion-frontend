import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/text/korean_wrap.dart';

/// 화면에 그려진 한글을 찾습니다.
///
/// 아이에게 읽히는 글은 **어절 단위로만 줄이 바뀌게** 보이지 않는 이음 문자로
/// 묶여 있습니다(`korean_wrap.dart`). 그래서 `find.text('마을 이장')` 은
/// 아무것도 못 찾습니다 — 위젯이 들고 있는 문자열이 다르기 때문입니다.
///
/// 눈에 보이는 글자는 원문 그대로이므로, 테스트도 원문으로 찾게 두는 것이
/// 맞습니다. 이음 문자를 아는 건 이 함수 하나면 충분합니다.
Finder findKidText(String text) => find.text(text.keepWords);
