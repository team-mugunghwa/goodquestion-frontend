import '../../domain/entities/play_session.dart';
import 'dialogue_character_manifest.dart';

/// 캐릭터가 지금 무엇을 하고 있는지. 표정과 별개의 축이고, 에셋을 따로 두지 않는다 -
/// 현재 표정 이미지 위에 코드 모션만 바꿔 얹는다.
enum DialogueActivity { idle, listening, thinking, speaking }

/// 한 턴의 결과로 정해진 표정. [via]가 있으면 그 표정을 잠시 보여준 뒤 [state]로 넘어간다.
class DialogueStateTransition {
  const DialogueStateTransition(this.state, {this.via});

  final String state;

  /// 모든 요소를 채우고 닫히는 턴에서 거쳐 가는 표정.
  final String? via;

  @override
  String toString() => via == null ? state : '$via -> $state';
}

/// 서버 응답만으로 캐릭터 표정을 정하는 규칙.
///
/// 상태를 들고 있는 이유는 하나뿐이다 - "이번 턴에 **새로** 충족된 요소"를 알려면 직전 턴의
/// 누적을 기억해야 한다. 서버 `progress.accumulatedElements`는 이번 턴이 반영된 뒤의 값이라
/// 그 자체로는 무엇이 새로 들어왔는지 알 수 없다.
///
/// 판정 순서는 콘텐츠 확정안(충족요건/대화{1,2,3,4}_충족조건.md)을 따른다.
///   1. 닫히는 턴이면 closing (closingVia를 거쳐서)
///   2. 놀림·주제 이탈·불명확이면 confused
///   3. 이번 턴에 새로 충족된 요소가 있으면 statePriority에서 가장 앞선 상태
///   4. 그 외에는 현재 표정 유지
class DialogueCharacterStateMachine {
  DialogueCharacterStateMachine(this.scene, this.manifest)
    : _current = scene.openingState;

  final DialogueSceneStates scene;
  final DialogueCharacterManifest manifest;

  String _current;
  Set<String> _seenElements = <String>{};

  /// 지금 보여 줄 표정 키.
  String get current => _current;

  String? get currentAsset => scene.assetOf(_current);

  /// 이어하기로 들어와 앞선 턴의 누적이 이미 있는 경우. 그 요소들은 "새로 충족"으로 치지 않는다.
  void primeAccumulated(Iterable<String> accumulated) {
    _seenElements = accumulated.toSet();
  }

  /// 장면이 바뀌었을 때 첫 대사 표정으로 되돌린다.
  void reset() {
    _current = scene.openingState;
    _seenElements = <String>{};
  }

  /// 표정을 직접 옮긴다. [DialogueStateTransition.via]를 재생한 뒤 최종 상태로 넘길 때 쓴다.
  void moveTo(String state) {
    if (scene.states.containsKey(state)) _current = state;
  }

  /// 턴 결과를 받아 다음 표정을 정한다. 바뀔 게 없으면 null.
  DialogueStateTransition? apply(PlayTurnResult result) {
    final PlayAnalysis? analysis = result.analysis;
    final PlayProgress? progress = result.progress;

    // 이번 턴에 새로 들어온 요소. accumulated가 있으면 그것이 기준이고(서버가 후처리로 걸러낸
    // 최종 누적이다), 없으면 detectedElements로 대신한다.
    final Set<String> accumulated =
        progress?.accumulatedElements.toSet() ?? <String>{};
    final Set<String> fresh = accumulated.isEmpty
        ? (analysis?.detectedElements.toSet() ?? <String>{}).difference(
            _seenElements,
          )
        : accumulated.difference(_seenElements);
    _seenElements = _seenElements.union(accumulated).union(fresh);

    // 1. 닫히는 턴. 종료 판정은 서버 몫이라 mode와 sceneTransition 둘 다 본다.
    if (result.hasSceneTransition || (progress?.isClosing ?? false)) {
      final String? via = scene.closingVia;
      final bool viaIsMeaningful =
          via != null && via != scene.closingState && via != _current;
      return DialogueStateTransition(
        scene.closingState,
        via: viaIsMeaningful ? via : null,
      );
    }

    // 2. 놀림·주제 이탈·불명확. confusedState가 없는 장면(대화4)은 표정을 바꾸지 않는다.
    if (manifest.isConfusedValidity(analysis?.utteranceValidity)) {
      final String? confused = scene.confusedState;
      if (confused == null) return null;
      return _moved(confused);
    }

    // 3. 새로 충족된 요소 -> 우선순위가 가장 앞선 상태.
    final String? next = _pickByPriority(fresh);
    if (next != null) return _moved(next);

    // 4. 진전이 없는 턴은 현재 표정을 유지한다. 되묻는 중에 표정이 흔들리면 산만해진다.
    return null;
  }

  DialogueStateTransition? _moved(String state) {
    if (state == _current) return null;
    _current = state;
    return DialogueStateTransition(state);
  }

  /// 한 턴에 요소가 여러 개 들어오면 statePriority 앞쪽이 이긴다.
  String? _pickByPriority(Set<String> freshElements) {
    if (freshElements.isEmpty) return null;
    final Set<String> candidates = freshElements
        .map((String element) => scene.elementToState[element])
        .whereType<String>()
        .toSet();
    if (candidates.isEmpty) return null;

    for (final String state in scene.statePriority) {
      if (candidates.contains(state)) return state;
    }
    // 우선순위 목록에 없는 상태면 하나만 있을 때에 한해 받아들인다. 순서를 임의로 정하지 않는다.
    return candidates.length == 1 ? candidates.first : null;
  }
}
