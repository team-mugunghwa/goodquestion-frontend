import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/auth/data/datasources/auth_token_store.dart';
import 'package:mocktail/mocktail.dart';

/// 브라우저 보안 저장소 흉내 - 페이지 새로고침을 "저장소는 그대로, 새
/// AuthTokenStore 인스턴스"로 재현하기 위한 것입니다.
class _FakeSecureStorage extends Mock implements FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 이 테스트는 flutter_secure_storage 플랫폼 채널이 없는 환경에서
  // 돌아갑니다 — MissingPluginException 을 잡아 메모리 세션으로만
  // 동작하는 경로를 그대로 검증합니다. 저장소 자체보다 "두 토큰을 한 쌍으로
  // 다루는지"가 이 테스트의 핵심입니다.

  test('저장한 두 토큰을 그대로 읽는다', () async {
    final store = AuthTokenStore();

    await store.save('access-1', 'refresh-1', persistent: false);

    expect(await store.read(), 'access-1');
    expect(await store.readRefresh(), 'refresh-1');
  });

  test('재발급 응답으로 두 토큰을 모두 새 값으로 바꾼다', () async {
    final store = AuthTokenStore();
    await store.save('access-1', 'refresh-1', persistent: false);

    await store.saveRefreshed(
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
    );

    expect(await store.read(), 'access-2');
    expect(
      await store.readRefresh(),
      'refresh-2',
      reason: '액세스만 갈아 끼우고 리프레시를 묵히면 다음 재발급이 실패합니다',
    );
  });

  test('로그인 유지로 저장한 토큰은 저장소에 남는다', () async {
    final storage = _FakeSecureStorage();
    final store = AuthTokenStore(secureStorage: storage);

    await store.save('access-1', 'refresh-1', persistent: true);

    expect(storage.values.values, contains('access-1'));
    expect(storage.values.values, contains('refresh-1'));
  });

  test('새로고침 뒤의 재발급이 로그인 유지를 잊지 않는다', () async {
    // 사고 재현: "로그인 유지"로 저장 -> 페이지 새로고침(새 인스턴스,
    // 메모리의 _persistent 리셋) -> 30분 뒤 액세스 만료 -> 재발급.
    // 재발급 저장이 로그인 유지를 잊으면 저장소 토큰을 지워 버려서,
    // 다음 새로고침 때 세션이 통째로 사라진다 - 리프레시 토큰은 1회용
    // 회전이라 옛 토큰으로도 복구할 수 없다.
    final storage = _FakeSecureStorage();
    final beforeReload = AuthTokenStore(secureStorage: storage);
    await beforeReload.save('access-1', 'refresh-1', persistent: true);

    final afterReload = AuthTokenStore(secureStorage: storage); // 새로고침
    expect(await afterReload.readRefresh(), 'refresh-1');
    await afterReload.saveRefreshed(
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
    );

    expect(
      storage.values.values,
      containsAll(<String>['access-2', 'refresh-2']),
      reason: '재발급이 저장소를 비우면 다음 새로고침 때 로그인이 풀립니다',
    );

    // 다음 새로고침에서도 세션이 이어져야 한다.
    final secondReload = AuthTokenStore(secureStorage: storage);
    expect(await secondReload.read(), 'access-2');
    expect(await secondReload.readRefresh(), 'refresh-2');
  });

  test('로그인 유지를 끄면 재발급도 저장소에 쓰지 않는다', () async {
    final storage = _FakeSecureStorage();
    final store = AuthTokenStore(secureStorage: storage);
    await store.save('access-1', 'refresh-1', persistent: false);

    await store.saveRefreshed(
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
    );

    expect(storage.values, isEmpty, reason: '유지를 끈 세션의 토큰이 저장소에 남으면 안 됩니다');
    expect(await store.read(), 'access-2');
  });

  test('로그아웃하면 두 토큰이 모두 사라진다', () async {
    final store = AuthTokenStore();
    await store.save('access-1', 'refresh-1', persistent: false);

    await store.clear();

    expect(await store.read(), isNull);
    expect(await store.readRefresh(), isNull);
  });
}
