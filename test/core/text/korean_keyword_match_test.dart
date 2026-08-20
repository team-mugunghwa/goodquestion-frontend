import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/text/korean_keyword_match.dart';

/// 체크 표시는 **격려 장식이지 판정이 아닙니다.** 안 켜져도 활동을 막지
/// 않으므로 미탐보다 오탐이 훨씬 나쁩니다 — 아래 테이블은 대부분
/// "이 낱말이 아닌데 걸리면 안 된다"는 오탐 방지 케이스입니다.
void main() {
  group('containsKeyword - 용언(다로 끝나는 낱말)', () {
    final List<({String keyword, String utterance, bool expected, String why})>
    cases = <({String keyword, String utterance, bool expected, String why})>[
      (
        keyword: '참다',
        utterance: '며느리가 방귀를 참았어요',
        expected: true,
        why: '받침 있는 어간 + 모음 어미(참+았)',
      ),
      (
        keyword: '참다',
        utterance: '참고 있었어요',
        expected: true,
        why: '어간 그대로 + 자음 어미(고)',
      ),
      (
        keyword: '참다',
        utterance: '참느라 힘들었어요',
        expected: true,
        why: '어간 그대로 + 자음 어미(느라)',
      ),
      (
        keyword: '참다',
        utterance: '방귀를 참을 수가 없었어요',
        expected: true,
        why: '어간 그대로 + 자음 어미(을)',
      ),
      (
        keyword: '참다',
        utterance: '참새가 날아갔어요',
        expected: false,
        why: '1음절 어간 오탐 방지 - "참" 다음이 어미 시작이 아님',
      ),
      (
        keyword: '참다',
        utterance: '찾았어요',
        expected: false,
        why: '종성 불일치(ㅁ≠ㅈ) - 종성 규칙이 막아야 하는 버그',
      ),
      (
        keyword: '참다',
        utterance: '창고에 갔어요',
        expected: false,
        why: '종성 불일치(ㅁ≠ㅇ)',
      ),
      (
        keyword: '쫓겨나다',
        utterance: '쫓겨났어요',
        expected: true,
        why: '받침 없는 어간 + 모음 어미 융합(나+았→났)',
      ),
      (
        keyword: '떨어뜨리다',
        utterance: '떨어뜨렸어요',
        expected: true,
        why: '중성 축약(ㅣ→ㅕ) + 종성 융합(리+었→렸)',
      ),
      (
        keyword: '고마워하다',
        utterance: '고마워했어요',
        expected: true,
        why: '하다 특례(ㅏ→ㅐ)만 허용, 축약표 전체가 아님',
      ),
      (
        keyword: '가다',
        utterance: '개는 멍멍 짖어요',
        expected: false,
        why: '하다 특례가 "하" 밖으로 새면 안 됨(가+ㅐ는 허용 안 함)',
      ),
    ];

    for (final (
          keyword: String keyword,
          utterance: String utterance,
          expected: bool expected,
          why: String why,
        )
        in cases) {
      test('$keyword × "$utterance" → $expected ($why)', () {
        expect(containsKeyword(utterance, keyword), expected);
      });
    }
  });

  group('containsKeyword - 체언(다로 안 끝나는 낱말)', () {
    test('부분문자열로 포함되어 있으면 매칭된다', () {
      expect(containsKeyword('자신감이 생겼어요', '자신감'), isTrue);
    });

    test('안 쓰인 체언은 매칭되지 않는다', () {
      expect(containsKeyword('오늘은 참 즐거웠어요', '자신감'), isFalse);
    });
  });

  group('containsKeyword - aliases', () {
    test('불규칙 용언은 규칙으로 못 잡으므로 aliases로 잡는다', () {
      // "듣다"는 규칙 활용이 아니라 "들어"로 어간이 바뀌는 불규칙 용언.
      expect(
        containsKeyword('이야기를 잘 들어줬어요', '듣다', aliases: <String>['들어']),
        isTrue,
      );
    });

    test('alias가 하나도 안 걸리고 본체도 안 걸리면 false', () {
      expect(
        containsKeyword('그냥 놀았어요', '듣다', aliases: <String>['들어']),
        isFalse,
      );
    });
  });

  group('containsKeyword - 방어적 입력', () {
    test('빈 발화는 죽지 않고 false', () {
      expect(containsKeyword('', '참다'), isFalse);
    });

    test('빈 낱말은 죽지 않고 false', () {
      expect(containsKeyword('참았어요', ''), isFalse);
    });

    test('낱말이 "다" 한 글자여도 죽지 않는다', () {
      expect(containsKeyword('다 같이 놀았어요', '다'), isTrue);
      expect(containsKeyword('아무것도 없어요', '다'), isFalse);
    });

    test('한글이 아닌 입력에서도 죽지 않는다', () {
      expect(containsKeyword('hello world 123', '참다'), isFalse);
      expect(containsKeyword('참았어요 hello', 'hello'), isTrue);
    });

    test('공백·문장부호가 섞여 있어도 정규화 후 매칭된다', () {
      expect(containsKeyword('며느리가, 방귀를... 참았어요!', '참다'), isTrue);
    });
  });

  group('matchedKeywords', () {
    test('여러 낱말 중 실제로 맞은 것만 골라 돌려준다', () {
      final Set<String> result = matchedKeywords('며느리가 방귀를 참았어요', <String>[
        '참다',
        '자신감',
        '고마워하다',
      ]);
      expect(result, <String>{'참다'});
    });

    test('아무것도 안 맞으면 빈 집합', () {
      expect(matchedKeywords('오늘 날씨가 좋아요', <String>['참다', '자신감']), isEmpty);
    });
  });
}
