import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../theme/app_colors.dart';

/// 코드로 그린 이야기 표지.
///
/// 아이는 글이 아니라 **그림으로 카드를 고릅니다.** 그런데 표지 일러스트
/// 에셋이 아직 없어서, 빈 자리를 회색 사각형이나 밋밋한 그라디언트로 두면
/// 화면이 "만들다 만" 것처럼 보입니다. 그래서 표지를 **주제별 파스텔 패턴 +
/// 말풍선 모티프**로 코드로 그립니다. ([topicTag] 가 색과 글리프를 정합니다)
///
/// 가드레일:
/// - 면은 차가운 파스텔([AppColors.brandMint]/[brandBlue]/[brandGreen])만.
///   따뜻한 색(노랑)은 별가루 전용, 빨강은 아이 화면 금지라 여기 쓰지 않습니다.
/// - 글리프·강조는 대비가 나오는 `*Deep` 로.
/// - 정적입니다(모션 없음). 아이의 주의는 캐릭터에게 가야 합니다.
///
/// > 나중에 진짜 표지 일러스트 에셋이 들어오면 [StoryThumbnail] 이 이미지를
/// > 먼저 쓰고, 이 커버는 그대로 폴백으로 남습니다.
class StoryCover extends StatelessWidget {
  const StoryCover({super.key, required this.palette, this.motifIcon});

  /// 주제별 색·글리프 묶음. [StoryCoverPalette.forTopic] 로 만드세요.
  final StoryCoverPalette palette;

  /// 워터마크 글리프를 강제로 바꾸고 싶을 때. `null` 이면 팔레트 기본값.
  final IconData? motifIcon;

