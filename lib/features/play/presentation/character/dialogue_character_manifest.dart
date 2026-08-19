import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 대화 장면 캐릭터 상태 에셋 매니페스트.
///
/// 원본은 `assets/images/dialogue/banggui/states.json`이고, 그 파일 상단 주석이 계약을 적어 둔다.
/// 여기에는 **에셋 매핑만** 담긴다 - 대사·충족 기준·미션·턴 수는 서버 응답에서 온다.
class DialogueCharacterManifest {
  const DialogueCharacterManifest._(
    this._scenes,
    this._confusedValidity,
    this.closingViaHold,
  );

  static const String assetPath = 'assets/images/dialogue/banggui/states.json';

  final Map<String, DialogueSceneStates> _scenes;
  final Set<String> _confusedValidity;

  /// 모든 요소를 채운 턴에서 `closingVia` 표정을 보여주는 시간.
  final Duration closingViaHold;

  static DialogueCharacterManifest? _cached;

  /// 한 번 읽어 캐시한다. 장면을 오갈 때마다 번들을 다시 파싱할 이유가 없다.
  static Future<DialogueCharacterManifest> load() async {
    final DialogueCharacterManifest? cached = _cached;
    if (cached != null) return cached;
    final String raw = await rootBundle.loadString(assetPath);
    return _cached = parse(raw);
  }

