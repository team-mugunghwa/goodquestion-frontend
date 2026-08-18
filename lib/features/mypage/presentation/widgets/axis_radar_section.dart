import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/entities/report_detail.dart';

/// 보호자 리포트의 6각 그래프 섹션 — "한눈에 확인" 요구(인터뷰 #10)에
/// 대응합니다.
///
/// ## D6 매핑 (엔진 8요소 → 보호자용 6축)
///
/// 이유대기(REASON) · 결과예측(RESULT) · 판단력(DECISION) ·
/// 해결력(SOLUTION+REQUEST) · 관점이해(PERSPECTIVE+EMPATHY) ·
/// 감정표현(EMOTION). → `claude/보호자리포트_6축그래프_설계안_D6.md`
///
/// **엔진 태그를 화면에 노출하지 않습니다** — [AxisScore.label]은 이미
/// 한글로 바뀐 값만 받습니다. (PRD F-09)
///
/// [axes]가 6개가 아니거나 비어 있으면 아무것도 그리지 않습니다 —
/// 호출부(`report_detail_view.dart`)가 `isNotEmpty`로 먼저 거르지만,
/// 방어적으로 한 번 더 확인합니다.
class AxisRadarSection extends StatelessWidget {
  const AxisRadarSection({
    super.key,
    required this.axes,
    required this.hasPreviousSession,
  });

  final List<AxisScore> axes;

  /// 지난 회차 평균이 있는지 — 1회차면 false.
  final bool hasPreviousSession;

