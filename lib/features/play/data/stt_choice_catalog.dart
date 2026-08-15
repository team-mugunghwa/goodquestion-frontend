// GENERATED - 손으로 고치지 마세요.
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

  /// 그 장면의 첫 발화 턴에 보여줄 세 문장.
  static const Map<int, List<SttChoiceSentence>> firstTurn =
      <int, List<SttChoiceSentence>>{
        3: <SttChoiceSentence>[
          SttChoiceSentence(
            id: 'c3_t1_1',
            text: '계속 참으면 많이 힘들 것 같아요. 가족들도 처음엔 놀라도 곧 이해해 줄 거예요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.emotion,
              SttChoiceElement.perspective,
            ],
            sceneOrder: 3,
            assetPath: 'assets/audio/choices/c3_t1_1.mp3',
            duration: Duration(milliseconds: 9971),
          ),
          SttChoiceSentence(
            id: 'c3_t1_2',
            text: '자꾸 참으면 배가 아프니까, 가족들한테 먼저 솔직하게 말해 보세요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.reason,
              SttChoiceElement.solution,
            ],
            sceneOrder: 3,
            assetPath: 'assets/audio/choices/c3_t1_2.mp3',
            duration: Duration(milliseconds: 7131),
          ),
          SttChoiceSentence(
            id: 'c3_t1_3',
            text: '부끄러워서 말 못 하는 마음 알아요. 제일 편한 사람한테 먼저 말해 보면 어때요?',
            elements: <SttChoiceElement>[
              SttChoiceElement.emotion,
              SttChoiceElement.solution,
            ],
            sceneOrder: 3,
            assetPath: 'assets/audio/choices/c3_t1_3.mp3',
            duration: Duration(milliseconds: 7851),
          ),
        ],
        5: <SttChoiceSentence>[
          SttChoiceSentence(
            id: 'c5_t1_1',
            text: '며느리도 일부러 그런 게 아니에요. 오래 참다가 한꺼번에 크게 나온 거예요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.perspective,
              SttChoiceElement.reason,
            ],
            sceneOrder: 5,
            assetPath: 'assets/audio/choices/c5_t1_1.mp3',
            duration: Duration(milliseconds: 7051),
          ),
          SttChoiceSentence(
            id: 'c5_t1_2',
            text: '며느리가 지금 얼마나 창피하고 속상하겠어요. 친정에 보내기 전에 이야기를 한 번만 들어 주세요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.empathy,
              SttChoiceElement.request,
            ],
            sceneOrder: 5,
            assetPath: 'assets/audio/choices/c5_t1_2.mp3',
            duration: Duration(milliseconds: 8171),
          ),
          SttChoiceSentence(
            id: 'c5_t1_3',
            text: '시아버지도 갑자기 놀라셨을 것 같아요. 그래도 며느리 마음도 많이 아플 거예요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.perspective,
              SttChoiceElement.empathy,
            ],
            sceneOrder: 5,
            assetPath: 'assets/audio/choices/c5_t1_3.mp3',
            duration: Duration(milliseconds: 7811),
          ),
        ],
        7: <SttChoiceSentence>[
          SttChoiceSentence(
            id: 'c7_t1_1',
            text: '며느리 방귀로 배나무를 흔들어요. 며느리 방귀는 지붕도 흔들 만큼 힘이 세니까요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.solution,
              SttChoiceElement.reason,
            ],
            sceneOrder: 7,
            assetPath: 'assets/audio/choices/c7_t1_1.mp3',
            duration: Duration(milliseconds: 8331),
          ),
          SttChoiceSentence(
            id: 'c7_t1_2',
            text: '며느리한테 도와달라고 부탁하고, 사람들은 나무에서 멀리 떨어져 있어요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.request,
              SttChoiceElement.solution,
            ],
            sceneOrder: 7,
            assetPath: 'assets/audio/choices/c7_t1_2.mp3',
            duration: Duration(milliseconds: 6011),
          ),
          SttChoiceSentence(
            id: 'c7_t1_3',
            text: '며느리가 나무 아래에서 방귀를 뀌면 배가 우수수 떨어져서 다 같이 나눠 먹을 수 있어요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.solution,
              SttChoiceElement.result,
            ],
            sceneOrder: 7,
            assetPath: 'assets/audio/choices/c7_t1_3.mp3',
            duration: Duration(milliseconds: 7131),
          ),
        ],
        9: <SttChoiceSentence>[
          SttChoiceSentence(
            id: 'c9_t1_1',
            text: '이제 당당해진 것 같아서 저도 기뻐요. 큰 방귀는 부끄러운 게 아니라 특별한 힘이에요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.emotion,
              SttChoiceElement.perspective,
            ],
            sceneOrder: 9,
            assetPath: 'assets/audio/choices/c9_t1_1.mp3',
            duration: Duration(milliseconds: 10011),
          ),
          SttChoiceSentence(
            id: 'c9_t1_2',
            text: '미리 알려 주고 사람 없는 쪽에서 뀌면 돼요. 그러면 높은 곳 열매를 딸 때 도와줄 수 있어요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.solution,
              SttChoiceElement.result,
            ],
            sceneOrder: 9,
            assetPath: 'assets/audio/choices/c9_t1_2.mp3',
            duration: Duration(milliseconds: 10651),
          ),
          SttChoiceSentence(
            id: 'c9_t1_3',
            text: '이제 부끄러워하지 않아도 돼요. 남을 도울 수 있는 좋은 점이니까요.',
            elements: <SttChoiceElement>[
              SttChoiceElement.perspective,
              SttChoiceElement.result,
            ],
            sceneOrder: 9,
            assetPath: 'assets/audio/choices/c9_t1_3.mp3',
            duration: Duration(milliseconds: 7531),
          ),
        ],
      };

  /// 두 번째 턴부터 쓰는, 요소별 문장 한 개씩.
  static const Map<int, Map<SttChoiceElement, SttChoiceSentence>> byElement =
      <int, Map<SttChoiceElement, SttChoiceSentence>>{
        3: <SttChoiceElement, SttChoiceSentence>{
          SttChoiceElement.emotion: SttChoiceSentence(
            id: 'c3_EMOTION',
            text: '혼자 참고 있으면 많이 외롭고 속상할 것 같아요.',
            elements: <SttChoiceElement>[SttChoiceElement.emotion],
            sceneOrder: 3,
            assetPath: 'assets/audio/choices/c3_EMOTION.mp3',
            duration: Duration(milliseconds: 5171),
          ),
          SttChoiceElement.perspective: SttChoiceSentence(
            id: 'c3_PERSPECTIVE',
            text: '가족들도 놀라기는 하겠지만 미워하지는 않을 거예요.',
            elements: <SttChoiceElement>[SttChoiceElement.perspective],
            sceneOrder: 3,
            assetPath: 'assets/audio/choices/c3_PERSPECTIVE.mp3',
            duration: Duration(milliseconds: 5571),
          ),
          SttChoiceElement.reason: SttChoiceSentence(
            id: 'c3_REASON',
            text: '오래 참으면 몸이 아프고 마음도 답답해지니까 말하는 게 좋아요.',
            elements: <SttChoiceElement>[SttChoiceElement.reason],
            sceneOrder: 3,
            assetPath: 'assets/audio/choices/c3_REASON.mp3',
            duration: Duration(milliseconds: 7371),
          ),
          SttChoiceElement.solution: SttChoiceSentence(
            id: 'c3_SOLUTION',
            text: '밥 먹고 나서 조용할 때 가족들한테 이야기해 보세요.',
            elements: <SttChoiceElement>[SttChoiceElement.solution],
            sceneOrder: 3,
            assetPath: 'assets/audio/choices/c3_SOLUTION.mp3',
            duration: Duration(milliseconds: 6251),
          ),
        },
        5: <SttChoiceElement, SttChoiceSentence>{
          SttChoiceElement.perspective: SttChoiceSentence(
            id: 'c5_PERSPECTIVE',
            text: '며느리는 그동안 눈치 보면서 계속 참기만 했을 거예요.',
            elements: <SttChoiceElement>[SttChoiceElement.perspective],
            sceneOrder: 5,
            assetPath: 'assets/audio/choices/c5_PERSPECTIVE.mp3',
            duration: Duration(milliseconds: 5971),
          ),
          SttChoiceElement.reason: SttChoiceSentence(
            id: 'c5_REASON',
            text: '너무 오래 참아서 한 번에 크게 터진 거예요.',
            elements: <SttChoiceElement>[SttChoiceElement.reason],
            sceneOrder: 5,
            assetPath: 'assets/audio/choices/c5_REASON.mp3',
            duration: Duration(milliseconds: 4291),
          ),
          SttChoiceElement.empathy: SttChoiceSentence(
            id: 'c5_EMPATHY',
            text: '며느리도 지금 제일 놀라고 부끄러울 거예요.',
            elements: <SttChoiceElement>[SttChoiceElement.empathy],
            sceneOrder: 5,
            assetPath: 'assets/audio/choices/c5_EMPATHY.mp3',
            duration: Duration(milliseconds: 3731),
          ),
          SttChoiceElement.request: SttChoiceSentence(
            id: 'c5_REQUEST',
            text: '보내지 마시고, 왜 그랬는지 며느리한테 한 번만 물어봐 주세요.',
            elements: <SttChoiceElement>[SttChoiceElement.request],
            sceneOrder: 5,
            assetPath: 'assets/audio/choices/c5_REQUEST.mp3',
            duration: Duration(milliseconds: 6131),
          ),
        },
        7: <SttChoiceElement, SttChoiceSentence>{
          SttChoiceElement.reason: SttChoiceSentence(
            id: 'c7_REASON',
            text: '며느리 방귀는 기왓장도 날릴 만큼 세니까 배도 떨어질 거예요.',
            elements: <SttChoiceElement>[SttChoiceElement.reason],
            sceneOrder: 7,
            assetPath: 'assets/audio/choices/c7_REASON.mp3',
            duration: Duration(milliseconds: 5851),
          ),
          SttChoiceElement.solution: SttChoiceSentence(
            id: 'c7_SOLUTION',
            text: '며느리가 나무 아래에 서서 방귀를 뀌면 배가 떨어져요.',
            elements: <SttChoiceElement>[SttChoiceElement.solution],
            sceneOrder: 7,
            assetPath: 'assets/audio/choices/c7_SOLUTION.mp3',
            duration: Duration(milliseconds: 6091),
          ),
          SttChoiceElement.request: SttChoiceSentence(
            id: 'c7_REQUEST',
            text: '며느리한테 한 번만 도와달라고 부탁하고, 사람들은 옆으로 피해 있어요.',
            elements: <SttChoiceElement>[SttChoiceElement.request],
            sceneOrder: 7,
            assetPath: 'assets/audio/choices/c7_REQUEST.mp3',
            duration: Duration(milliseconds: 5731),
          ),
          SttChoiceElement.result: SttChoiceSentence(
            id: 'c7_RESULT',
            text: '배가 많이 떨어져서 마을에서 배 잔치를 할 수 있어요.',
            elements: <SttChoiceElement>[SttChoiceElement.result],
            sceneOrder: 7,
            assetPath: 'assets/audio/choices/c7_RESULT.mp3',
            duration: Duration(milliseconds: 4971),
          ),
        },
        9: <SttChoiceElement, SttChoiceSentence>{
          SttChoiceElement.emotion: SttChoiceSentence(
            id: 'c9_EMOTION',
            text: '웃는 걸 보니까 저도 마음이 놓이고 기뻐요.',
            elements: <SttChoiceElement>[SttChoiceElement.emotion],
            sceneOrder: 9,
            assetPath: 'assets/audio/choices/c9_EMOTION.mp3',
            duration: Duration(milliseconds: 4971),
          ),
          SttChoiceElement.perspective: SttChoiceSentence(
            id: 'c9_PERSPECTIVE',
            text: '남들과 다른 건 이상한 게 아니라 특별한 거예요.',
            elements: <SttChoiceElement>[SttChoiceElement.perspective],
            sceneOrder: 9,
            assetPath: 'assets/audio/choices/c9_PERSPECTIVE.mp3',
            duration: Duration(milliseconds: 5771),
          ),
          SttChoiceElement.solution: SttChoiceSentence(
            id: 'c9_SOLUTION',
            text: '뀌기 전에 미리 말해 주고, 사람이 없는 쪽으로 서서 뀌면 돼요.',
            elements: <SttChoiceElement>[SttChoiceElement.solution],
            sceneOrder: 9,
            assetPath: 'assets/audio/choices/c9_SOLUTION.mp3',
            duration: Duration(milliseconds: 6331),
          ),
          SttChoiceElement.result: SttChoiceSentence(
            id: 'c9_RESULT',
            text: '높은 나무의 열매를 딸 때 마을 사람들을 도와줄 수 있어요.',
            elements: <SttChoiceElement>[SttChoiceElement.result],
            sceneOrder: 9,
            assetPath: 'assets/audio/choices/c9_RESULT.mp3',
            duration: Duration(milliseconds: 5091),
          ),
        },
      };

  /// 1회 실패 뒤 캐릭터가 다시 물어보는 말.
  static const Map<int, SttChoiceVoice> retryFirst = <int, SttChoiceVoice>{
    3: SttChoiceVoice(
      id: 'retry_1_c3',
      text: '괜찮아, 다시 한 번 말해 줄래?',
      assetPath: 'assets/audio/choices/retry_1_c3.mp3',
      duration: Duration(milliseconds: 4051),
    ),
    5: SttChoiceVoice(
      id: 'retry_1_c5',
      text: '허허, 잘 못 들었구나. 다시 한 번 말해 보거라.',
      assetPath: 'assets/audio/choices/retry_1_c5.mp3',
      duration: Duration(milliseconds: 4171),
    ),
    7: SttChoiceVoice(
      id: 'retry_1_c7',
      text: '허허, 잘 안 들렸소. 한 번만 더 말해 주겠소?',
      assetPath: 'assets/audio/choices/retry_1_c7.mp3',
      duration: Duration(milliseconds: 4011),
    ),
    9: SttChoiceVoice(
      id: 'retry_1_c9',
      text: '괜찮아, 다시 한 번 말해 줄래?',
      assetPath: 'assets/audio/choices/retry_1_c9.mp3',
      duration: Duration(milliseconds: 3891),
    ),
  };

  /// 2회 실패 뒤 캐릭터가 다시 물어보는 말.
  static const Map<int, SttChoiceVoice> retrySecond = <int, SttChoiceVoice>{
    3: SttChoiceVoice(
      id: 'retry_2_c3',
      text: '소리가 잘 안 들렸어. 조금만 크게 말해 줄래?',
      assetPath: 'assets/audio/choices/retry_2_c3.mp3',
      duration: Duration(milliseconds: 5451),
    ),
    5: SttChoiceVoice(
      id: 'retry_2_c5',
      text: '이 늙은이가 귀가 어두워서 그런다. 조금 크게 말해 보거라.',
      assetPath: 'assets/audio/choices/retry_2_c5.mp3',
      duration: Duration(milliseconds: 5091),
    ),
    7: SttChoiceVoice(
      id: 'retry_2_c7',
      text: '소리가 작아서 잘 안 들리는구려. 조금 크게 말해 주시오.',
      assetPath: 'assets/audio/choices/retry_2_c7.mp3',
      duration: Duration(milliseconds: 5651),
    ),
    9: SttChoiceVoice(
      id: 'retry_2_c9',
      text: '소리가 잘 안 들렸어. 조금만 크게 말해 줄래?',
      assetPath: 'assets/audio/choices/retry_2_c9.mp3',
      duration: Duration(milliseconds: 5331),
    ),
  };

  /// 선택지를 내리면서 캐릭터가 건네는 말.
  static const Map<int, SttChoiceVoice> choiceIntro = <int, SttChoiceVoice>{
    3: SttChoiceVoice(
      id: 'choice_intro_c3',
      text: '그럼 이 중에서 하고 싶은 말을 골라 볼래?',
      assetPath: 'assets/audio/choices/choice_intro_c3.mp3',
      duration: Duration(milliseconds: 4611),
    ),
    5: SttChoiceVoice(
      id: 'choice_intro_c5',
      text: '그럼 이 중에서 골라 말해 보거라.',
      assetPath: 'assets/audio/choices/choice_intro_c5.mp3',
      duration: Duration(milliseconds: 3091),
    ),
    7: SttChoiceVoice(
      id: 'choice_intro_c7',
      text: '그럼 이 중에서 골라 말해 주겠소?',
      assetPath: 'assets/audio/choices/choice_intro_c7.mp3',
      duration: Duration(milliseconds: 2931),
    ),
    9: SttChoiceVoice(
      id: 'choice_intro_c9',
      text: '그럼 이 중에서 하고 싶은 말을 골라 볼래?',
      assetPath: 'assets/audio/choices/choice_intro_c9.mp3',
      duration: Duration(milliseconds: 5371),
    ),
  };
}
