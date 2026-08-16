import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 우주 장식의 색 묶음.
///
/// 별/유성/행성이 쓰는 색을 배경 종류별로 한 벌씩 정의합니다.
/// 화면에서 알파를 따로 정하지 말고 이 프리셋을 그대로 쓰세요 —
/// 같은 뜻의 장식이 화면마다 다른 농도가 되면 어수선해 보입니다.
class CosmicPalette {
  const CosmicPalette({
    required this.starColors,
    required this.starAlpha,
    required this.sparkleColor,
    required this.meteorColor,
    required this.haloColor,
    required this.bodyColors,
    required this.craterColor,
    required this.rimColor,
    required this.shadeColor,
  });

  /// 점 별의 색 후보. 알파는 [starAlpha] 를 기준으로 반짝임이 얹힙니다.
  final List<Color> starColors;

  /// 별 알파의 기준값. 밝은 배경에서는 낮게, 밤 배경에서는 높게.
  final double starAlpha;

  /// 4갈래 반짝이 별의 색.
  final Color sparkleColor;

  /// 유성 꼬리의 색.
  final Color meteorColor;

  /// 행성 뒤로 퍼지는 옅은 빛.
  final Color haloColor;

  /// 행성 본체의 방사형 그라디언트. [빛 받는 면, 중간, 가장자리] 순서.
  final List<Color> bodyColors;

  /// 크레이터 면.
  final Color craterColor;

  /// 행성 테두리 선.
  final Color rimColor;

  /// 행성 아래쪽(화면 밖으로 잠기는 쪽)의 음영.
  final Color shadeColor;

  /// 낮/보호자처럼 밝은 바탕용. 파스텔 별 + 흰빛 도는 달.
  static final CosmicPalette light = CosmicPalette(
    starColors: <Color>[
      AppColors.brandBlue,
      AppColors.brandMint,
      AppColors.brandBlueDeep,
    ],
    starAlpha: 0.55,
    sparkleColor: AppColors.brandBlue,
    meteorColor: AppColors.brandBlueDeep,
    haloColor: AppColors.brandMint.withValues(alpha: 0.30),
    bodyColors: <Color>[
      AppColors.surface,
      AppColors.brandMint.withValues(alpha: 0.55),
      AppColors.brandBlue.withValues(alpha: 0.75),
    ],
    craterColor: AppColors.brandBlue.withValues(alpha: 0.16),
    rimColor: AppColors.brandBlue.withValues(alpha: 0.38),
    shadeColor: AppColors.brandBlueDeep.withValues(alpha: 0.08),
  );

  /// 밤 바탕용. 흰 별 + 은은하게 빛나는 달.
  static final CosmicPalette night = CosmicPalette(
    starColors: <Color>[AppColors.surface, AppColors.brandMint],
    starAlpha: 0.9,
    sparkleColor: AppColors.surface,
    meteorColor: AppColors.surface,
    haloColor: AppColors.brandMint.withValues(alpha: 0.22),
    bodyColors: <Color>[
      AppColors.surface,
      AppColors.brandMint.withValues(alpha: 0.85),
      AppColors.brandBlue.withValues(alpha: 0.9),
    ],
    craterColor: AppColors.nightTop.withValues(alpha: 0.28),
    rimColor: AppColors.surface.withValues(alpha: 0.25),
    shadeColor: AppColors.nightTop.withValues(alpha: 0.30),
  );
}

