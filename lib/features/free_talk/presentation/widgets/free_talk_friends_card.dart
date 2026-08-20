import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/text/korean_wrap.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/character_avatar.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../play/presentation/character/dialogue_character_manifest.dart';
import '../../domain/entities/free_talk.dart';

/// 이야기 상세의 **친구들 카드** — 완주한 이야기에만 뜹니다.
///
/// ## 왜 버튼 하나가 아니라 얼굴들인가
///
/// 처음에는 하단에 "○○와 더 이야기하기" 버튼 한 줄이었습니다. 그런데 이
/// 이야기에는 친구가 셋(며느리·시아버지·이장)이고, 버튼 한 줄은 **그 셋이
/// 있다는 사실 자체를 숨깁니다.** 아이는 눌러서 다음 화면에 가 본 뒤에야
/// 고를 게 있다는 걸 압니다.
///
/// 얼굴을 늘어놓으면 고르는 일이 화면에 그대로 보이고, 글을 못 읽는 아이도
/// **누구를 만날지 그림으로** 정합니다. 이 앱에서 아이가 이야기를 고르는
/// 방식(표지 그림)과 같은 규칙입니다.
///
/// ## 얼굴을 누르면 그 친구에게 바로 갑니다
///
/// 인물 고르기 화면(`free_talk_characters_view.dart`)을 한 번 더 거치지
/// 않습니다 — 여기서 이미 고른 것을 다음 화면에서 또 고르라고 하면 같은
/// 질문을 두 번 하는 셈입니다. 완료 화면에서 오는 길은 그대로 인물 고르기로
/// 가고, 이 카드는 **고르기까지 마친 지름길**입니다.
class FreeTalkFriendsCard extends StatefulWidget {
  const FreeTalkFriendsCard({
    super.key,
    required this.characters,
    required this.metrics,
    required this.onTapCharacter,
    this.manifest,
  });

  final List<FreeTalkCharacter> characters;
  final ScreenMetrics metrics;

  /// 번들 표정 에셋 매니페스트를 **밖에서 넣고 싶을 때만** 씁니다(테스트·
  /// 프리뷰). 안 주면 카드가 스스로 읽습니다.
  final DialogueCharacterManifest? manifest;

  final void Function(FreeTalkCharacter character) onTapCharacter;

  @override
  State<FreeTalkFriendsCard> createState() => _FreeTalkFriendsCardState();
}

