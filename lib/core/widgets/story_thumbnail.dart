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
    this.title,
  });

  /// 제목 → 우리가 그려 둔 로컬 표지 파일 이름(확장자 제외).
  ///
  /// 서버 storyId 는 UUID 라 기존 `story_<int>.png` 폴백이 매칭되지 않습니다.
  /// 표지 일러스트 자체는 제목별로 고정이라, **제목으로 매칭**해 기존 그림을
  /// 계속 씁니다. 새 이야기가 늘어나면 여기에 한 줄씩 추가하세요.
  static const Map<String, String> _localCoverByTitle = <String, String>{
    '방귀 뀌는 며느리': 'story_11',
    '해와 달이 된 오누이': 'story_21',
    '의좋은 형제': 'story_22',
    '흥부와 놀부': 'story_23',
    '토끼와 거북이': 'story_31',
    '호랑이와 곶감': 'story_32',
    '학교 가는 길': 'story_41',
  };

  /// [title] 에 대응하는 로컬 표지 에셋 경로. 없으면 `null`.
  static String? localCoverAssetFor(String? title) {
    final String? file = title == null ? null : _localCoverByTitle[title];
    return file == null ? null : 'assets/images/covers/$file.png';
  }

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

  /// 이야기 제목. 서버 이미지가 없을 때 [_localCoverByTitle] 매칭에 씁니다.
  final String? title;

  @override
  Widget build(BuildContext context) {
    // 서버가 `imageUrl: ""`(빈 문자열)이나 공백을 주면 "이미지 없음"으로 봅니다.
    // 그러지 않으면 `Image.asset('')` 이 곧장 실패해 제목 표지(우선순위 2)를
    // 건너뛰고 코드 표지로 떨어집니다.
    final String? raw = image;
    final String? path = (raw != null && raw.trim().isNotEmpty) ? raw : null;
    final Widget fallback = StoryCover(
      palette: StoryCoverPalette.forTopic(topicTag),
      motifIcon: topicTag == null ? fallbackIcon : null,
    );
    final String? localCover = localCoverAssetFor(title);
    // 서버 이미지가 없거나 실패했을 때: 제목으로 찾은 로컬 표지 → 코드 표지.
    final Widget onMissing = localCover == null
        ? fallback
        : _LocalAsset(path: localCover, fallback: fallback);

    final Widget content;
    if (path != null && path.startsWith('http')) {
      // 우선순위 1 — 서버가 준 이미지 URL.
      content = Image.network(
        path,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        gaplessPlayback: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            onMissing,
        loadingBuilder:
            (BuildContext context, Widget child, ImageChunkEvent? progress) =>
                progress == null ? child : onMissing,
      );
    } else if (path != null) {
      // 더미·기존 코드가 넘기는 로컬 에셋 경로. 실패하면 제목 표지→코드 표지.
      content = _LocalAsset(path: path, fallback: onMissing);
    } else if (localCover != null) {
      // 우선순위 2 — 제목으로 찾은 로컬 표지.
      content = _LocalAsset(path: localCover, fallback: fallback);
    } else {
      // 우선순위 3 — 코드로 그린 표지.
      content = fallback;
    }

    final double? ratio = aspectRatio;
    if (ratio == null) return SizedBox.expand(child: content);
    return AspectRatio(aspectRatio: ratio, child: content);
  }
}

/// `Image.asset` + 실패 시 코드 표지 폴백. 파일이 빠졌을 때 빨간 에러
/// 상자 대신 표지가 뜹니다.
class _LocalAsset extends StatelessWidget {
  const _LocalAsset({required this.path, required this.fallback});

  final String path;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => Image.asset(
    path,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
        fallback,
  );
}
