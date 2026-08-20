import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/storage/selected_child_store.dart';

/// 고른 아이가 기기에 남아 새로고침을 견디는지. 진짜 보안 저장소는 단위
/// 테스트에 채널이 없어 못 쓰므로, **플러그인이 없을 때도 앱이 죽지 않는지**를
/// 봅니다(그 경우 이번 실행 동안만 유지됩니다).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('플러그인이 없어도 이번 실행 동안은 선택이 유지된다', () async {
    final SelectedChildStore store = SelectedChildStore();

    expect(await store.load(), isNull);
    await store.save('child-2');

    expect(store.value, 'child-2');
  });

  test('지우면 값이 사라진다 - 다음 사용자가 남의 아이를 보면 안 된다', () async {
    final SelectedChildStore store = SelectedChildStore();
    await store.save('child-2');

    await store.clear();

    expect(store.value, isNull);
  });
}
