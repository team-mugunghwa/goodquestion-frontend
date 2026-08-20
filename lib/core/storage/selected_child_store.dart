import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 지금 고른 아이. **기기에 남겨 두고 앱을 다시 켤 때 되살립니다.**
///
/// 메모리에만 두면 새로고침할 때마다 목록의 첫 아이로 돌아갑니다 - 아이가
/// 둘 이상인 집에서는 매번 다시 고르게 됩니다.
///
/// ## 왜 [AuthTokenStore] 에 끼워 넣지 않는가
///
/// 저장 매체는 같지만(보안 저장소) 지켜야 하는 규칙이 다릅니다. 토큰 저장소는
/// **두 토큰을 한 쌍으로** 다루고 "로그인 유지" 여부에 따라 저장할지 말지가
/// 갈리는 곳입니다. 성격이 다른 값을 섞으면 그 규칙을 읽기 어려워지고,
/// 유지를 끈 로그인에서 선택까지 지워지는 등 원하지 않는 규칙이 딸려옵니다.
///
/// 매체를 보안 저장소로 맞춘 이유는 아이 식별자가 개인정보에 준하는 값이고,
/// 앱이 이미 이 의존성을 쓰고 있어 새로 들일 것이 없기 때문입니다.
///
/// 마이페이지가 아니라 core 에 두는 이유: 고른 아이는 홈·이야기·행성·단어장·
/// 리포트가 모두 보는 앱 전체의 값이고, **로그아웃(인증)** 이 지워야 하는
/// 값이기도 합니다. 한 기능 안에 두면 다른 기능이 그 기능을 거꾸로 참조하게
/// 됩니다.
///
/// ## 동기 getter
///
/// 홈·이야기·리포트 등 여러 화면이 `selectedChildId` 를 **동기로** 읽습니다.
/// 그래서 앱 시작 때 [load] 로 한 번 읽어 메모리에 들고, 이후에는 그 값을
/// 돌려줍니다. 쓰기는 메모리와 저장소를 함께 갱신합니다.
class SelectedChildStore {
  SelectedChildStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _key = 'goodquestion_selected_child_id';

  final FlutterSecureStorage _secureStorage;
  String? _cached;

  /// 지금 고른 아이. [load] 전에는 null 입니다.
  String? get value => _cached;

  /// 앱 시작 때 한 번. 저장소를 못 읽어도 앱은 그대로 뜹니다 - 그때는
  /// 목록의 첫 아이로 시작합니다.
  Future<String?> load() async {
    try {
      _cached = await _secureStorage.read(key: _key);
    } on MissingPluginException {
      _cached = null;
    } on PlatformException {
      _cached = null;
    }
    return _cached;
  }

  Future<void> save(String childId) async {
    if (_cached == childId) return;
    _cached = childId;
    try {
      await _secureStorage.write(key: _key, value: childId);
    } on MissingPluginException {
      // 저장이 안 돼도 이번 실행 동안은 고른 아이가 유지됩니다.
    } on PlatformException {
      // 같은 이유로 삼킵니다 - 저장 실패가 전환 자체를 막지 않게 합니다.
    }
  }

  /// 로그아웃 때 부릅니다. **안 지우면 다음 사용자가 남의 아이를 봅니다.**
  Future<void> clear() async {
    _cached = null;
    try {
      await _secureStorage.delete(key: _key);
    } on MissingPluginException {
      // 지울 값이 없으므로 메모리 초기화로 충분합니다.
    } on PlatformException {
      // 저장소 접근 실패가 로그아웃을 막지 않게 합니다.
    }
  }
}
