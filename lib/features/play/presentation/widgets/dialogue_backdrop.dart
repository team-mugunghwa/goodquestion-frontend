/// 대화·전개 화면이 함께 쓰는 바탕 한 장.
///
/// [DialogueBackdrop] 은 에셋 경로와 서버 URL 을 같은 자리에서 받습니다 —
/// 부르는 쪽이 "이건 번들 그림, 저건 서버 그림"을 가려낼 필요가 없어야
/// 합니다. 어느 쪽이든 못 그리면 [DialogueBackdropFallback] 으로 떨어집니다.
///
/// `play_view.dart` 에 있던 것을 자유 대화 화면과 함께 쓰려고 뽑아 왔습니다.
/// **그림은 한 픽셀도 바꾸지 않았습니다** — 자유 대화가 학습 화면과 다른
/// 바탕을 쓰면 같은 인물이 다른 세계에 서 있게 됩니다.
library;

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';

class DialogueBackdrop extends StatelessWidget {
  const DialogueBackdrop({super.key, this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      final String resolvedAsset = asset!.startsWith('/')
          ? Uri.parse(AppConfig.apiBaseUrl).resolve(asset!).toString()
          : asset!;
      final Uri? uri = Uri.tryParse(resolvedAsset);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return Image.network(
          resolvedAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DialogueBackdropFallback(),
        );
      }
      return Image.asset(
        resolvedAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const DialogueBackdropFallback(),
      );
    }
    return const DialogueBackdropFallback();
  }
}

class DialogueBackdropFallback extends StatelessWidget {
  const DialogueBackdropFallback({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF356B8A),
          Color(0xFF244A73),
          Color(0xFF172E50),
        ],
      ),
    ),
    child: CustomPaint(painter: _BackdropPainter()),
  );
}

class DialogueBackdropShade extends StatelessWidget {
  const DialogueBackdropShade({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x33071425),
            Color(0x00071425),
            Color(0x66071425),
          ],
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0x1677E0C4);
    canvas.drawCircle(
      Offset(size.width * .15, size.height * .22),
      size.width * .16,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .28),
      size.width * .22,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * .62, size.height * .9),
      size.width * .26,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
