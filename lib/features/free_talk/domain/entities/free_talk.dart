/// 후속 자유 대화(`/api/.../free-talk`)의 도메인 모델.
///
/// 이야기를 완주한 아이가 그 이야기의 인물과 **목표 요소 없이** 이어서
/// 말하는 기능입니다. 학습 대화(`play_session.dart`)와 모델을 나눠 두는
/// 이유는 서버 응답이 다르기 때문만이 아닙니다 — 자유 대화에는 사고 요소·
/// 미션·별가루가 **없어야** 하는데, 학습 모델을 재사용하면 그 필드들이
/// 딸려 들어와 언젠가 화면에 새어 나옵니다.
/// → `docs/기획` · 후속대화 설계 문서
library;

/// 자유 대화를 걸 수 있는 인물 한 명.
class FreeTalkCharacter {
  const FreeTalkCharacter({
    required this.characterId,
    required this.name,
    required this.characterKey,
    this.thumbnailUrl,
    this.lastTalkedAt,
  });

  final String characterId;
  final String name;

  /// 서버가 쓰는 인물 식별 문자열(`daughter_in_law` 등). 화면에는 그리지
  /// 않고, 표정 에셋을 찾을 때 [characterId] 가 안 맞으면 이걸로 되짚습니다.
  final String characterKey;

  /// 인물 카드에 쓸 표정 이미지. 없으면 번들 에셋으로 폴백합니다.
  final String? thumbnailUrl;

  /// 마지막으로 이야기한 시각. 한 번도 안 걸었으면 `null` 입니다.
  final DateTime? lastTalkedAt;
}

/// 캐릭터가 한 말 한 덩어리.
class FreeTalkSpeech {
  const FreeTalkSpeech({required this.text, this.audioUrl, this.emotion});

  final String text;

  /// 사전 합성된 음성. 없으면 화면이 `/api/tts` 로 직접 합성합니다.
  final String? audioUrl;

  /// 서버가 정한 감정. 표정 매니페스트의 상태 키와 이름이 같으면 그 표정으로
  /// 갈아 끼우고, 모르는 값이면 **표정을 바꾸지 않습니다** — 모르는 감정에
  /// 임의의 표정을 고르면 아이 말과 무관한 얼굴이 나옵니다.
  final String? emotion;
}

/// `POST /api/children/{childId}/free-talk` 응답.
class FreeTalkSession {
  const FreeTalkSession({
    required this.freeTalkId,
    required this.character,
    required this.opening,
    required this.maxTurns,
  });

  final String freeTalkId;
  final FreeTalkCharacter character;
  final FreeTalkSpeech opening;

  /// 이 대화의 턴 상한. **화면에 그리지 않습니다** — 남은 횟수를 세는 순간
  /// 대화가 과제가 됩니다(설계 결정). 서버가 [FreeTalkTurn.ended] 로
  /// 알려 주므로 프런트는 이 값으로 아무것도 판단하지 않습니다.
  final int maxTurns;
}

/// `POST /api/free-talk/{freeTalkId}/messages` 응답.
class FreeTalkTurn {
  const FreeTalkTurn({
    required this.characterMessage,
    required this.turnCount,
    required this.ended,
  });

  final FreeTalkSpeech characterMessage;

  /// 지금까지 주고받은 턴 수. 화면에 그리지 않고 디버깅·로그용으로만 둡니다.
  final int turnCount;

  /// 이번 대사를 끝으로 대화가 닫혔는지. **턴 상한 판단은 서버 몫입니다** —
  /// 프런트가 [FreeTalkSession.maxTurns] 로 세면 서버가 안전 사유로 일찍
  /// 닫은 대화를 계속 이어 가려 듭니다.
  final bool ended;
}
