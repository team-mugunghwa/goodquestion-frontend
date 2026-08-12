import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// 홈(낮) 바탕에 깊이를 더하는 장식 레이어.
///
/// [AppCanvas.day] 의 평평한 위→아래 그라디언트만으로는 화면이 비어 보입니다.
/// 캐릭터 일러스트 에셋이 아직 없어서, 이 앱의 서명인 **말풍선 형태**와
/// 낮의 온도감(햇살·구름·언덕)을 순수하게 코드 도형으로 그려 또렷하게 채웁니다.
///
/// 규칙을 지킨 것:
/// - 따뜻한 색(노랑)은 별가루 전용이라 여기 쓰지 않습니다. 전부 차가운
///   파스텔([AppColors.brandMint]/[AppColors.brandBlue]/[AppColors.brandGreen])
///   과 흰빛만 얹습니다.
/// - 콘텐츠 뒤에 깔리는 순수 장식이라 [IgnorePointer] 로 터치를 통과시키고,
///   [RepaintBoundary] 로 본문 리페인트와 분리합니다. 정적(모션 없음)입니다.
class HomeBackdrop extends StatelessWidget {
  const HomeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _BackdropPainter()),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    _paintLightGlow(canvas, w, h);
    _paintClouds(canvas, w, h);
    _paintBubbleMotifs(canvas, w, h);
    _paintHills(canvas, w, h);
  }

  /// 좌상단 민트 햇살 + 우상단 옅은 파랑. 이전보다 진하게 올려 또렷하게.
  void _paintLightGlow(Canvas canvas, double w, double h) {
    final Rect full = Rect.fromLTWH(0, 0, w, h);

    canvas.drawRect(
      full,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                AppColors.brandMint.withValues(alpha: 0.55),
                AppColors.brandMint.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.14, -h * 0.06),
                radius: w * 0.62,
              ),
            ),
    );

    canvas.drawRect(
      full,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                AppColors.brandBlue.withValues(alpha: 0.34),
                AppColors.brandBlue.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 1.0, -h * 0.02),
                radius: w * 0.5,
              ),
            ),
    );
  }

  /// 흰 구름 네 무리. 뭉게진 원을 겹쳐 흐리게, 이전보다 진하게 얹습니다.
  void _paintClouds(Canvas canvas, double w, double h) {
    final Paint cloud = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    _cloud(canvas, cloud, Offset(w * 0.22, h * 0.15), w * 0.06);
    _cloud(canvas, cloud, Offset(w * 0.80, h * 0.10), w * 0.052);
    _cloud(canvas, cloud, Offset(w * 0.93, h * 0.34), w * 0.04);
    _cloud(canvas, cloud, Offset(w * 0.06, h * 0.42), w * 0.036);
  }

  void _cloud(Canvas canvas, Paint paint, Offset c, double r) {
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c.translate(r * 1.1, r * 0.25), r * 0.78, paint);
    canvas.drawCircle(c.translate(-r * 1.05, r * 0.30), r * 0.70, paint);
    canvas.drawCircle(c.translate(r * 0.1, r * 0.55), r * 0.90, paint);
  }

  /// 이 앱의 서명인 말풍선을 배경에 또렷하게 반복합니다. 채운 원 + 꼬리로
  /// 로고 Q 와 같은 형태를 암시하되, 콘텐츠를 방해하지 않게 흰빛·파랑 중알파.
  void _paintBubbleMotifs(Canvas canvas, double w, double h) {
    _bubble(
      canvas,
      Offset(w * 0.87, h * 0.58),
      w * 0.085,
      AppColors.surface.withValues(alpha: 0.66),
    );
    _bubble(
      canvas,
      Offset(w * 0.11, h * 0.56),
      w * 0.055,
      AppColors.brandBlue.withValues(alpha: 0.22),
    );
    _bubble(
      canvas,
      Offset(w * 0.72, h * 0.28),
      w * 0.035,
      AppColors.surface.withValues(alpha: 0.7),
    );
    _bubble(
      canvas,
      Offset(w * 0.40, h * 0.72),
      w * 0.045,
      AppColors.brandGreen.withValues(alpha: 0.20),
    );
  }

  void _bubble(Canvas canvas, Offset c, double r, Color color) {
    final Paint p = Paint()..color = color;
    canvas.drawCircle(c, r, p);
    // 왼쪽 아래로 향하는 작은 꼬리 — 로고 말풍선과 같은 방향.
    final Path tail = Path()
      ..moveTo(c.dx - r * 0.55, c.dy + r * 0.45)
      ..lineTo(c.dx - r * 0.95, c.dy + r * 1.05)
      ..lineTo(c.dx - r * 0.10, c.dy + r * 0.80)
      ..close();
    canvas.drawPath(tail, p);
  }

  /// 화면 바닥의 낮은 언덕 세 겹. 낮 세계를 땅 위에 앉혀 "완성된" 느낌을 줍니다.
  void _paintHills(Canvas canvas, double w, double h) {
    final Path back = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.84)
      ..quadraticBezierTo(w * 0.28, h * 0.75, w * 0.55, h * 0.83)
      ..quadraticBezierTo(w * 0.80, h * 0.90, w, h * 0.80)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      back,
      Paint()..color = AppColors.brandBlue.withValues(alpha: 0.18),
    );

    final Path mid = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90)
      ..quadraticBezierTo(w * 0.30, h * 0.83, w * 0.58, h * 0.90)
      ..quadraticBezierTo(w * 0.82, h * 0.96, w, h * 0.88)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      mid,
      Paint()..color = AppColors.brandMint.withValues(alpha: 0.24),
    );

    final Path front = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.95)
      ..quadraticBezierTo(w * 0.34, h * 0.90, w * 0.64, h * 0.955)
      ..quadraticBezierTo(w * 0.86, h * 1.0, w, h * 0.93)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()..color = AppColors.brandGreen.withValues(alpha: 0.30),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}
