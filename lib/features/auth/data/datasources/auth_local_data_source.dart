import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/exceptions.dart';
import '../dtos/auth_dto.dart';

/// 번들된 더미에서 로그인 화면의 선택지를 읽습니다.
/// → `docs/DECISIONS.md` 015
class AuthLocalDataSource {
  const AuthLocalDataSource({this.bundle});

  /// 테스트에서 다른 번들을 끼워 넣기 위해 열어 둔 자리입니다.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  Future<AuthOptionsDto> fetchOptions() async {
    final String raw = await _assets.loadString(AppAssets.authDummy);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const ParseException('인증 더미(auth_screen.json)의 최상위가 객체가 아닙니다.');
    }
    return AuthOptionsDto.fromJson(decoded);
  }
}