class _FreeTalkFriendsCardState extends State<FreeTalkFriendsCard> {
  DialogueCharacterManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _manifest = widget.manifest;
    if (_manifest == null) unawaited(_loadManifest());
  }

  /// 표정 에셋 매니페스트. **실패해도 카드가 죽지 않습니다** — 원반은 서버
  /// 썸네일이나 로고 마크로 떨어집니다. (`free_talk_characters_view.dart` 와
  /// 같은 원칙)
  Future<void> _loadManifest() async {
    try {
      final DialogueCharacterManifest manifest =
          await DialogueCharacterManifest.load();
      if (!mounted) return;
      setState(() => _manifest = manifest);
    } on Object {
      // 무시한다.
    }
  }

  ScreenMetrics get metrics => widget.metrics;

  /// 한 줄에 세울 얼굴 수. 넷째부터는 [Wrap] 이 다음 줄로 내립니다.
  int get _perRow => math.min(widget.characters.length, 3);

  /// 원반 지름을 **폭에서 거꾸로 잽니다.**
  ///
  /// 고정 크기(88)를 쓰다가 폰 430dp 에서 셋 중 하나가 다음 줄로 내려갔습니다 —
  /// 얼굴 셋이 나란한 것이 이 카드의 전부라, 하나가 아래로 떨어지면 "친구가
  /// 셋"이 한눈에 안 읽힙니다. 남는 폭을 나눠 갖게 하면 어떤 폭에서도 한 줄에
  /// 섭니다.
  ///
  /// [maxSize] 로 위를 막습니다. 태블릿에서 폭이 남는다고 원반이 계속 커지면
  /// 역할 카드의 그림보다 커져서 위계가 뒤집힙니다.
  double _avatarSize(double maxWidth) {
    final double maxSize = metrics.isWide ? 128 : 96;
    final double tile = (maxWidth - AppSpacing.md * (_perRow - 1)) / _perRow;
    return math.min(maxSize, tile - AppSpacing.sm);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // 역할 카드와 **같은 파스텔 면**입니다. 완주한 이야기에서 이 둘은
        // 나란히 서는 형제 카드라, 색이 다르면 화면이 알록달록해집니다.
        color: AppColors.brandBlueSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            FreeTalkStrings.friendsIntro,
            textAlign: TextAlign.center,
            style: metrics
                .text(AppTypography.kidTitle)
                .copyWith(color: AppColors.brandBlueDeep),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            FreeTalkStrings.friendsHint,
            textAlign: TextAlign.center,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.lg),
          // 인물이 넷 이상인 이야기가 오면 줄이 바뀝니다. 가로 스크롤로
          // 밀어 두면 화면 밖의 친구를 아이가 못 찾습니다.
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double size = _avatarSize(constraints.maxWidth);
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  for (final FreeTalkCharacter character in widget.characters)
                    _FriendTile(
                      character: character,
                      metrics: metrics,
                      size: size,
                      scene: _manifest?.sceneForCharacter(
                        characterId: character.characterId,
                        name: character.name,
                      ),
                      onTap: () => widget.onTapCharacter(character),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 얼굴 하나 + 이름. 누르면 그 친구와의 대화로 갑니다.
class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.character,
    required this.metrics,
    required this.size,
    required this.onTap,
    this.scene,
  });

  final FreeTalkCharacter character;
  final ScreenMetrics metrics;
  final double size;
  final DialogueSceneStates? scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? lastTalked = _lastTalkedLabel();
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel: <String>[
        character.name,
        if (lastTalked != null) lastTalked,
      ].join(', '),
      child: SizedBox(
        // 이름이 길어도(“방귀쟁이 며느리”) 원반이 밀려나지 않게 폭을 고정합니다.
        // 원반보다 조금 넓게 두면 두 줄까지는 원반 아래에 얌전히 앉습니다.
        // 이 여유분은 [_FreeTalkFriendsCardState._avatarSize] 가 폭을 나눌 때
        // 이미 빼 둔 값과 같아야 합니다 — 다르면 한 줄에서 밀려납니다.
        width: size + AppSpacing.sm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CharacterAvatar(
              size: size,
              assetImage: _portrait,
              thumbnailUrl: character.thumbnailUrl,
              // 파스텔 면 위의 흰 원반은 경계가 흐립니다. 여기서만 테두리를
              // 두릅니다 — 누를 수 있는 것이라 윤곽이 분명해야 합니다.
              borderColor: AppColors.surface,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // 원반 아래 폭이 좁아 두 줄까지 갑니다. "마을 이 / 장" 으로
              // 쪼개지지 않게 어절로 묶습니다.
              character.name.keepWords,
              semanticsLabel: character.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: metrics
                  .text(AppTypography.kidLabel)
                  .copyWith(color: AppColors.ink900),
            ),
            // 한 번도 안 걸었으면 줄 자체를 그리지 않습니다 - "없음"이라
            // 적으면 안 한 것이 못 한 것처럼 보입니다.
            if (lastTalked != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                lastTalked,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: metrics
                    .text(AppTypography.kidCaption)
                    .copyWith(color: AppColors.ink500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 이 자리에 걸 표정.
  ///
  /// **`openingState` 를 쓰면 안 됩니다.** 첫 대사 표정은 전부 이야기가
  /// 시작될 때의 감정입니다 — 며느리는 걱정, 시아버지는 화난 얼굴, 이장은
  /// 굳은 얼굴. 다시 만나자고 부르는 자리에 걸면 "무슨 안 좋은 일이 있나"
  /// 로 읽힙니다. (역할 카드가 `purposeful_hopeful` 을 고른 것과 같은 이유)
  ///
  /// `closingVia` 는 **아이와 이야기가 잘 풀린 뒤의 얼굴**입니다 —
  /// 며느리 `hopeful`, 시아버지 `softened`, 이장 `result_hopeful`.
  /// 매니페스트에 없으면 마무리 표정 → 첫 표정 순으로 물러섭니다.
  String? get _portrait {
    final DialogueSceneStates? states = scene;
    if (states == null) return null;
    return states.assetOf(states.closingVia) ??
        states.assetOf(states.closingState) ??
        states.assetOf(states.openingState);
  }

  /// 며칠 전에 이야기했는지. **시각이 아니라 날짜 차이**로 셉니다 - 어젯밤
  /// 11시와 오늘 새벽 1시는 두 시간 차이지만 아이에게는 "어제"와 "오늘"입니다.
  /// (`free_talk_character_card.dart` 와 같은 규칙)
  String? _lastTalkedLabel() {
    final DateTime? last = character.lastTalkedAt;
    if (last == null) return null;
    final DateTime now = DateTime.now();
    final int days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(last.year, last.month, last.day)).inDays;
    return FreeTalkStrings.lastTalked(days < 0 ? 0 : days);
  }
}
