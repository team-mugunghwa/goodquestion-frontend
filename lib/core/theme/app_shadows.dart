import 'package:flutter/material.dart';

/// 그림자 토큰.
///
/// 검정 그림자를 쓰지 않습니다. 잉크색(`ink900` = `#16233F`)을 옅게 깐 그림자가
/// 파스텔 배경 위에서 회색 때처럼 보이지 않습니다.
///
/// 단계는 **두 개뿐**입니다. Material 의 elevation 0~24 를 쓰지 마세요 —
/// 4명이 각자 다른 숫자를 고르면 화면마다 카드가 다르게 떠 있습니다.
abstract final class AppShadows {
  /// 바닥에 놓인 것. 카드, 목록 항목, 하단 내비.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x1416233F), // ink900 8%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// 떠 있는 것. 말풍선, 시트, 상점 카드, 누를 수 있는 큰 버튼.
  static const List<BoxShadow> lift = [
    BoxShadow(
      color: Color(0x1F16233F), // ink900 12%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// 별가루가 붙은 요소(획득 배지, 구매 가능한 아이템)의 발광.
  /// 그림자 대신 빛입니다 — 아래가 아니라 사방으로 퍼집니다.
  static const List<BoxShadow> stardustGlow = [
    BoxShadow(color: Color(0x66FFC24B), blurRadius: 28, spreadRadius: 2),
  ];

  /// 밤 배경(내 행성·완료 화면) 위의 카드 면.
  ///
  /// 어두운 배경에서는 그림자가 보이지 않습니다. 흰 카드를 얹으면 너무 튀고요.
  /// 반투명한 흰 면 + 밝은 테두리로 분리합니다.
  static const Color nightSurface = Color(0x1FFFFFFF);
  static const Color nightBorder = Color(0x33FFFFFF);
}