  @override
  Widget build(BuildContext context) {
    if (axes.length != 6) return const SizedBox.shrink();

    final TextTheme text = Theme.of(context).textTheme;
    final bool hasInactive = axes.any((AxisScore a) => !a.active);
    final AxisScore? lowest = _lowestActiveAxis(axes);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(ReportDetailStrings.axisChartTitle, style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ReportDetailStrings.axisChartSubtitle,
            style: text.bodySmall?.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.md),
          ResponsiveLayout(
            compact: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _RadarChart(axes: axes),
                const SizedBox(height: AppSpacing.sm),
                _Legend(
                  hasPreviousSession: hasPreviousSession,
                  hasInactive: hasInactive,
                ),
                const SizedBox(height: AppSpacing.md),
                _AxisList(axes: axes),
              ],
            ),
            expanded: (_) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _RadarChart(axes: axes),
                      const SizedBox(height: AppSpacing.sm),
                      _Legend(
                        hasPreviousSession: hasPreviousSession,
                        hasInactive: hasInactive,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 6, child: _AxisList(axes: axes)),
              ],
            ),
          ),
          if (lowest != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandBlueSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${lowest.label} ${ReportDetailStrings.axisLowestSuffix}',
                style: text.bodySmall?.copyWith(color: AppColors.ink700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  AxisScore? _lowestActiveAxis(List<AxisScore> axes) {
    AxisScore? lowest;
    for (final AxisScore axis in axes) {
      if (!axis.active || axis.score == null) continue;
      if (lowest == null || axis.score! < lowest.score!) lowest = axis;
    }
    return lowest;
  }
}

/// 육각 레이더 본체. 정사각형에 가깝게 그리되, 위아래 라벨이 잘리지
/// 않도록 폭보다 살짝 큰 높이를 씁니다.
class _RadarChart extends StatelessWidget {
  const _RadarChart({required this.axes});

  final List<AxisScore> axes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = constraints.maxWidth < 340
            ? constraints.maxWidth
            : 340;
        return Center(
          child: SizedBox(
            width: side,
            height: side + 44,
            child: CustomPaint(painter: _RadarPainter(axes: axes)),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.axes});

  final List<AxisScore> axes;

  static const int _sides = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width * 0.30;

    Offset vertex(int i, double fraction) {
      final double angle = -pi / 2 + i * (2 * pi / _sides);
      return center + Offset(cos(angle), sin(angle)) * (radius * fraction);
    }

    // 1) 그리드 링 (20/40/60/80/100%)
    for (int ring = 1; ring <= 5; ring++) {
      final double fraction = ring / 5;
      final Path ringPath = Path();
      for (int i = 0; i < _sides; i++) {
        final Offset p = vertex(i, fraction);
        if (i == 0) {
          ringPath.moveTo(p.dx, p.dy);
        } else {
          ringPath.lineTo(p.dx, p.dy);
        }
      }
      ringPath.close();
      canvas.drawPath(
        ringPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 5 ? 1.4 : 1
          ..color = AppColors.ink100,
      );
    }

    // 2) 스포크 + 이번 이야기 목표가 아닌 축의 빗금 웨지
    for (int i = 0; i < _sides; i++) {
      final AxisScore axis = axes[i];
      if (!axis.active) {
        final double angle = -pi / 2 + i * (2 * pi / _sides);
        final Offset p0 =
            center + Offset(cos(angle - pi / 6), sin(angle - pi / 6)) * radius;
        final Offset p1 = vertex(i, 1);
        final Offset p2 =
            center + Offset(cos(angle + pi / 6), sin(angle + pi / 6)) * radius;
        final Path wedge = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.save();
        canvas.clipPath(wedge);
        canvas.drawPath(
          wedge,
          Paint()
            ..style = PaintingStyle.fill
            ..color = AppColors.ink100,
        );
        final Paint hatchPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.ink300;
        final double step = radius / 4;
        for (double d = -radius; d < radius * 2; d += step) {
          canvas.drawLine(
            Offset(center.dx - radius + d, center.dy - radius),
            Offset(center.dx + d, center.dy + radius),
            hatchPaint,
          );
        }
        canvas.restore();
      }
      final Offset end = vertex(i, 1);
      canvas.drawLine(
        center,
        end,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.ink300,
      );
    }

    // 3) 지난 회차 평균 — 회색 점선, 채움 없음 (강조하지 않음)
    final List<int> refIndices = <int>[
      for (int i = 0; i < _sides; i++)
        if (axes[i].active && axes[i].previousScore != null) i,
    ];
    if (refIndices.length >= 2) {
      final Path refPath = Path();
      for (int idx = 0; idx < refIndices.length; idx++) {
        final int i = refIndices[idx];
        final Offset p = vertex(i, (axes[i].previousScore ?? 0) / 100);
        if (idx == 0) {
          refPath.moveTo(p.dx, p.dy);
        } else {
          refPath.lineTo(p.dx, p.dy);
        }
      }
      refPath.close();
      _drawDashedPath(
        canvas,
        refPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.ink500,
      );
    }

    // 4) 이번 회차 — 활성 축만 이어서 그립니다.
    final List<int> activeIndices = <int>[
      for (int i = 0; i < _sides; i++)
        if (axes[i].active) i,
    ];
    if (activeIndices.isNotEmpty) {
      final Path dataPath = Path();
      for (int idx = 0; idx < activeIndices.length; idx++) {
        final int i = activeIndices[idx];
        final Offset p = vertex(i, (axes[i].score ?? 0) / 100);
        if (idx == 0) {
          dataPath.moveTo(p.dx, p.dy);
        } else {
          dataPath.lineTo(p.dx, p.dy);
        }
      }
      dataPath.close();
      canvas.drawPath(
        dataPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = AppColors.brandBlue.withValues(alpha: 0.30),
      );
      canvas.drawPath(
        dataPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.brandBlueDeep,
      );
      for (final int i in activeIndices) {
        final Offset p = vertex(i, (axes[i].score ?? 0) / 100);
        canvas.drawCircle(p, 6, Paint()..color = AppColors.surface);
        canvas.drawCircle(p, 4.2, Paint()..color = AppColors.brandBlueDeep);
      }
    }

    // 5) 라벨 (모든 축 — 비활성 축도 "측정 안 함"으로 표시)
    for (int i = 0; i < _sides; i++) {
      _paintLabel(canvas, center, radius, i, axes[i]);
    }
  }

  void _paintLabel(
    Canvas canvas,
    Offset center,
    double radius,
    int i,
    AxisScore axis,
  ) {
    final double angle = -pi / 2 + i * (2 * pi / _sides);
    final double cosA = cos(angle);
    final double sinA = sin(angle);
    final Offset anchor = center + Offset(cosA, sinA) * (radius * 1.34);

    final TextPainter labelPainter = TextPainter(
      text: TextSpan(
        text: axis.label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          fontFamily: AppFonts.body,
          color: axis.active ? AppColors.ink900 : AppColors.ink500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final String valueText = axis.active
        ? '${axis.score}'
        : ReportDetailStrings.axisNotMeasuredShort;
    final TextPainter valuePainter = TextPainter(
      text: TextSpan(
        text: valueText,
        style: TextStyle(
          fontSize: axis.active ? 13 : 10.5,
          fontWeight: FontWeight.w800,
          fontFamily: AppFonts.body,
          color: axis.active ? AppColors.brandBlueDeep : AppColors.ink500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double gap = 2;
    final double blockHeight = labelPainter.height + gap + valuePainter.height;

    double blockTop;
    if (sinA < -0.15) {
      blockTop = anchor.dy - blockHeight - 4;
    } else if (sinA > 0.15) {
      blockTop = anchor.dy + 4;
    } else {
      blockTop = anchor.dy - blockHeight / 2;
    }

    double lineX(double lineWidth) {
      if (cosA > 0.15) return anchor.dx;
      if (cosA < -0.15) return anchor.dx - lineWidth;
      return anchor.dx - lineWidth / 2;
    }

    labelPainter.paint(canvas, Offset(lineX(labelPainter.width), blockTop));
    valuePainter.paint(
      canvas,
      Offset(lineX(valuePainter.width), blockTop + labelPainter.height + gap),
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashLength = 5;
    const double gapLength = 4;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double segmentEnd = distance + (draw ? dashLength : gapLength);
        final double end = segmentEnd > metric.length
            ? metric.length
            : segmentEnd;
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      !identical(oldDelegate.axes, axes);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hasPreviousSession, required this.hasInactive});

  final bool hasPreviousSession;
  final bool hasInactive;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.ink500);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.brandBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(ReportDetailStrings.legendCurrent, style: style),
          ],
        ),
        if (hasPreviousSession)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(width: 16, height: 2, color: AppColors.ink500),
              const SizedBox(width: AppSpacing.xs),
              Text(ReportDetailStrings.legendPrevious, style: style),
            ],
          ),
        if (hasInactive)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.ink100,
                  border: Border.all(color: AppColors.ink300),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(ReportDetailStrings.legendInactive, style: style),
            ],
          ),
      ],
    );
  }
}

