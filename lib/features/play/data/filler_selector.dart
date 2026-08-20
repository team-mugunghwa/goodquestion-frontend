import 'dart:math';

import 'filler_catalog.dart';

/// 이번에 어떤 맞장구를 들려줄지 고르는 규칙.
///
/// 화면(`play_view.dart`)에 두지 않고 따로 뺐습니다 - [SttChoiceSelector] 와
/// 같은 이유입니다. 규칙이 순수해야 위젯을 띄우지 않고 표로 검증할 수 있고,
/// 나중에 문장 테이블이 서버로 옮겨 가도 [FillerCatalog] 만 바꿔 끼우면 됩니다.
///
/// **셔플 백**입니다 - 후보를 한 번 섞어 하나씩 꺼내 쓰고, 다 쓰면 다시 섞습니다.
///
/// 순수 무작위로 뽑지 않는 이유: 후보가 4개면 연달아 같은 것이 나올 확률이
/// 25%입니다. 한 세션의 대화 턴이 20회 남짓이라 평균 다섯 번은 같은 맞장구를
/// 두 번 잇달아 듣게 되는데, 아이는 그걸 정확히 알아챕니다.
///
/// 단순 순환(0,1,2,3,0,1,2,3…)도 쓰지 않습니다 - 순서가 뻔하고, 장면이 바뀔
/// 때마다 늘 같은 것으로 시작해 "첫 맞장구는 언제나 그거"가 됩니다.
///
/// 백은 **장면별로** 따로 둡니다. 장면마다 캐릭터가 달라 후보가 아예 다른
/// 목록이고, 한 장면에서 쓴 것이 다른 장면의 순서를 흔들 이유가 없습니다.
class FillerSelector {
  /// [random] 은 테스트에서 시드를 고정하려고 받습니다 - 안 그러면 "같은 것이
  /// 연달아 나오지 않는다"를 확인할 방법이 없습니다.
  FillerSelector({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 장면 -> 아직 안 쓴 후보의 인덱스. **뒤에서부터** 꺼냅니다.
  final Map<int, List<int>> _bags = <int, List<int>>{};

  /// 장면 -> 직전에 낸 후보의 인덱스. 백을 다시 섞을 때 경계에서 같은 것이
  /// 이어지지 않게 하는 데만 씁니다.
  final Map<int, int> _lastIndex = <int, int>{};

  /// 이 장면에서 지금 들려줄 맞장구. 음성이 없는 장면이면 `null` 입니다 -
  /// 그때는 아무 소리도 내지 않습니다.
  DialogueFiller? next(int? sceneOrder) {
    if (!FillerCatalog.supports(sceneOrder)) return null;
    final int scene = sceneOrder!;
    final List<DialogueFiller> pool =
        FillerCatalog.byScene[scene] ?? const <DialogueFiller>[];
    if (pool.isEmpty) return null;

    final List<int> bag = _bags[scene] ??= <int>[];
    if (bag.isEmpty) _refill(bag, pool.length, _lastIndex[scene]);

    final int index = bag.removeLast();
    _lastIndex[scene] = index;
    return pool[index];
  }

  void _refill(List<int> bag, int size, int? lastUsed) {
    bag.addAll(List<int>.generate(size, (int i) => i));
    bag.shuffle(_random);
    // 백이 비어 다시 섞은 순간이 인접 중복이 날 수 있는 **유일한** 자리입니다 -
    // 백 안에서는 각 후보가 한 번씩만 나오므로 중복이 구조적으로 불가능합니다.
    // 새 백의 첫 장(= 목록의 맨 뒤)이 직전에 낸 것과 같으면 맨 앞과 맞바꿉니다.
    //
    // 다시 섞지 않고 한 번의 교환으로 끝내는 이유는 종료가 보장되기 때문입니다.
    // 어느 쪽이든 백은 여전히 순열이라 후보별 등장 횟수는 그대로입니다.
    if (size > 1 && lastUsed != null && bag.last == lastUsed) {
      final int first = bag.first;
      bag[0] = bag.last;
      bag[bag.length - 1] = first;
    }
  }
}