/// 여백이 있는 화면 뒤에 까는 우주 장식 레이어.
///
/// 위쪽에는 반짝이는 별과 이따금 지나가는 유성, 아래쪽에는 화면 밖으로
/// 반쯤 잠긴 행성(달)을 그립니다. "내 행성" 콘텐츠가 있는 앱이라, 로그인·
/// 단어장처럼 비어 보이던 화면이 같은 세계관으로 묶입니다.
///
/// ## 쓰는 법
///
/// [AppCanvas] 안에서 본문 뒤에 Stack 으로 깝니다.
///
/// ```dart
/// body: AppCanvas.guardian(
///   child: Stack(
///     fit: StackFit.expand,
///     children: <Widget>[
///       const CosmicBackdrop(),
///       SafeArea(child: ...),
///     ],
///   ),
/// )
/// ```
///
/// ## 성능/접근성 규칙 (지킨 것)
///
/// - 순수 장식이라 [IgnorePointer] + [ExcludeSemantics] 로 감쌉니다.
/// - 행성은 정적 레이어, 별은 애니메이션 레이어로 나누고 각각
///   [RepaintBoundary] 를 둡니다. 매 프레임 다시 그리는 건 별 레이어뿐이고,
///   본문·행성의 래스터 캐시는 재사용됩니다.
/// - 반짝임은 컨트롤러 하나가 돌리고, 페인터는 `repaint` 리스너블로만
///   다시 그립니다. setState/rebuild 가 프레임마다 돌지 않습니다.
/// - 흐림(MaskFilter)은 프레임마다 그리는 별 레이어에 쓰지 않습니다.
/// - 기기의 "동작 줄이기" 설정([MediaQuery.disableAnimationsOf])이면
///   멈춘 별만 그립니다.
class CosmicBackdrop extends StatefulWidget {
  const CosmicBackdrop({
    super.key,
    this.showPlanet = true,
    this.planetCenterX = 0.5,
    this.bottomInset = 0,
    this.seed = 7,
    this.palette,
  });

  /// 하단 행성을 그릴지. 좁은 화면 등 행성이 답답해 보이면 끕니다.
  final bool showPlanet;

  /// 행성 중심의 가로 위치 (0.0 왼쪽 끝 ~ 1.0 오른쪽 끝).
  /// 화면마다 조금씩 다르게 두면 같은 장식이 복붙처럼 보이지 않습니다.
  final double planetCenterX;

  /// 행성이 이 높이만큼 위로 올라와 앉습니다. 하단 내비가 있는 화면에서
  /// [AppSizes.bottomNav] 를 넘기면 행성이 내비에 가려지지 않습니다.
  final double bottomInset;

  /// 별 배치 시드. 화면마다 다른 값을 주면 별자리가 달라집니다.
  final int seed;

  /// 색 프리셋. 기본은 밝은 바탕용 [CosmicPalette.light].
  final CosmicPalette? palette;

  /// 테스트 전용 스위치.
  ///
  /// 반짝임은 무한 반복 애니메이션이라 위젯 테스트의 `pumpAndSettle` 이
  /// 영원히 끝나지 않게 만듭니다. `test/flutter_test_config.dart` 에서
  /// false 로 꺼 두므로, 테스트에서는 멈춘 별만 그려집니다.
  static bool animationsEnabled = true;

  @override
  State<CosmicBackdrop> createState() => _CosmicBackdropState();
}

