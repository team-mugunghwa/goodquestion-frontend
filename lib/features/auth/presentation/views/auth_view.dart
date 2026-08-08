import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 보호자 인증 — 이메일·소셜 로그인, 약관·아동 개인정보 동의, 최초 아이 프로필 등록.
///
/// 로그인과 회원가입을 나누지 않습니다. 화면은 이 하나뿐입니다.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutePlaceholderView(path: AppRoutes.auth, title: '보호자 인증');
  }
}
