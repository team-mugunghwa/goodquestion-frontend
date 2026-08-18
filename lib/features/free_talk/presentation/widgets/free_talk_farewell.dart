import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../play/presentation/character/dialogue_character_stage.dart';
import '../../../play/presentation/character/dialogue_character_state_machine.dart';

/// "또 만나자" — 자유 대화가 닫힌 뒤 마지막으로 남는 화면.
///
/// **뒤가 비치지 않는 한 장입니다.** 대화 화면 위에 반투명 막을 덮으면 아래의
/// 마이크 안내("이제 말할 차례예요")가 그대로 읽히는데, 대화가 끝난 시점이라
/// 사실이 아닙니다. (`play_view.dart` 의 전환 화면과 같은 이유)
///
/// 나가는 문을 **두 개** 둡니다. 아이 화면에서 선택지는 보통 하나지만, 여기는
/// 막다른 길이 아니라 갈림길입니다 — 다른 인물과 더 이야기하고 싶으면 이야기로,
/// 오늘은 그만하고 싶으면 홈으로 갑니다.
class FreeTalkFarewellScreen extends StatelessWidget {
  const FreeTalkFarewellScreen({
    required this.characterName,
    required this.closingText,
    required this.onHome,
    required this.onStory,
    this.character,
    super.key,
  });

  final String characterName;

  /// 캐릭터가 마지막으로 한 말. 서버가 준 문장을 그대로 씁니다.
  final String closingText;

  /// 표정 무대. 없으면 글자만 남습니다.
  final DialogueCharacterStateMachine? character;

  final VoidCallback onHome;
  final VoidCallback onStory;

