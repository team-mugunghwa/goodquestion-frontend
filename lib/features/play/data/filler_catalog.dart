// GENERATED - 손으로 고치지 마세요. (tool/gen_filler_catalog.py)
//
// 원본은 `assets/audio/fillers/manifest.json` 입니다. 문장·장면·실측 길이가
// 모두 그 파일에 들어 있어서, 옮겨 적지 않고 그대로 기계 변환해 둡니다.
// 음성을 다시 뽑으면 manifest 를 갈아끼우고 이 파일을 다시 생성합니다.
//
// 선택지 음성([SttChoiceCatalog])과 같은 길입니다 - DB 를 타지 않습니다.
// `scene_audio` 는 `scene_id` 가 NOT NULL 이고 slot 이 세 값으로 제한돼
// 있으며 (scene_id, slot) 이 유니크라 "여러 개 중 골라 트는" 소리를 담을 수
// 없습니다. 조회도 재생할 문장의 해시로 하는데, 필러는 어떤 대사가 올지
// 모르는 상태에서 트는 소리라 대조할 문장이 아예 없습니다.

/// 아이 말이 서버로 떠난 뒤 캐릭터가 내는 짧은 맞장구 한 마디.
///
/// 캐릭터가 대답하기까지 6초 남짓이 비는 동안(분석 LLM + 캐릭터 LLM + TTS
/// 왕복) 그 앞머리를 덮습니다. **런타임 합성을 타지 않는 정적 파일입니다** -
/// 지연을 덮으려고 트는 소리가 또 왕복을 하면 지연을 더합니다.
class DialogueFiller {
  const DialogueFiller({
    required this.id,
    required this.text,
    required this.assetPath,
    required this.duration,
  });

  final String id;

  /// 무엇을 녹음해 둔 것인지 코드에서 보이게 두는 값입니다.
  ///
  /// **자막으로 띄우지 않습니다.** 아이가 무슨 말을 했는지 모르는 상태에서
  /// 트는 소리라 말풍선에 올릴 내용이 아니고, 올리면 곧 도착할 진짜 대사가
  /// 그 자리를 다시 덮어써 말풍선이 두 번 바뀝니다.
  final String text;

  /// 앱에 들어 있는 mp3. 네트워크 왕복이 없어야 "말을 마치자마자" 들립니다.
  final String assetPath;

  /// ffprobe 로 잰 실제 길이입니다(메타값이 아닙니다 - mp3 인코더 패딩 때문에
  /// 둘이 1% 남짓 어긋납니다).
  final Duration duration;
}

/// 장면별 맞장구 테이블.
///
/// 음성이 준비된 장면은 3 · 5 · 7 · 9 네 개뿐입니다(선택지 음성과 같습니다).
/// 그 밖의 장면에서는 조회가 비어서 돌아오고, 화면은 예전처럼 조용히
/// 기다립니다 - 없는 장면에서 억지로 다른 캐릭터 목소리를 트느니 그편이 낫습니다.
class FillerCatalog {
  const FillerCatalog._();

  /// 맞장구가 준비된 장면 번호.
  static const Set<int> supportedScenes = <int>{3, 5, 7, 9};

  static bool supports(int? sceneOrder) =>
      sceneOrder != null && supportedScenes.contains(sceneOrder);

  /// 장면별 후보. 같은 것이 연달아 나오지 않게 고르는 일은
  /// [FillerSelector] 가 합니다.
  static const Map<int, List<DialogueFiller>> byScene =
      <int, List<DialogueFiller>>{
        3: <DialogueFiller>[
          DialogueFiller(
            id: 'f_c3_01',
            text: '음…… 그렇구나……',
            assetPath: 'assets/audio/fillers/f_c3_01.mp3',
            duration: Duration(milliseconds: 2664),
          ),
          DialogueFiller(
            id: 'f_c3_02',
            text: '아…… 그랬구나……',
            assetPath: 'assets/audio/fillers/f_c3_02.mp3',
            duration: Duration(milliseconds: 2904),
          ),
        ],
        5: <DialogueFiller>[
          DialogueFiller(
            id: 'f_c5_01',
            text: '허허…… 그렇구먼그래……',
            assetPath: 'assets/audio/fillers/f_c5_01.mp3',
            duration: Duration(milliseconds: 3312),
          ),
          DialogueFiller(
            id: 'f_c5_02',
            text: '오호…… 그런 말이구먼……',
            assetPath: 'assets/audio/fillers/f_c5_02.mp3',
            duration: Duration(milliseconds: 4032),
          ),
        ],
        7: <DialogueFiller>[
          DialogueFiller(
            id: 'f_c7_01',
            text: '허허…… 그런 말이구려……',
            assetPath: 'assets/audio/fillers/f_c7_01.mp3',
            duration: Duration(milliseconds: 3291),
          ),
          DialogueFiller(
            id: 'f_c7_02',
            text: '오호…… 그렇단 말이오……',
            assetPath: 'assets/audio/fillers/f_c7_02.mp3',
            duration: Duration(milliseconds: 3531),
          ),
        ],
        9: <DialogueFiller>[
          DialogueFiller(
            id: 'f_c3_01',
            text: '음…… 그렇구나……',
            assetPath: 'assets/audio/fillers/f_c3_01.mp3',
            duration: Duration(milliseconds: 2664),
          ),
          DialogueFiller(
            id: 'f_c3_02',
            text: '아…… 그랬구나……',
            assetPath: 'assets/audio/fillers/f_c3_02.mp3',
            duration: Duration(milliseconds: 2904),
          ),
        ],
      };
}