class _AxisList extends StatelessWidget {
  const _AxisList({required this.axes});

  final List<AxisScore> axes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < axes.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _AxisRow(axis: axes[i]),
        ],
      ],
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow({required this.axis});

  final AxisScore axis;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: axis.active ? AppColors.surface : AppColors.guardianCanvas,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ink100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: axis.active
                      ? AppColors.brandBlueDeep
                      : AppColors.ink300,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  axis.label,
                  style: text.titleMedium?.copyWith(
                    color: axis.active ? AppColors.ink900 : AppColors.ink500,
                  ),
                ),
              ),
              Text(
                axis.active ? '${axis.score}' : '—',
                style: text.titleMedium?.copyWith(
                  color: axis.active
                      ? AppColors.brandBlueDeep
                      : AppColors.ink500,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (axis.active)
            _ScoreBar(score: axis.score ?? 0, previousScore: axis.previousScore)
          else
            Text(
              ReportDetailStrings.axisNotMeasured,
              style: text.bodySmall?.copyWith(color: AppColors.ink500),
            ),
          if (axis.active && (axis.evidence?.isNotEmpty ?? false)) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '"${axis.evidence}"',
              style: AppTypography.quote.copyWith(fontSize: 14, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score, this.previousScore});

  final int score;
  final int? previousScore;

  double _fraction(int value) {
    if (value <= 0) return 0;
    if (value >= 100) return 1;
    return value / 100;
  }

  @override
  Widget build(BuildContext context) {
    final double fraction = _fraction(score);
    return SizedBox(
      width: double.infinity,
      height: 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: AppColors.ink100,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.brandBlueDeep,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          if (previousScore != null)
            Align(
              alignment: Alignment(
                (-1 + 2 * _fraction(previousScore!)).toDouble(),
                0,
              ),
              child: Container(width: 2, height: 14, color: AppColors.ink500),
            ),
        ],
      ),
    );
  }
}
