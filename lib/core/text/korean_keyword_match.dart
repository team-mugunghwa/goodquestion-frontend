/// 발화 속 핵심 낱말 매칭.
///
/// 말하기 후 활동에서 아이가 장면을 설명한 발화에 그 장면의 핵심 낱말이
/// 쓰였는지 판정해 체크 표시를 켭니다. **이건 pass/fail 판정이 아니라
/// 격려 장식입니다** — 체크가 안 켜져도 활동은 그대로 진행되고 완료를
/// 막지 않습니다. 그래서 미탐(false negative)보다 **오탐(false positive)이
/// 훨씬 나쁩니다.** 안 쓴 낱말에 체크가 켜지면 "말했다고 인정받았는데
/// 사실 안 했다"는 잘못된 신호를 아이와 부모 모두에게 줍니다. 규칙을
/// 넓히고 싶어질 때마다 이 우선순위를 기억하세요 — 애매하면 매칭시키지
/// 않는 쪽을 고릅니다.
///
/// 낱말이 활용되는 방식이 둘로 갈립니다.
///
/// - **체언**(자신감, 방귀 등): 형태가 안 바뀌므로 부분문자열 포함이면
///   충분합니다.
/// - **용언**(참다, 쫓겨나다 등): "참다"는 발화에서 "참았어요", "참고",
///   "참느라"처럼 어미가 붙어 나타나므로 어간과 어미의 결합 규칙을
///   압니다. 특히 **종성(받침)을 무시하면 오탐이 납니다** — "참다"의
///   어간 "참"(종성 ㅁ)이 종성을 안 보면 "찾았어요"(종성 ㅈ), "창고에"
///   (종성 ㅇ)에도 걸립니다. 이 파일에서 종성 규칙이 가장 중요한
///   이유입니다.
///
/// 불규칙 용언(듣다→들어, 굽다→구워처럼 어간 자체가 바뀌는 것)은 규칙으로
/// 다루지 않습니다. 활용형이 규칙을 벗어나는 걸 규칙으로 쫓아가려 하면
/// 오탐 쪽으로 규칙이 계속 넓어지기 때문입니다. 대신 [containsKeyword]의
/// `aliases`가 그 자리입니다 — 백엔드가 활용형 목록을 주면 그대로
/// 꽂습니다.
library;

/// 한글 음절(가~힣) 코드 시작값. 이 범위 밖 문자는 초성/중성/종성으로
/// 분해할 수 없습니다.
const int _hangulBase = 0xAC00;
const int _hangulLast = 0xD7A3;

/// 중성 21개 × 종성 28개.
const int _jongCount = 28;
const int _jungTimesJong = 21 * _jongCount; // 588

/// 종성 인덱스. 0은 "받침 없음".
const int _jongNone = 0;
const int _jongN = 4; // ㄴ
const int _jongL = 8; // ㄹ
const int _jongSs = 20; // ㅆ

/// 중성 인덱스(표준 순서: 아 애 야 얘 어 에 여 예 오 와 왜 외 요 우 워 웨
/// 위 유 으 의 이 → 0~20).
const int _jungA = 0; // ㅏ
const int _jungAe = 1; // ㅐ
const int _jungEo = 4; // ㅓ
const int _jungYeo = 6; // ㅕ
const int _jungO = 8; // ㅗ
const int _jungWa = 9; // ㅘ
const int _jungWae = 10; // ㅙ
const int _jungOe = 11; // ㅚ
const int _jungU = 13; // ㅜ
const int _jungWeo = 14; // ㅝ
const int _jungEu = 18; // ㅡ
const int _jungI = 20; // ㅣ

/// 어간 끝음절 중성이 모음 어미와 만나 줄어드는 축약표.
/// 예: 어간 끝이 "이"(중성 ㅣ)면 어미 "어"가 붙어 "여"(중성 ㅕ)로 줄어듦.
/// "하다" 전용인 ㅏ→ㅐ 는 여기 넣지 않습니다 — [_matchesVerb]의 하다 특례
/// 부분 참고.
const Map<int, List<int>> _jungContraction = <int, List<int>>{
  _jungI: <int>[_jungYeo], // 이+어→여
  _jungO: <int>[_jungWa], // 오+아→와
  _jungU: <int>[_jungWeo], // 우+어→워
  _jungEu: <int>[_jungEo, _jungA], // 으+어→어, 으+아→아
  _jungOe: <int>[_jungWae], // 외+어→왜
};

/// 종성 없는 어간에 모음 어미가 붙어 생기는 받침(나+았→났, 하+ㄴ→한).
const Set<int> _fusedJongAfterOpenStem = <int>{
  _jongNone,
  _jongSs,
  _jongN,
  _jongL,
};

/// 어미가 시작될 수 있는 음절들. 1음절 어간(예: "참다"의 "참")에서만
/// 씁니다 — 어간이 한 글자면 "참새"의 "참"처럼 다른 낱말과 겹치기 쉬워서,
/// 매칭된 음절 바로 다음이 실제로 어미로 이어지는지 한 번 더 확인합니다.
const Set<String> _endingStarts = <String>{
  '았',
  '었',
  '고',
  '는',
  '느',
  '지',
  '아',
  '어',
  '으',
  '며',
  '면',
  '니',
  '다',
  '자',
  '게',
  '도',
  '서',
  '러',
  '려',
  '라',
  '네',
  '죠',
  '을',
  '더',
};

/// 공백과 문장부호를 제거합니다. 발화는 "며느리가, 방귀를... 참았어요!"
/// 처럼 STT가 구두점을 붙여 오기 때문에, 부분문자열/음절 비교 전에
/// 걷어내야 위치가 어긋나지 않습니다.
String _normalize(String text) =>
    text.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');

