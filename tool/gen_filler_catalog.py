# manifest.json -> Dart 상수 테이블 생성기 (필러/맞장구 음성).
#
# `gen_stt_choice_catalog.py` 와 같은 방식입니다 - 문장을 손으로 옮기지 않고
# 기계 변환합니다. 음성을 다시 뽑으면 manifest 를 갈아끼우고 이걸 다시 돌립니다.
#
# 원본 mp3·manifest 는 ai-service 의 `prerender_fillers_gemini.py` 가 만듭니다.
import collections
import io
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "assets", "audio", "fillers", "manifest.json")
OUT = os.path.join(ROOT, "lib", "features", "play", "data", "filler_catalog.dart")

SCENES = [3, 5, 7, 9]

m = json.load(io.open(SRC, encoding="utf-8"))
items = m["items"]

by_scene = collections.defaultdict(list)
for it in items:
    if not re.fullmatch(r"f_c\d+_\d+", it["id"]):
        raise SystemExit("알 수 없는 id: " + it["id"])
    by_scene[int(it["scene"])].append(it)

# 며느리가 장면 3 과 9 에 나온다. 같은 보이스·같은 연기 지시라 파일을 또 만들지
# 않고 장면 3 것을 그대로 가리킨다. 매니페스트의 sceneAlias 가 그 짝이다.
for src, dst in ((int(k), v) for k, v in m.get("sceneAlias", {}).items()):
    by_scene[src] = by_scene[dst]

for sc in SCENES:
    by_scene[sc].sort(key=lambda x: x["id"])
    # 풀이 한 장뿐이면 셔플 백이 인접 중복을 못 막습니다. 최소 두 장은 있어야
    # "같은 맞장구가 연달아 나오지 않는다"가 성립합니다. → FillerSelector
    if len(by_scene[sc]) < 2:
        raise SystemExit(f"장면 {sc}: 필러가 {len(by_scene[sc])}개뿐입니다")


def q(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def ms(d):
    return int(round(float(d) * 1000))


lines = []
w = lines.append

w("// GENERATED - 손으로 고치지 마세요. (tool/gen_filler_catalog.py)")
w("//")
w("// 원본은 `assets/audio/fillers/manifest.json` 입니다. 문장·장면·실측 길이가")
w("// 모두 그 파일에 들어 있어서, 옮겨 적지 않고 그대로 기계 변환해 둡니다.")
w("// 음성을 다시 뽑으면 manifest 를 갈아끼우고 이 파일을 다시 생성합니다.")
w("//")
w("// 선택지 음성([SttChoiceCatalog])과 같은 길입니다 - DB 를 타지 않습니다.")
w("// `scene_audio` 는 `scene_id` 가 NOT NULL 이고 slot 이 세 값으로 제한돼")
w("// 있으며 (scene_id, slot) 이 유니크라 \"여러 개 중 골라 트는\" 소리를 담을 수")
w("// 없습니다. 조회도 재생할 문장의 해시로 하는데, 필러는 어떤 대사가 올지")
w("// 모르는 상태에서 트는 소리라 대조할 문장이 아예 없습니다.")
w("")
w("/// 아이 말이 서버로 떠난 뒤 캐릭터가 내는 짧은 맞장구 한 마디.")
w("///")
w("/// 캐릭터가 대답하기까지 6초 남짓이 비는 동안(분석 LLM + 캐릭터 LLM + TTS")
w("/// 왕복) 그 앞머리를 덮습니다. **런타임 합성을 타지 않는 정적 파일입니다** -")
w("/// 지연을 덮으려고 트는 소리가 또 왕복을 하면 지연을 더합니다.")
w("class DialogueFiller {")
w("  const DialogueFiller({")
w("    required this.id,")
w("    required this.text,")
w("    required this.assetPath,")
w("    required this.duration,")
w("  });")
w("")
w("  final String id;")
w("")
w("  /// 무엇을 녹음해 둔 것인지 코드에서 보이게 두는 값입니다.")
w("  ///")
w("  /// **자막으로 띄우지 않습니다.** 아이가 무슨 말을 했는지 모르는 상태에서")
w("  /// 트는 소리라 말풍선에 올릴 내용이 아니고, 올리면 곧 도착할 진짜 대사가")
w("  /// 그 자리를 다시 덮어써 말풍선이 두 번 바뀝니다.")
w("  final String text;")
w("")
w("  /// 앱에 들어 있는 mp3. 네트워크 왕복이 없어야 \"말을 마치자마자\" 들립니다.")
w("  final String assetPath;")
w("")
w("  /// ffprobe 로 잰 실제 길이입니다(메타값이 아닙니다 - mp3 인코더 패딩 때문에")
w("  /// 둘이 1% 남짓 어긋납니다).")
w("  final Duration duration;")
w("}")
w("")
w("/// 장면별 맞장구 테이블.")
w("///")
w("/// 음성이 준비된 장면은 3 · 5 · 7 · 9 네 개뿐입니다(선택지 음성과 같습니다).")
w("/// 그 밖의 장면에서는 조회가 비어서 돌아오고, 화면은 예전처럼 조용히")
w("/// 기다립니다 - 없는 장면에서 억지로 다른 캐릭터 목소리를 트느니 그편이 낫습니다.")
w("class FillerCatalog {")
w("  const FillerCatalog._();")
w("")
w("  /// 맞장구가 준비된 장면 번호.")
w("  static const Set<int> supportedScenes = <int>{%s};" % ", ".join(str(s) for s in SCENES))
w("")
w("  static bool supports(int? sceneOrder) =>")
w("      sceneOrder != null && supportedScenes.contains(sceneOrder);")
w("")
w("  /// 장면별 후보. 같은 것이 연달아 나오지 않게 고르는 일은")
w("  /// [FillerSelector] 가 합니다.")
w("  static const Map<int, List<DialogueFiller>> byScene =")
w("      <int, List<DialogueFiller>>{")

for sc in SCENES:
    w("        %d: <DialogueFiller>[" % sc)
    for it in by_scene[sc]:
        w("          DialogueFiller(")
        w("            id: %s," % q(it["id"]))
        w("            text: %s," % q(it["text"]))
        w("            assetPath: 'assets/audio/fillers/%s'," % it["file"])
        w("            duration: Duration(milliseconds: %d)," % ms(it["duration"]))
        w("          ),")
    w("        ],")

w("      };")
w("}")
w("")

io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines))

total = sum(len(by_scene[s]) for s in SCENES)
longest = max(float(it["duration"]) for it in items)
print("%s\n  필러 %d개 (장면당 %s) · 최장 %.3f초"
      % (OUT, total, "/".join(str(len(by_scene[s])) for s in SCENES), longest))
