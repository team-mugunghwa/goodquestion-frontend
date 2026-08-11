import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 액세스 토큰 저장소. 로그인 유지가 꺼져 있으면 현재 실행 중에만 보관합니다.
class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _key = 'goodquestion_access_token';
  final FlutterSecureStorage _secureStorage;
  String? _sessionToken;

  Future<String?> read() async {
    if (_sessionToken != null) return _sessionToken;
    try {
      return await _secureStorage.read(key: _key);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> save(String token, {required bool persistent}) async {
    _sessionToken = token;
    try {
      if (persistent) {
        await _secureStorage.write(key: _key, value: token);
      } else {
        await _secureStorage.delete(key: _key);
      }
    } on MissingPluginException {
      // 웹 플러그인이 아직 등록되지 않은 개발 환경에서는 현재 세션만 유지합니다.
    } on PlatformException {
      // 보안 저장소를 사용할 수 없어도 현재 실행 중인 로그인은 유지합니다.
    }
  }

  Future<void> clear() async {
    _sessionToken = null;
    try {
      await _secureStorage.delete(key: _key);
    } on MissingPluginException {
      // 저장된 값이 없으므로 메모리 세션 초기화만으로 로그아웃을 완료합니다.
    } on PlatformException {
      // 저장소 접근 실패가 로그아웃 자체를 막지 않게 합니다.
    }
  }
}
