import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 액세스·리프레시 토큰 저장소. 로그인 유지가 꺼져 있으면 현재 실행 중에만
/// 보관합니다.
///
/// 두 토큰을 한 쌍으로 다룹니다 — Access 만 갈아 끼우고 Refresh 를 묵히면
/// 다음 재발급이 실패합니다(리프레시 토큰은 1회용 회전 방식). `save`/
/// `saveRefreshed` 는 항상 두 값을 함께 씁니다.
class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _accessKey = 'goodquestion_access_token';
  static const String _refreshKey = 'goodquestion_refresh_token';
  final FlutterSecureStorage _secureStorage;
  String? _sessionAccessToken;
  String? _sessionRefreshToken;

  /// 최초 로그인 때 고른 "로그인 유지" 여부. 재발급 때도 그대로 따라야
  /// 하므로 호출부가 매번 다시 넘기지 않게 여기서 기억합니다.
  bool _persistent = false;

  Future<String?> read() async {
    if (_sessionAccessToken != null) return _sessionAccessToken;
    try {
      return await _secureStorage.read(key: _accessKey);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<String?> readRefresh() async {
    if (_sessionRefreshToken != null) return _sessionRefreshToken;
    try {
      return await _secureStorage.read(key: _refreshKey);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 로그인 직후 최초 저장. [persistent] 를 기억해 뒀다가 [saveRefreshed] 가
  /// 재사용합니다.
  Future<void> save(
    String accessToken,
    String? refreshToken, {
    required bool persistent,
  }) {
    _persistent = persistent;
    return _write(accessToken, refreshToken);
  }

  /// `POST /auth/refresh` 응답으로 두 토큰을 새 값으로 통째로 바꿉니다.
  /// 리프레시 토큰이 1회용으로 회전되므로 Access 만 갈아 끼우면 다음
  /// 재발급이 실패합니다 — 항상 [refreshToken] 도 함께 넘기세요.
  Future<void> saveRefreshed({
    required String accessToken,
    required String refreshToken,
  }) => _write(accessToken, refreshToken);

  Future<void> _write(String accessToken, String? refreshToken) async {
    _sessionAccessToken = accessToken;
    if (refreshToken != null) _sessionRefreshToken = refreshToken;
    try {
      if (_persistent) {
        await _secureStorage.write(key: _accessKey, value: accessToken);
        if (refreshToken != null) {
          await _secureStorage.write(key: _refreshKey, value: refreshToken);
        }
      } else {
        await _secureStorage.delete(key: _accessKey);
        await _secureStorage.delete(key: _refreshKey);
      }
    } on MissingPluginException {
      // 웹 플러그인이 아직 등록되지 않은 개발 환경에서는 현재 세션만 유지합니다.
    } on PlatformException {
      // 보안 저장소를 사용할 수 없어도 현재 실행 중인 로그인은 유지합니다.
    }
  }

  Future<void> clear() async {
    _sessionAccessToken = null;
    _sessionRefreshToken = null;
    _persistent = false;
    try {
      await _secureStorage.delete(key: _accessKey);
      await _secureStorage.delete(key: _refreshKey);
    } on MissingPluginException {
      // 저장된 값이 없으므로 메모리 세션 초기화만으로 로그아웃을 완료합니다.
    } on PlatformException {
      // 저장소 접근 실패가 로그아웃 자체를 막지 않게 합니다.
    }
  }
}