class _CosmicBackdropState extends State<CosmicBackdrop>
    with SingleTickerProviderStateMixin {
  /// 반짝임 한 바퀴. 별의 반짝임 속도는 정수 배수라 루프 경계가 안 보입니다.
  static const Duration _loop = Duration(seconds: 8);

  /// 애니메이션을 껐을 때 보여 줄 프레임. 유성 구간을 피해 골랐습니다.
  static const double _staticPhase = 0.35;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool animate =
        CosmicBackdrop.animationsEnabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = _staticPhase;
    } else if (!animate) {
      _controller.value = _staticPhase;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CosmicPalette palette = widget.palette ?? CosmicPalette.light;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (widget.showPlanet)
              RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  willChange: false,
                  painter: _PlanetPainter(
                    palette: palette,
                    centerXFraction: widget.planetCenterX,
                    bottomInset: widget.bottomInset,
                    seed: widget.seed,
                  ),
                ),
              ),
            // 별은 위쪽 하늘에만 있으므로 애니메이션 레이어를 상단 55% 로
            // 줄입니다. 매 프레임 다시 래스터되는 면적이 절반 가까이 줍니다.
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.55,
                widthFactor: 1,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _StarFieldPainter(
                      palette: palette,
                      seed: widget.seed,
                      animation: _controller,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 별 하나의 불변 속성. 매 프레임 새로 만들지 않도록 미리 계산해 둡니다.
class _Star {
  const _Star({
    required this.position,
    required this.radius,
    required this.color,
    required this.phase,
    required this.speed,
    required this.isSparkle,
  });

  /// 별 레이어(화면 상단 55%) 안의 비율 좌표 (0~1).
  final Offset position;
  final double radius;
  final Color color;

  /// 반짝임 위상 (0~1). 별마다 다르게 두어 일제히 깜빡이지 않게 합니다.
  final double phase;

  /// 루프당 반짝임 횟수. 정수라야 루프 경계에서 튀지 않습니다.
  final int speed;

  /// true 면 4갈래 반짝이 별, false 면 점 별.
  final bool isSparkle;
}

/// 위쪽 하늘 — 반짝이는 별과 유성.
///
/// [animation] 을 `repaint` 로 넘기므로 위젯 rebuild 없이 페인트만 돕니다.
class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({
    required this.palette,
    required this.seed,
    required this.animation,
  }) : super(repaint: animation);

  final CosmicPalette palette;
  final int seed;
  final Animation<double> animation;

  /// 별 목록은 크기가 정해진 뒤 한 번만 만들고 재사용합니다.
  List<_Star>? _stars;
  Size _starsFor = Size.zero;

  /// 유성 두 줄기의 (시작 구간, 시작점, 이동 방향). 루프당 두 번 지나갑니다.
  static const List<(double, Offset, Offset)> _meteors =
      <(double, Offset, Offset)>[
        (0.18, Offset(0.68, 0.06), Offset(-0.20, 0.13)),
        (0.62, Offset(0.18, 0.10), Offset(0.22, 0.11)),
      ];

  /// 유성 하나가 하늘을 가로지르는 데 쓰는 루프 구간.
  static const double _meteorWindow = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final List<_Star> stars = _starsOf(size);
    final double t = animation.value;

    final Paint dot = Paint();
    for (final _Star star in stars) {
      // 0.6~1.0 사이를 사인으로 오가는 반짝임. 완전히 꺼지지는 않습니다.
      final double twinkle =
          0.6 + 0.4 * math.sin(2 * math.pi * (star.speed * t + star.phase));
      final Offset center = Offset(
        star.position.dx * size.width,
        star.position.dy * size.height,
      );
      final double alpha = (palette.starAlpha * twinkle).clamp(0.0, 1.0);
      if (star.isSparkle) {
        _paintSparkle(
          canvas,
          center,
          star.radius * (0.85 + 0.15 * twinkle),
          palette.sparkleColor.withValues(alpha: alpha),
        );
      } else {
        dot.color = star.color.withValues(alpha: alpha);
        canvas.drawCircle(center, star.radius, dot);
      }
    }

    _paintMeteors(canvas, size, t);
  }

  List<_Star> _starsOf(Size size) {
    if (_stars != null && _starsFor == size) return _stars!;
    final math.Random random = math.Random(seed);
    final int count = (size.width / 34).round().clamp(16, 44);
    final List<_Star> stars = <_Star>[
      for (int i = 0; i < count; i++)
        _Star(
          position: Offset(
            random.nextDouble(),
            0.03 + random.nextDouble() * 0.85,
          ),
          radius: 1.4 + random.nextDouble() * 1.8,
          color: palette.starColors[i % palette.starColors.length],
          phase: random.nextDouble(),
          speed: 1 + random.nextInt(3),
          isSparkle: false,
        ),
      // 반짝이 별은 소수만. 많아지면 장식이 아니라 소음이 됩니다.
      for (int i = 0; i < 5; i++)
        _Star(
          position: Offset(
            0.06 + random.nextDouble() * 0.88,
            0.06 + random.nextDouble() * 0.62,
          ),
          radius: 5.0 + random.nextDouble() * 4.0,
          color: palette.sparkleColor,
          phase: random.nextDouble(),
          speed: 1 + random.nextInt(2),
          isSparkle: true,
        ),
    ];
    _stars = stars;
    _starsFor = size;
    return stars;
  }

  /// 4갈래 반짝이 별. 가운데로 오목한 곡선이라 ✦ 처럼 보입니다.
  void _paintSparkle(Canvas canvas, Offset c, double s, Color color) {
    final Path path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintMeteors(Canvas canvas, Size size, double t) {
    for (final (double start, Offset from, Offset delta) in _meteors) {
      final double p = (t - start) / _meteorWindow;
      if (p < 0 || p > 1) continue;

      // 나타났다 사라지는 밝기. 궤적은 감속 곡선으로 자연스럽게.
      final double fade = math.sin(math.pi * p);
      final double eased = Curves.easeOut.transform(p);
      final Offset head = Offset(
        (from.dx + delta.dx * eased) * size.width,
        (from.dy + delta.dy * eased) * size.width,
      );
      final Offset direction = -delta / delta.distance;
      final Offset tail = head + direction * (72 + 24 * fade);

      final Paint streak = Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: <Color>[
            palette.meteorColor.withValues(alpha: 0.5 * fade),
            palette.meteorColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(head, tail));
      canvas.drawLine(head, tail, streak);
      canvas.drawCircle(
        head,
        2.6,
        Paint()..color = palette.meteorColor.withValues(alpha: 0.55 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.seed != seed;
}

/// 아래쪽 지평선 — 화면 밖으로 반쯤 잠긴 달.
///
/// 정적 레이어라 한 번 그려진 뒤에는 래스터 캐시로만 살아갑니다.
class _PlanetPainter extends CustomPainter {
  const _PlanetPainter({
    required this.palette,
    required this.centerXFraction,
    required this.bottomInset,
    required this.seed,
  });

  final CosmicPalette palette;
  final double centerXFraction;
  final double bottomInset;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double w = size.width;
    final double h = size.height;

    final double radius = (w * 0.42).clamp(260.0, 520.0);
    // 화면에 보이는 달의 높이. 너무 크면 본문을 밀어내는 느낌이 듭니다.
    final double visible = (h * 0.14).clamp(88.0, 168.0);
    final double horizon = h - bottomInset;
    final Offset center = Offset(
      w * centerXFraction,
      horizon + radius - visible,
    );

    // 1) 달 뒤로 퍼지는 빛. 정적 레이어라 그라디언트 비용은 최초 1회입니다.
    canvas.drawCircle(
      center,
      radius * 1.22,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.haloColor,
            palette.haloColor.withValues(alpha: 0),
          ],
          stops: const <double>[0.62, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.22)),
    );

    // 2) 본체. 빛은 왼쪽 위(별이 있는 하늘)에서 옵니다.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.75),
          radius: 1.25,
          colors: palette.bodyColors,
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 3) 아래로 잠기는 쪽 음영. 원 안에만 칠해집니다.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            palette.shadeColor.withValues(alpha: 0),
            palette.shadeColor,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    _paintCraters(canvas, center, radius, horizon);

    // 5) 테두리 한 줄. 파스텔 면이 배경에 뭉개지지 않게 잡아 줍니다.
    canvas.drawCircle(
      center,
      radius - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = palette.rimColor,
    );
  }

  /// 4) 크레이터. 화면에 실제로 보이는 곡면 띠 안에만 흩어서,
  /// 어떤 화면 비율에서도 달이 밋밋해지지 않게 합니다.
  void _paintCraters(
    Canvas canvas,
    Offset center,
    double radius,
    double horizon,
  ) {
    final double top = center.dy - radius;
    final double band = horizon - top;
    if (band <= 0) return;

    final math.Random random = math.Random(seed * 31 + 7);
    final Paint outer = Paint()
      ..color = palette.craterColor.withValues(
        alpha: palette.craterColor.a * 0.62,
      );
    final Paint inner = Paint()..color = palette.craterColor;

    for (int i = 0; i < 7; i++) {
      final double r = radius * (0.035 + random.nextDouble() * 0.055);
      final double y = top + band * (0.16 + random.nextDouble() * 0.72);
      if (y + r > horizon) continue;
      // 이 높이에서 원 안에 들어가는 가로 범위(현의 절반) 안에서만 고릅니다.
      final double dy = y - center.dy;
      final double half = math.sqrt(math.max(0, radius * radius - dy * dy));
      if (half < r * 3) continue;
      final double x =
          center.dx + (random.nextDouble() * 2 - 1) * (half - r * 2.4);
      final Offset c = Offset(x, y);
      canvas.drawCircle(c, r, outer);
      canvas.drawCircle(c.translate(r * 0.12, r * 0.16), r * 0.66, inner);
    }
  }

  @override
  bool shouldRepaint(_PlanetPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.centerXFraction != centerXFraction ||
      oldDelegate.bottomInset != bottomInset ||
      oldDelegate.seed != seed;
}
