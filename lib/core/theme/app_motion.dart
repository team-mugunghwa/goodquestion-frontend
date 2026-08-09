import 'package:flutter/material.dart';

/// 모션 토큰.
///
/// 이 앱에서 애니메이션은 장식이 아니라 **차례를 알려주는 신호**입니다.
/// 아이는 글을 읽지 않으므로 "지금 내 차례"를 화면 변화와 소리로 압니다.
/// (PRD F-05 완료 조건)
///
/// ## 접근성
///
/// `MediaQuery.disableAnimationsOf(context)` 가 true 면 [duration] 대신
/// [Duration.zero] 를 쓰세요. 전정기관이 예민한 아이가 있습니다.
/// 편의 함수 [respect] 를 쓰면 됩니다.
abstract final class AppDurations {
  /// 눌린 느낌. 버튼 스케일, 리플.
  static const Duration tap = Duration(milliseconds: 120);

  /// 상태 변화. 색, 아이콘 교체, 칩 등장.
  static const Duration quick = Duration(milliseconds: 200);

  /// 기본값. 화면 전환, 카드 이동, 말풍선 등장.
  static const Duration normal = Duration(milliseconds: 320);

  /// 차례 전환. 캐릭터턴 → 아이턴처럼 아이가 알아채야 하는 변화.
  /// 일부러 느립니다.
  static const Duration turn = Duration(milliseconds: 600);

  /// 별가루 낙하, 완주 축하. 한 세션에 한 번뿐인 연출.
  static const Duration celebrate = Duration(milliseconds: 1200);

  /// 캐릭터 대기(생각하는) 모션의 한 주기. 응답이 3초 넘게 걸릴 때
  /// 공백을 메웁니다. (PRD §6 응답 지연)
  static const Duration thinkingLoop = Duration(milliseconds: 1400);

  /// 무응답 힌트가 나가기까지. (PRD 예외 경로)
  static const Duration idleHint = Duration(seconds: 30);
}

/// 가속도 곡선.
///
/// **`Curves.linear` 를 쓰지 마세요.** 등속 운동은 기계처럼 보입니다.
abstract final class AppCurves {
  /// 기본. 들어오고 나가는 대부분의 것.
  static const Curve standard = Curves.easeOutCubic;

  /// 아이 화면에서 뭔가가 등장할 때. 끝에서 살짝 튀어 장난감처럼 보입니다.
  static const Curve playful = Curves.easeOutBack;

  /// 사라질 때. 등장보다 빠르게 빠집니다.
  static const Curve exit = Curves.easeInCubic;

  /// 별가루가 떨어져 잔액에 합쳐질 때.
  static const Curve fall = Curves.easeInOutCubic;
}

/// 애니메이션 시간을 접근성 설정에 맞춰 보정합니다.
///
/// ```dart
/// AnimatedContainer(duration: respect(context, AppDurations.normal), ...)
/// ```
Duration respect(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
