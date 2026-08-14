import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// 말풍선을 누가 말했는지.
///
/// 면 색과 꼬리 방향이 함께 바뀝니다. 색만 바꾸면 색을 구분하기 어려운
/// 아이에게 화자가 사라집니다. (`docs/DESIGN_SYSTEM.md` 10장)
enum KidSpeaker {
  /// 캐릭터 — 왼쪽, 흰 면.
  character,

  /// 아이 — 오른쪽, `brandBlue` 10% 면.
  child,
}

/// 아이 화면의 기본 그릇.
///
/// 이 앱의 주제는 "말"이라서 화면의 기본 그릇은 사각 카드가 아니라
/// **말풍선**입니다. 캐릭터 대사·아이 발화·미션·힌트가 전부 같은 형태를 쓰고
/// **꼬리 방향과 면 색으로만** 누가 말했는지를 구분합니다.
/// (`docs/DESIGN_SYSTEM.md` 1장 — "이게 이 앱의 서명입니다")
///
/// 꼬리는 **박스 안쪽에서** 그려집니다. [height] 를 주면 꼬리까지 포함한
/// 높이라서, 세로 예산을 짤 때 이 위젯 하나만 세면 됩니다.
class KidSpeechBubble extends StatelessWidget {
  const KidSpeechBubble({
    super.key,
    required this.child,
    this.speaker = KidSpeaker.character,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.maxWidth = AppSizes.bubbleMaxWidth,
    this.height,
    this.color,
    this.tail = true,
  });

  final Widget child;
  final KidSpeaker speaker;

  /// 꼬리 높이는 여기에 포함하지 마세요 — 위젯이 알아서 더합니다.
  final EdgeInsets padding;

  /// 한 줄이 길어지면 아이가 눈으로 줄을 놓칩니다. 기본값을 넓히지 마세요.
  final double maxWidth;

  /// 꼬리까지 포함한 전체 높이. `null` 이면 내용에 맞춥니다.
  final double? height;

  /// 면 색을 덮어씁니다. 힌트 말풍선처럼 톤이 달라야 할 때만 쓰세요.
  final Color? color;

  final bool tail;

  /// 꼬리가 차지하는 세로. 높이 예산을 짤 때 씁니다.
  static const double tailHeight = 14;

  /// 말풍선의 위아래 여백 + 꼬리. 안에 들어갈 글자 줄 수를 역산할 때 씁니다.
  static double chromeOf(EdgeInsets padding, {bool tail = true}) =>
      padding.vertical + (tail ? tailHeight : 0);

  @override
  Widget build(BuildContext context) {
    final bool fromChild = speaker == KidSpeaker.child;
    return Align(
      alignment: fromChild ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          height: height,
          padding: padding.add(EdgeInsets.only(bottom: tail ? tailHeight : 0)),
          decoration: ShapeDecoration(
            color:
                color ??
                (fromChild
                    // brandBlue 10% 를 흰 면 위에 합성해 둡니다. 낮 배경 위에
                    // 반투명으로 얹으면 바탕 그라디언트가 비쳐서, 같은 말풍선이
                    // 화면 위쪽과 아래쪽에서 다른 색으로 보입니다.
                    ? Color.alphaBlend(
                        AppColors.brandBlueSurface,
                        AppColors.surface,
                      )
                    : AppColors.surface),
            shape: _SpeechBubbleShape(
              radius: AppRadius.xl,
              alignEnd: fromChild,
              hasTail: tail,
            ),
            shadows: fromChild ? AppShadows.lift : AppShadows.soft,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 둥근 사각형 + 아래쪽 꼬리 하나로 이루어진 외곽선.
///
/// [ShapeBorder] 로 만든 이유는 그림자 때문입니다. `CustomPaint` 로 꼬리를
/// 따로 그리면 그림자가 꼬리를 따라가지 않아서 꼬리만 붕 떠 보입니다.
class _SpeechBubbleShape extends ShapeBorder {
  const _SpeechBubbleShape({
    required this.radius,
    required this.alignEnd,
    required this.hasTail,
  });

  final double radius;
  final bool alignEnd;
  final bool hasTail;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final bool drawTail =
        hasTail && rect.height > KidSpeechBubble.tailHeight * 2;
    final double bottom = drawTail
        ? rect.bottom - KidSpeechBubble.tailHeight
        : rect.bottom;
    final double r = radius.clamp(0, rect.shortestSide / 2);
    final Path body = Path()
      ..addRRect(
        RRect.fromLTRBR(
          rect.left,
          rect.top,
          rect.right,
          bottom,
          Radius.circular(r),
        ),
      );
    if (!drawTail) return body;

    // 꼬리는 화자 쪽 모서리에서 반경만큼 들어온 자리에 답니다.
    const double width = 26;
    final double base = alignEnd ? rect.right - r : rect.left + r;
    final double dir = alignEnd ? -1 : 1;
    final Path tail = Path()
      ..moveTo(base, bottom - 2)
      ..lineTo(base + dir * width, bottom - 2)
      ..lineTo(base + dir * width * 0.3, rect.bottom)
      ..close();
    return Path.combine(PathOperation.union, body, tail);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
