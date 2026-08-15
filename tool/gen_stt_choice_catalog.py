# manifest.json -> Dart 상수 테이블 생성기.
# 문장을 손으로 옮기지 않기 위한 일회성 스크립트. 원본: assets/audio/choices/manifest.json
import json, io, re, sys, collections

SRC = r"C:\dev\goodquestion-frontend\assets\audio\choices\manifest.json"
OUT = r"C:\dev\goodquestion-frontend\lib\features\play\data\stt_choice_catalog.dart"

m = json.load(io.open(SRC, encoding="utf-8"))
items = m["items"]

ELEMENTS = ["EMOTION", "PERSPECTIVE", "REASON", "SOLUTION", "EMPATHY", "REQUEST", "RESULT"]
SCENES = [3, 5, 7, 9]

def q(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"

def ms(d):
    return int(round(float(d) * 1000))

first_turn = collections.defaultdict(list)   # scene -> [item]
by_element = collections.defaultdict(dict)   # scene -> element -> item
retry1, retry2, intro = {}, {}, {}

for it in items:
    i = it["id"]
    sc = int(it["scene"])
    if re.fullmatch(r"c\d+_t1_[123]", i):
        first_turn[sc].append(it)
    elif re.fullmatch(r"c\d+_(" + "|".join(ELEMENTS) + r")", i):
        by_element[sc][i.split("_", 1)[1]] = it
    elif i.startswith("retry_1_"):
        retry1[sc] = it
    elif i.startswith("retry_2_"):
        retry2[sc] = it
    elif i.startswith("choice_intro_"):
        intro[sc] = it
    else:
        sys.exit("알 수 없는 id: " + i)

for sc in SCENES:
    first_turn[sc].sort(key=lambda x: x["id"])
    assert len(first_turn[sc]) == 3, (sc, first_turn[sc])
    assert sc in retry1 and sc in retry2 and sc in intro, sc

def sentence(it, indent):
    p = " " * indent
    els = ", ".join("SttChoiceElement." + e.lower() for e in it["elements"])
    return (
        f"{p}SttChoiceSentence(\n"
        f"{p}  id: {q(it['id'])},\n"
        f"{p}  text: {q(it['text'])},\n"
        f"{p}  elements: <SttChoiceElement>[{els}],\n"
        f"{p}  sceneOrder: {it['scene']},\n"
        f"{p}  assetPath: {q('assets/audio/choices/' + it['file'])},\n"
        f"{p}  duration: Duration(milliseconds: {ms(it['duration'])}),\n"
        f"{p})"
    )

def voice(it, indent):
    p = " " * indent
    return (
        f"{p}SttChoiceVoice(\n"
        f"{p}  id: {q(it['id'])},\n"
        f"{p}  text: {q(it['text'])},\n"
        f"{p}  assetPath: {q('assets/audio/choices/' + it['file'])},\n"
        f"{p}  duration: Duration(milliseconds: {ms(it['duration'])}),\n"
        f"{p})"
    )

L = []
w = L.append
w("""// GENERATED - 손으로 고치지 마세요.
//
// 원본은 `assets/audio/choices/manifest.json` 입니다(백엔드 공유, 2026-08-15).
// 문장·요소·장면·길이가 모두 그 파일에 들어 있어서, 옮겨 적지 않고 그대로
// 기계 변환해 둡니다. 음성을 다시 뽑으면 manifest 를 갈아끼우고 이 파일을
// 다시 생성합니다.
//
// 지금은 프론트 상수로 들고 있습니다. 나중에 서버(DB)로 옮기더라도 화면은
// [SttChoiceCatalog] 만 보고 있으므로, 이 파일을 리포지토리 구현으로
// 바꿔 끼우면 됩니다. → `docs/이야기_전개_가이드.md` 3.4

/// 대화가 채워 나가는 생각 요소. 서버 `progress.missingElements` 의 값과
/// 같은 이름을 씁니다.
enum SttChoiceElement {
  emotion('EMOTION'),
  perspective('PERSPECTIVE'),
  reason('REASON'),
  solution('SOLUTION'),
  empathy('EMPATHY'),
  request('REQUEST'),
  result('RESULT');

  const SttChoiceElement(this.code);

  /// 서버가 쓰는 대문자 코드.
  final String code;

  /// 서버 문자열을 열거형으로. 모르는 값이면 null - 콘텐츠가 늘어나
  /// 새 요소가 생겨도 화면이 죽지 않게 합니다.
  static SttChoiceElement? fromCode(String code) {
    for (final SttChoiceElement element in SttChoiceElement.values) {
      if (element.code == code) return element;
    }
    return null;
  }
}

/// 아이가 고를 수 있는 문장 한 장.
class SttChoiceSentence {
  const SttChoiceSentence({
    required this.id,
    required this.text,
    required this.elements,
    required this.sceneOrder,
    required this.assetPath,
    required this.duration,
  });

  final String id;

  /// 카드에 그대로 보여주고, 고르면 그대로 발화 `text` 로 보냅니다.
  final String text;

  /// 이 문장이 채워 주는 생각 요소.
  final List<SttChoiceElement> elements;
  final int sceneOrder;

  /// 스피커 버튼이 재생할 mp3.
  final String assetPath;
  final Duration duration;
}

/// 카드가 아닌 안내 음성(재시도 1·2회, 선택지 안내).
class SttChoiceVoice {
  const SttChoiceVoice({
    required this.id,
    required this.text,
    required this.assetPath,
    required this.duration,
  });

  final String id;

  /// 자막용. 아이가 소리를 못 듣는 환경에서도 같은 말이 보여야 합니다.
  final String text;
  final String assetPath;
  final Duration duration;
}

/// 장면별 문장·안내 음성 테이블.
///
/// 음성이 준비된 장면은 3 · 5 · 7 · 9 네 개뿐입니다. 그 밖의 장면에서는
/// 모든 조회가 비어서 돌아오고, 화면은 선택지 없이 재녹음 안내만 유지합니다.
class SttChoiceCatalog {
  const SttChoiceCatalog._();

  /// 선택지 음성이 준비된 장면 번호.
  static const Set<int> supportedScenes = <int>{3, 5, 7, 9};

  static bool supports(int? sceneOrder) =>
      sceneOrder != null && supportedScenes.contains(sceneOrder);
""")

w("\n  /// 그 장면의 첫 발화 턴에 보여줄 세 문장.")
w("  static const Map<int, List<SttChoiceSentence>> firstTurn =")
w("      <int, List<SttChoiceSentence>>{")
for sc in SCENES:
    w(f"        {sc}: <SttChoiceSentence>[")
    for it in first_turn[sc]:
        w(sentence(it, 10) + ",")
    w("        ],")
w("      };")

w("\n  /// 두 번째 턴부터 쓰는, 요소별 문장 한 개씩.")
w("  static const Map<int, Map<SttChoiceElement, SttChoiceSentence>> byElement =")
w("      <int, Map<SttChoiceElement, SttChoiceSentence>>{")
for sc in SCENES:
    w(f"        {sc}: <SttChoiceElement, SttChoiceSentence>{{")
    for e in ELEMENTS:
        if e in by_element[sc]:
            w(f"          SttChoiceElement.{e.lower()}:")
            w(sentence(by_element[sc][e], 14) + ",")
    w("        },")
w("      };")

for name, table, doc in (
    ("retryFirst", retry1, "1회 실패 뒤 캐릭터가 다시 물어보는 말."),
    ("retrySecond", retry2, "2회 실패 뒤 캐릭터가 다시 물어보는 말."),
    ("choiceIntro", intro, "선택지를 내리면서 캐릭터가 건네는 말."),
):
    w(f"\n  /// {doc}")
    w(f"  static const Map<int, SttChoiceVoice> {name} = <int, SttChoiceVoice>{{")
    for sc in SCENES:
        w(f"        {sc}:")
        w(voice(table[sc], 12) + ",")
    w("      };")

w("}")

io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
print("wrote", OUT)
print("first-turn:", {k: len(v) for k, v in first_turn.items()})
print("by-element:", {k: sorted(v) for k, v in by_element.items()})

# 생성 후에는 `dart format lib/features/play/data/stt_choice_catalog.dart` 를 돌립니다.