  @override
  Widget build(BuildContext context) {
    final DialogueCharacterStateMachine? stage = character;
    // **탭을 흘려보내지 않습니다.** 그림만 덮으면 아래 대화 화면의 상단
    // 버튼(나가기·다시 듣기·소리)이 안 보이는 채로 그대로 눌립니다 -
    // DecoratedBox 는 자기 면으로 히트테스트를 받지 않기 때문입니다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: AppCanvas.day(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (stage != null)
                    SizedBox(
                      height: AppSizes.illustration,
                      child: DialogueCharacterStage(
                        scene: stage.scene,
                        state: stage.current,
                        activity: DialogueActivity.idle,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    FreeTalkStrings.farewellTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.kidTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.bubbleMaxWidth,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      label: '$characterName: $closingText',
                      child: Text(
                        closingText,
                        textAlign: TextAlign.center,
                        style: AppTypography.kidBody,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      KidPrimaryButton(
                        icon: AppIcons.home,
                        label: FreeTalkStrings.farewellHome,
                        onPressed: onHome,
                      ),
                      KidSecondaryButton(
                        icon: AppIcons.stories,
                        label: FreeTalkStrings.farewellStory,
                        onPressed: onStory,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "이야기를 그만할까?" — 나가기(X)를 눌렀을 때의 확인 카드.
///
/// 곧바로 닫지 않고 한 번 묻습니다. 잘못 눌렀을 때 되돌릴 틈이 있어야 하기
/// 때문입니다.
///
/// ## 나가는 길을 둘로 벌려 둡니다
///
/// [onFarewell] 은 친구의 작별 인사를 듣고 나가고, [onLeaveNow] 는 인사 없이
/// 곧장 나갑니다. 인사 하나로만 끝내던 것을 굳이 가른 이유는, 이미 나가기로
/// 마음먹은 아이에게 낭독이 끝날 때까지 기다리라고 하면 그 몇 초가 그대로
/// 지루함이 되기 때문입니다(2026-08-18 팀 피드백). 인사는 **남기되 의무로
/// 만들지 않습니다** — 고를 수 있어야 인사가 벌이 아니라 선물이 됩니다.
///
/// ## 버튼은 아이 크기로 세웁니다
///
/// 선택지가 셋이 되면 잘못 누를 확률이 그만큼 올라갑니다. Material 기본
/// 버튼(높이 48)은 [AppSizes] 주석대로 아이 손가락에 부족해서, "또 만나자"
/// 화면과 같은 [KidPrimaryButton]·[KidSecondaryButton](88·64)로 바꿔 세웁니다.
/// 셋을 가로로 늘어놓지 않는 것도 같은 이유입니다 — 폭 340 카드에 셋을 나란히
/// 두면 하나가 손가락보다 좁아집니다. 세로로 쌓으면 각 버튼이 카드 폭을 그대로
/// 쓰고, 늘어나는 것은 카드 높이뿐입니다.
class FreeTalkExitPrompt extends StatelessWidget {
  const FreeTalkExitPrompt({
    required this.onKeep,
    required this.onFarewell,
    required this.onLeaveNow,
    super.key,
  });

  /// 카드를 닫고 하던 이야기로 돌아갑니다.
  final VoidCallback onKeep;

  /// 작별 인사를 받아 들려준 뒤 "또 만나자" 화면으로.
  final VoidCallback onFarewell;

  /// 인사 없이 즉시 홈으로.
  final VoidCallback onLeaveNow;

  /// 카드 **안쪽** 폭.
  static const double _cardWidth = 340;

  /// 바깥 상자의 폭 = 안쪽 폭 + 좌우 여백([AppSpacing.lg] 24 를 두 번).
  /// 더하지 않고 340 을 바깥에 걸면 카드가 292 로 줄어듭니다 — 폭을 눈으로
  /// 어림하지 말고 이렇게 적어 두고 검산합니다.
  static const double _maxWidth = _cardWidth + AppSpacing.lg * 2;

  @override
  Widget build(BuildContext context) {
    // 카드 바깥을 눌러도 아래 화면이 반응하지 않아야 합니다(모달).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: const Color(0xD10C1C2F),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            // 버튼이 셋으로 늘어 카드가 그만큼 길어졌습니다. 가로로 누운 작은
            // 화면에서는 세로가 모자랄 수 있어, 잘리는 대신 밀려 올라가게
            // 둡니다([FreeTalkFarewellScreen] 과 같은 처리).
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              // 버튼 라벨이 들어갈 폭을 **재서** 글자 크기를 정합니다. 이 카드의
              // 버튼은 셋 다 폭을 꽉 채우는데, 그 안의 Text 는 maxLines:1 +
              // ellipsis 라 넘쳐도 예외가 안 나고 조용히 "인사하고 나…" 로
              // 줄어듭니다. 눈으로 보고 넘어가면 못 잡는 자리라 폭에서 계산합니다.
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final ScreenMetrics metrics = ScreenMetrics.of(
                    constraints.maxWidth,
                  );
                  // 카드가 화면에 눌려 제 폭([_cardWidth])을 못 받은 때에만
                  // 안쪽 여백을 줄여 라벨에 폭을 돌려줍니다. 폭이 넉넉한데도
                  // 줄이면 보통 폰(390dp)의 카드 생김새까지 같이 바뀝니다 —
                  // 320dp 에서 24 를 그대로 두면 라벨 상자가 128 밖에 안 남아
                  // "더 이야기하기"(약 131) 가 들어가지 않는 것이 고칠 대상이다.
                  final bool squeezed = constraints.maxWidth < _cardWidth;
                  final double cardPadding = squeezed
                      ? AppSpacing.md
                      : AppSpacing.lg;
                  return Container(
                    padding: EdgeInsets.all(cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          AppIcons.characterSpeaking,
                          color: AppColors.brandBlueDeep,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          FreeTalkStrings.exitTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          FreeTalkStrings.exitMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.ink500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // 되돌아가는 쪽이 가장 큽니다. X 는 대개 잘못 눌러서 닿는
                        // 자리라, 기본값은 "그대로 있기"여야 합니다.
                        KidPrimaryButton(
                          icon: AppIcons.characterSpeaking,
                          label: FreeTalkStrings.exitKeep,
                          onPressed: onKeep,
                          expand: true,
                          labelStyle: metrics.text(AppTypography.kidButton),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // 나가는 두 갈래는 서로 대등합니다. 같은 얼굴로 두고
                        // 아이콘과 글자로만 가릅니다 — 한쪽을 흐리게 만들면
                        // 골라서는 안 되는 것처럼 보입니다.
                        KidSecondaryButton(
                          icon: AppIcons.farewell,
                          label: FreeTalkStrings.exitFarewell,
                          onPressed: onFarewell,
                          expand: true,
                          labelStyle: metrics.text(AppTypography.kidButton),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        KidSecondaryButton(
                          icon: AppIcons.home,
                          label: FreeTalkStrings.exitLeave,
                          onPressed: onLeaveNow,
                          expand: true,
                          labelStyle: metrics.text(AppTypography.kidButton),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
