import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/auth/data/datasources/auth_token_store.dart';

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

  test('로그아웃하면 두 토큰이 모두 사라진다', () async {
    final store = AuthTokenStore();
    await store.save('access-1', 'refresh-1', persistent: false);

    await store.clear();

    expect(await store.read(), isNull);
    expect(await store.readRefresh(), isNull);
  });
}