  /// 테스트에서 번들 없이 쓰려고 열어 둔다.
  static DialogueCharacterManifest parse(String raw) {
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> scenes =
        (json['scenes'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return DialogueCharacterManifest._(
      scenes.map(
        (String sceneId, dynamic value) =>
            MapEntry<String, DialogueSceneStates>(
              sceneId,
              DialogueSceneStates._fromJson(value as Map<String, dynamic>),
            ),
      ),
      ((json['confusedValidity'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => e as String)
          .toSet(),
      Duration(
        milliseconds: (json['closingViaHoldMs'] as num?)?.toInt() ?? 1200,
      ),
    );
  }

  /// 장면 UUID로 찾고, 없으면 장면 순번으로 되짚는다.
  ///
  /// 콘텐츠 시드를 다시 심으면 UUID가 갈릴 수 있는데, 그때 캐릭터가 통째로 사라지는 것보다
  /// 순번으로라도 맞는 그림을 내보내는 편이 낫다. 둘 다 못 찾으면 null - 호출부가 기존
  /// 배경 한 장짜리 화면으로 되돌아간다.
  DialogueSceneStates? sceneFor({String? sceneId, int? sceneOrder}) {
    final DialogueSceneStates? byId = sceneId == null ? null : _scenes[sceneId];
    if (byId != null) return byId;
    if (sceneOrder == null) return null;
    for (final DialogueSceneStates scene in _scenes.values) {
      if (scene.sceneOrder == sceneOrder) return scene;
    }
    return null;
  }

  /// 인물 식별자로 그 인물이 서 있는 장면을 찾는다.
  ///
  /// 자유 대화는 장면이 아니라 **인물**로 들어온다 - 매니페스트는 장면 단위지만
  /// 장면마다 `characterId`가 적혀 있어 되짚을 수 있다. 시드를 다시 심어 UUID가
  /// 갈리면 이름으로 한 번 더 찾는다(같은 이야기 안에서 이름은 유일하다).
  /// 둘 다 못 찾으면 null - 호출부가 서버 썸네일 한 장짜리 화면으로 되돌아간다.
  DialogueSceneStates? sceneForCharacter({String? characterId, String? name}) {
    if (characterId != null && characterId.isNotEmpty) {
      for (final DialogueSceneStates scene in _scenes.values) {
        if (scene.characterId == characterId) return scene;
      }
    }
    if (name != null && name.isNotEmpty) {
      for (final DialogueSceneStates scene in _scenes.values) {
        if (scene.characterName == name) return scene;
      }
    }
    return null;
  }

  /// 서버 `analysis.utteranceValidity`가 당황 표정으로 바꿔야 하는 값인지.
  bool isConfusedValidity(String? validity) =>
      validity != null && _confusedValidity.contains(validity);
}

/// 장면 하나의 상태 집합.
class DialogueSceneStates {
  const DialogueSceneStates._({
    required this.sceneOrder,
    required this.label,
    required this.characterName,
    required this.characterId,
    required this.dir,
    required this.background,
    required this.openingState,
    required this.closingState,
    required this.closingVia,
    required this.confusedState,
    required this.states,
    required this.statePriority,
    required this.elementToState,
    required this.emotionToState,
  });

  factory DialogueSceneStates._fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawStates =
        (json['states'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, String> assets = <String, String>{};
    final Map<String, String> elementToState = <String, String>{};

    for (final MapEntry<String, dynamic> entry in rawStates.entries) {
      final Map<String, dynamic> state = entry.value as Map<String, dynamic>;
      assets[entry.key] = state['asset'] as String;
      for (final dynamic element
          in (state['elements'] as List<dynamic>?) ?? const <dynamic>[]) {
        elementToState[element as String] = entry.key;
      }
    }

    return DialogueSceneStates._(
      sceneOrder: (json['sceneOrder'] as num).toInt(),
      label: json['label'] as String? ?? '',
      characterName: json['characterName'] as String? ?? '',
      characterId: json['characterId'] as String? ?? '',
      dir: json['dir'] as String,
      background: json['background'] as String,
      openingState: json['openingState'] as String,
      closingState: json['closingState'] as String,
      closingVia: json['closingVia'] as String?,
      confusedState: json['confusedState'] as String?,
      states: assets,
      statePriority:
          ((json['statePriority'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic e) => e as String)
              .toList(growable: false),
      elementToState: elementToState,
      emotionToState:
          ((json['emotions'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{})
              .map(
                (String emotion, dynamic state) =>
                    MapEntry<String, String>(emotion, state as String),
              ),
    );
  }

  final int sceneOrder;
  final String label;
  final String characterName;

  /// 이 장면에 서는 인물의 DB 식별자. 자유 대화가 인물로 표정 에셋을 찾는
  /// 유일한 열쇠다. 매니페스트에 안 적혀 있으면 빈 문자열.
  final String characterId;

  final String dir;
  final String background;
  final String openingState;
  final String closingState;

  /// 모든 요소를 채운 턴에 잠시 거쳐 가는 상태. null이면 곧바로 [closingState]로 간다.
  final String? closingVia;

  /// 놀림·주제 이탈·불명확 발화에 쓸 상태. null이면 표정을 바꾸지 않고 현재 상태를 유지한다
  /// (대화4가 그렇게 확정됐다).
  final String? confusedState;

  /// 상태 키 -> 에셋 파일명
  final Map<String, String> states;

  /// 한 턴에 여러 상태가 후보일 때 앞쪽이 이긴다.
  final List<String> statePriority;

  /// 사고 요소 -> 상태 키. 여러 요소가 한 상태를 가리킬 수 있다
  /// (대화2의 PERSPECTIVE·REASON -> considering).
  final Map<String, String> elementToState;

  /// 서버 감정(`CharacterEmotion` 6종) -> 상태 키. **후속 자유 대화 전용**이다.
  ///
  /// 자유 대화에는 사고 요소도 진행 판단도 없어서 표정을 고를 근거가 감정
  /// 하나뿐이다. 서버가 주는 값은 `NEUTRAL/HAPPY/SAD/WORRIED/SURPRISED/RELIEVED`
  /// 인데 이 표를 거치지 않으면 상태 키와 한 번도 맞지 않는다 - 그래서 자유
  /// 대화의 표정이 한 번도 바뀌지 않았다.
  ///
  /// 어울리는 얼굴이 없는 감정은 **비워 둔다**(대화4의 SAD·WORRIED·SURPRISED).
  /// 빠진 감정은 표정을 그대로 두는 쪽이고, 아이 말과 무관한 얼굴을 짓는 것보다 낫다.
  final Map<String, String> emotionToState;

  /// 서버 감정에 해당하는 상태 키. 모르는 감정이면 null.
  ///
  /// 옛 서버가 상태 키를 그대로 보내던 시절과도 호환한다 - 값이 이미 상태
  /// 키면 그대로 쓴다.
  String? stateForEmotion(String? emotion) {
    if (emotion == null || emotion.isEmpty) return null;
    final String? mapped = emotionToState[emotion];
    if (mapped != null) return mapped;
    return states.containsKey(emotion) ? emotion : null;
  }

  String get backgroundAsset => '$dir/$background';

  /// 상태 키에 해당하는 에셋 경로. 모르는 키면 null.
  String? assetOf(String? state) {
    final String? file = state == null ? null : states[state];
    return file == null ? null : '$dir/$file';
  }

  /// 미리 캐시해 둘 이미지 전체. 턴이 넘어갈 때 표정이 늦게 뜨는 것을 막는다.
  Iterable<String> get allAssets sync* {
    yield backgroundAsset;
    for (final String file in states.values) {
      yield '$dir/$file';
    }
  }
}
