import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'story_cover.dart';

/// 이야기·행성·단어 그룹의 대표 이미지 자리.
///
/// 아이는 글을 읽지 않고 **이미지로 카드의 뜻을 구분**합니다. 그래서 이미지가
/// 아직 없더라도 자리를 비워 두지 않고 브랜드 그라디언트 + 아이콘으로 채웁니다.
/// 빈 회색 사각형을 두면 "고장난 카드"로 보입니다.
class StoryThumbnail extends StatelessWidget {
  const StoryThumbnail({
    super.key,
    required this.image,
    required this.fallbackIcon,
    this.aspectRatio = wide,
    this.iconSize = AppSizes.iconChild,
    this.topicTag,
  });

  /// 16:9 — 홈 카드(이어하기·추천)의 기본. (`docs/DESIGN_SYSTEM.md` 10장)
  static const double wide = 16 / 9;

  /// 2:3 — 그림책 표지 비율. 이야기 목록(`/stories`) 카드 전용.
  /// 세로 표지 밑에 제목이 붙는 "책장에 꽂힌 그림책" 느낌을 냅니다.
  static const double portrait = 2 / 3;

  /// 정사각. 행성 썸네일·필터 칩처럼 원이나 작은 타일로 쓰는 자리.
  static const double square = 1;

  /// 에셋 경로. `null` 이면 그라디언트로 대체합니다.
  /// 서버가 URL 을 내려주기 시작하면 이 위젯 안에서만 바꾸면 됩니다.
  final String? image;

  /// 이미지가 없을 때 대신 보여 줄 아이콘. `AppIcons` 에서 가져오세요.
  final IconData fallbackIcon;

  /// `null` 이면 비율을 강제하지 않고 **부모가 준 크기를 채웁니다.**
  ///
  /// 이야기 상세의 대표 이미지처럼 높이를 직접 정해야 할 때 쓰세요 —
  /// 태블릿에서 16:9 를 전폭으로 깔면 이미지 하나가 화면을 다 먹습니다.
  final double? aspectRatio;

  /// 칩처럼 작은 자리에서는 [AppSizes.iconInline] 로 줄이세요.
  final double iconSize;

  /// 주제(한글 태그). 이미지가 없을 때 표지 색·모티프를 정합니다.
  /// 이야기 목록·홈 추천의 `topicTag` 가 그대로 들어옵니다.
  final String? topicTag;

  @override
  Widget build(BuildContext context) {
    final String? path = image;
    final Widget fallback = StoryCover(
      palette: StoryCoverPalette.forTopic(topicTag),
      motifIcon: topicTag == null ? fallbackIcon : null,
    );
    final Widget content = path == null
        ? fallback
        : Image.asset(
            path,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            // 파일이 빠졌을 때 빨간 에러 상자 대신 표지가 뜹니다.
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) =>
                    fallback,
          );

    final double? ratio = aspectRatio;
    if (ratio == null) return SizedBox.expand(child: content);
    return AspectRatio(aspectRatio: ratio, child: content);
  }
}