  @override
  Widget build(BuildContext context) {
    final IconData glyph = motifIcon ?? palette.motif ?? AppIcons.stories;
    return ClipRect(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double shortest = math.min(
            c.maxWidth.isFinite ? c.maxWidth : 200,
            c.maxHeight.isFinite ? c.maxHeight : 200,
          );
          // 작은 원형(행성 썸네일·칩)에서는 패턴을 줄이고 글리프를 가운데로.
          final bool compact = shortest < 120;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                painter: _CoverPainter(palette: palette, compact: compact),
              ),
              if (compact)
                Center(
                  child: Icon(
                    glyph,
                    size: shortest * 0.42,
                    color: palette.accent.withValues(alpha: 0.85),
                  ),
                )
              else
                Positioned(
                  right: -shortest * 0.06,
                  bottom: -shortest * 0.08,
                  child: Icon(
                    glyph,
                    size: shortest * 0.62,
                    color: palette.accent.withValues(alpha: 0.22),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 표지 한 장의 색·글리프.
@immutable
class StoryCoverPalette {
  const StoryCoverPalette({
    required this.top,
    required this.bottom,
    required this.accent,
    this.motif,
  });

  /// 대각선 그라디언트의 시작(좌상)·끝(우하) 파스텔.
  final Color top;
  final Color bottom;

  /// 글리프·언덕에 쓰는 진한 색. 대비가 나와야 하므로 `*Deep`.
  final Color accent;

  /// 주제를 암시하는 워터마크 글리프. `null` 이면 [StoryCover] 가 책 아이콘.
  final IconData? motif;

  /// 주제 이름(한글)으로 표지 팔레트를 고릅니다.
  ///
  /// 홈·이야기 목록의 `topicTag` / `topicLabel` 이 그대로 들어옵니다.
  /// 모르는 주제·`null` 이면 브랜드 기본 표지로 떨어집니다.
  static StoryCoverPalette forTopic(String? topic) {
    switch (topic) {
      case '우정':
        return const StoryCoverPalette(
          top: AppColors.brandGreen,
          bottom: AppColors.brandMint,
          accent: AppColors.brandGreenDeep,
          motif: AppIcons.like,
        );
      case '용기':
        return const StoryCoverPalette(
          top: AppColors.brandBlue,
          bottom: AppColors.brandMint,
          accent: AppColors.brandBlueDeep,
          motif: AppIcons.topicAdventure,
        );
      case '가족':
        return const StoryCoverPalette(
          top: AppColors.brandMint,
          bottom: AppColors.brandGreen,
          accent: AppColors.brandGreenDeep,
          motif: AppIcons.topicFolk,
        );
      case '모험':
        return const StoryCoverPalette(
          top: AppColors.brandBlue,
          bottom: AppColors.brandGreen,
          accent: AppColors.brandBlueDeep,
          motif: AppIcons.topicAdventure,
        );
      case '동물':
        return const StoryCoverPalette(
          top: AppColors.brandGreen,
          bottom: AppColors.brandBlue,
          accent: AppColors.brandGreenDeep,
          motif: AppIcons.topicAnimal,
        );
      case '일상':
        return const StoryCoverPalette(
          top: AppColors.brandMint,
          bottom: AppColors.brandBlue,
          accent: AppColors.brandBlueDeep,
          motif: AppIcons.topicDaily,
        );
      case '옛이야기':
        return const StoryCoverPalette(
          top: AppColors.brandBlue,
          bottom: AppColors.brandMint,
          accent: AppColors.brandBlueDeep,
          motif: AppIcons.topicFolk,
        );
      default:
        return const StoryCoverPalette(
          top: AppColors.brandMint,
          bottom: AppColors.brandBlue,
          accent: AppColors.brandBlueDeep,
          motif: AppIcons.stories,
        );
    }
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter({required this.palette, required this.compact});

  final StoryCoverPalette palette;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double s = math.min(w, h);
    final Rect rect = Offset.zero & size;

    // 1) 대각선 파스텔 그라디언트.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.top, palette.bottom],
        ).createShader(rect),
    );

    // 2) 좌상단에서 닿는 흰빛 — 부풀어 오른 면처럼.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.8, -0.9),
          radius: 1.1,
          colors: <Color>[
            AppColors.surface.withValues(alpha: 0.34),
            AppColors.surface.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.7],
        ).createShader(rect),
    );

    if (!compact) {
      // 3) 바닥의 낮은 언덕 — 백드롭과 같은 언어로 표지를 땅에 앉힙니다.
      final Path hill = Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.82)
        ..quadraticBezierTo(w * 0.35, h * 0.72, w * 0.62, h * 0.82)
        ..quadraticBezierTo(w * 0.85, h * 0.90, w, h * 0.80)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        hill,
        Paint()..color = palette.accent.withValues(alpha: 0.14),
      );
    }

    // 4) 이 앱의 서명 — 말풍선 무리(흰빛 + 살짝의 accent).
    if (compact) {
      _bubble(
        canvas,
        Offset(w * 0.24, h * 0.26),
        s * 0.14,
        AppColors.surface.withValues(alpha: 0.4),
        false,
      );
    } else {
      _bubble(
        canvas,
        Offset(w * 0.20, h * 0.24),
        s * 0.16,
        AppColors.surface.withValues(alpha: 0.38),
        true,
      );
      _bubble(
        canvas,
        Offset(w * 0.30, h * 0.60),
        s * 0.10,
        AppColors.surface.withValues(alpha: 0.28),
        true,
      );
      _bubble(
        canvas,
        Offset(w * 0.58, h * 0.30),
        s * 0.075,
        palette.accent.withValues(alpha: 0.16),
        false,
      );
      _bubble(
        canvas,
        Offset(w * 0.80, h * 0.66),
        s * 0.11,
        AppColors.surface.withValues(alpha: 0.22),
        true,
      );
    }
  }

  /// 채운 원 + 왼쪽 아래 작은 꼬리. 로고 말풍선과 같은 방향.
  void _bubble(Canvas canvas, Offset c, double r, Color color, bool tail) {
    final Paint p = Paint()..color = color;
    canvas.drawCircle(c, r, p);
    if (!tail) return;
    final Path t = Path()
      ..moveTo(c.dx - r * 0.55, c.dy + r * 0.45)
      ..lineTo(c.dx - r * 0.95, c.dy + r * 1.05)
      ..lineTo(c.dx - r * 0.10, c.dy + r * 0.80)
      ..close();
    canvas.drawPath(t, p);
  }

  @override
  bool shouldRepaint(_CoverPainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.compact != compact;
}
