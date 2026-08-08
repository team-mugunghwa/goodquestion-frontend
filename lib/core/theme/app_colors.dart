import 'package:flutter/material.dart';

/// 브랜드 컬러 토큰.
///
/// 로고(말풍선 Q)의 그라디언트에서 뽑았습니다.
/// 왼쪽 위 민트블루 → 오른쪽 아래 라이트그린으로 흐르고,
/// 워드마크는 "Good"(그린) + "Question"(블루) 로 나뉩니다.
///
/// ⚠️ 위젯에서 이 값을 직접 쓰는 건 **로고·스플래시·강조 요소일 때만** 입니다.
/// 일반적인 UI 색은 `Theme.of(context).colorScheme.*` 를 쓰세요.
/// 그래야 다크 모드에서 자동으로 대비가 맞습니다.
abstract final class AppColors {
  /// 워드마크 "Question" 의 파랑. 앱의 주 색상.
  static const Color brandBlue = Color(0xFF83B9DD);

  /// 워드마크 "Good" 의 초록. 보조 색상.
  static const Color brandGreen = Color(0xFFA0CE99);

  /// Q 마크 왼쪽 위의 민트.
  static const Color brandMint = Color(0xFF8FD4E3);

  /// Material 3 팔레트 생성용 시드.
  ///
  /// 로고 색을 그대로 시드로 쓰면 채도가 너무 낮아 버튼·텍스트 대비가
  /// 부족해집니다. 같은 색상(hue)을 유지한 채 채도만 올린 값입니다.
  static const Color seed = Color(0xFF4E9BC9);

  /// 로고와 같은 방향의 그라디언트. 스플래시·헤더·엠티 상태 일러스트에 사용.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandMint, brandBlue, brandGreen],
    stops: [0.0, 0.45, 1.0],
  );
}
