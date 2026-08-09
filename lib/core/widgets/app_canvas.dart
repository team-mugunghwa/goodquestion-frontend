import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 화면의 바탕.
///
/// 이 앱에는 바탕이 **세 종류**뿐입니다. 화면을 새로 만들 때 어느 바탕인지
/// 먼저 정하고, `Scaffold` 의 `body` 를 이걸로 감싸세요.
/// (`Scaffold.backgroundColor` 는 `Colors.transparent` 로 둡니다)
///
/// | 생성자 | 쓰는 화면 |
/// |---|---|
/// | [AppCanvas.day] | 홈 · 이야기 목록/상세 · 말하기 후 활동 · 단어장 |
/// | [AppCanvas.night] | 완료(별가루 획득) · 내 행성 · 상점 |
/// | [AppCanvas.guardian] | 로그인 · 마이페이지 · 리포트 · 설정 |
///
/// 낮에서 시작해 밤에서 끝나는 건 의도한 흐름입니다. 아이는 홈에서 이야기를
/// 골라(낮) 별가루를 받고 자기 행성으로 갑니다(밤). 배경이 바뀌는 것 자체가
/// "오늘 이야기를 끝냈다"는 신호라서, 순서를 섞으면 그 신호가 사라집니다.
///
/// 장면 진행 화면(`/play/:sessionId`)은 예외입니다 — 장면 이미지가 화면을
/// 채우므로 바탕을 깔지 않습니다.
class AppCanvas extends StatelessWidget {
  const AppCanvas._({
    super.key,
    required this.child,
    this.gradient,
    this.color,
  });

  /// 낮 — 아이 화면 기본.
  const AppCanvas.day({Key? key, required Widget child})
    : this._(key: key, child: child, gradient: AppColors.dayGradient);

  /// 밤 — 별가루와 행성.
  const AppCanvas.night({Key? key, required Widget child})
    : this._(key: key, child: child, gradient: AppColors.nightGradient);

  /// 보호자·시스템. 읽는 화면이라 그라디언트를 쓰지 않습니다.
  const AppCanvas.guardian({Key? key, required Widget child})
    : this._(key: key, child: child, color: AppColors.guardianCanvas);

  final Widget child;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient, color: color),
      child: child,
    );
  }
}