/// 한글 음절 하나를 초성/중성/종성 인덱스로 분해합니다. [char]가 한글
/// 음절 범위(가~힣) 밖이면(자모 단독, 영문, 숫자 등) `null` — 그런 문자는
/// 애초에 용언 활용 비교 대상이 아닙니다.
({int cho, int jung, int jong})? _decomposeSyllable(String char) {
  if (char.isEmpty) return null;
  final int code = char.codeUnitAt(0);
  if (code < _hangulBase || code > _hangulLast) return null;
  final int offset = code - _hangulBase;
  return (
    cho: offset ~/ _jungTimesJong,
    jung: (offset % _jungTimesJong) ~/ _jongCount,
    jong: offset % _jongCount,
  );
}

/// [keyword]가 어간+어미 결합으로 [utterance]에 나타나는지 봅니다.
/// [keyword]는 이미 "…다"로 끝나고 2자 이상임이 확인된 상태로 들어옵니다.
bool _matchesVerb(String utterance, String keyword) {
  // 마지막 "다"를 뗀 게 어간. "참다"→"참", "고마워하다"→"고마워하".
  final String stem = keyword.substring(0, keyword.length - 1);
  final String stemLast = stem.substring(stem.length - 1);
  final String stemPrefix = stem.substring(0, stem.length - 1);

  final ({int cho, int jung, int jong})? l = _decomposeSyllable(stemLast);
  if (l == null) {
    // 어간 끝음절이 한글 음절이 아니면(드문 입력값) 활용 비교를 할 수
    // 없으니, 최소한 어간 원문이라도 들어 있는지로 물러섭니다.
    return utterance.contains(stem);
  }

  // 하다 특례(규칙 5): "하"일 때만 ㅏ→ㅐ 를 추가로 허용합니다("고마워
  // 했어요"). 축약표 전체에 넣으면 "가다"가 "개는"에도 걸리는 오탐이
  // 생기므로 반드시 stemLast == '하' 조건 안에서만 적용합니다.
  final List<int> allowedJung = <int>[
    l.jung,
    ...?_jungContraction[l.jung],
    if (stemLast == '하' && l.jung == _jungA) _jungAe,
  ];

  final bool oneSyllableStem = stemPrefix.isEmpty;

  // P(어간 앞부분)가 나타나는 모든 위치에서, 그 바로 다음 음절 S를
  // 후보로 봅니다. P가 빈 문자열(1음절 어간)이면 발화의 모든 위치가
  // 후보입니다.
  for (int i = 0; i <= utterance.length - stemPrefix.length; i++) {
    if (stemPrefix.isNotEmpty && !utterance.startsWith(stemPrefix, i)) {
      continue;
    }
    final int candidateIndex = i + stemPrefix.length;
    if (candidateIndex >= utterance.length) continue;

    final String candidate = utterance[candidateIndex];
    final ({int cho, int jung, int jong})? s = _decomposeSyllable(candidate);
    if (s == null ||
        s.cho != l.cho ||
        !allowedJung.contains(s.jung) ||
        !_jongMatches(stemJong: l.jong, candidateJong: s.jong)) {
      continue;
    }

    final bool passesOneSyllableGuard =
        !oneSyllableStem ||
        candidateIndex + 1 >= utterance.length ||
        _endingStarts.contains(utterance[candidateIndex + 1]);
    if (passesOneSyllableGuard) return true;
  }
  return false;
}

/// 종성(받침) 비교. 받침 있는 어간은 모음 어미 앞에서 받침이 그대로
/// 보존되므로 정확히 같아야 하고(참+아→참아, 받침 ㅁ 유지), 받침 없는
/// 어간은 모음 어미와 만나 ㅆ/ㄴ/ㄹ 받침으로 융합될 수 있습니다
/// (나+았→났, 하+ㄴ→한).
bool _jongMatches({required int stemJong, required int candidateJong}) {
  if (stemJong != _jongNone) return candidateJong == stemJong;
  return _fusedJongAfterOpenStem.contains(candidateJong);
}

/// [utterance]에 [keyword]가 쓰였는지 판정합니다.
///
/// [aliases]에 하나라도 부분문자열로 들어 있으면 바로 매칭됩니다 —
/// 불규칙 용언(듣다→들어)처럼 규칙으로 못 잡는 활용형을 백엔드가 목록으로
/// 내려줄 때 꽂는 자리입니다.
///
/// [keyword]가 "다"로 끝나고 2자 이상이면 용언으로 보고 어간+어미 결합을
/// 확인합니다. 그 밖(체언, 또는 "다" 한 글자처럼 어간을 뗄 수 없는 값)은
/// 정규화한 문자열의 부분문자열 포함으로 판정합니다.
bool containsKeyword(
  String utterance,
  String keyword, {
  List<String> aliases = const <String>[],
}) {
  final String normalizedUtterance = _normalize(utterance);
  final String normalizedKeyword = _normalize(keyword);
  if (normalizedUtterance.isEmpty || normalizedKeyword.isEmpty) return false;

  for (final String alias in aliases) {
    final String normalizedAlias = _normalize(alias);
    if (normalizedAlias.isNotEmpty &&
        normalizedUtterance.contains(normalizedAlias)) {
      return true;
    }
  }

  if (normalizedKeyword.endsWith('다') && normalizedKeyword.length >= 2) {
    return _matchesVerb(normalizedUtterance, normalizedKeyword);
  }
  return normalizedUtterance.contains(normalizedKeyword);
}

/// [keywords] 중 [utterance]에서 실제로 매칭된 것만 골라 돌려줍니다.
Set<String> matchedKeywords(String utterance, List<String> keywords) {
  final Set<String> matched = <String>{};
  for (final String keyword in keywords) {
    if (containsKeyword(utterance, keyword)) matched.add(keyword);
  }
  return matched;
}
