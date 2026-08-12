import 'dart:convert';
import 'dart:math';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';

class OAuthAuthorization {
  const OAuthAuthorization({required this.code, required this.redirectUri});

  final String code;
  final String redirectUri;
}

/// 시스템 브라우저에서 공급자 인증을 받고 인가 코드를 회수합니다.
class OAuthCodeProvider {
  Future<OAuthAuthorization> authorize(String provider) async {
    final String clientId = switch (provider) {
      'kakao' => AppConfig.kakaoClientId,
      'google' => AppConfig.googleClientId,
      _ => '',
    };
    if (clientId.isEmpty) {
      throw const UnknownFailure('소셜 로그인 키가 설정되지 않았습니다.');
    }

    final Uri redirect = Uri.parse(AppConfig.oauthRedirectUri);
    final String state = _newState();
    final Uri authorizationUri = switch (provider) {
      'kakao' =>
        Uri.https('kauth.kakao.com', '/oauth/authorize', <String, String>{
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirect.toString(),
          'state': state,
        }),
      'google' =>
        Uri.https('accounts.google.com', '/o/oauth2/v2/auth', <String, String>{
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirect.toString(),
          'scope': 'openid email profile',
          'prompt': 'select_account',
          'state': state,
        }),
      _ => throw const UnknownFailure('지원하지 않는 로그인 방식입니다.'),
    };

    try {
      final String callback = await FlutterWebAuth2.authenticate(
        url: authorizationUri.toString(),
        callbackUrlScheme: redirect.scheme,
      );
      final Uri result = Uri.parse(callback);
      if (result.queryParameters['state'] != state) {
        throw const UnknownFailure('로그인 요청을 확인하지 못했습니다. 다시 시도해 주세요.');
      }
      final String? providerError = result.queryParameters['error'];
      if (providerError != null) {
        throw UnknownFailure(
          providerError == 'access_denied'
              ? '소셜 로그인이 취소되었습니다.'
              : '소셜 로그인을 완료하지 못했습니다. ($providerError)',
        );
      }
      final String? code = result.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const UnknownFailure('로그인 인증 코드를 받지 못했습니다.');
      }
      return OAuthAuthorization(code: code, redirectUri: redirect.toString());
    } on Failure {
      rethrow;
    } on Object {
      throw const UnknownFailure('소셜 로그인을 완료하지 못했습니다.');
    }
  }

  String _newState() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
