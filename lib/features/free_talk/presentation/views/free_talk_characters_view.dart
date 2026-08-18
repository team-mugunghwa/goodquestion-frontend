import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../play/presentation/character/dialogue_character_manifest.dart';
import '../../domain/entities/free_talk.dart';
import '../../domain/repositories/free_talk_repository.dart';
import '../widgets/free_talk_character_card.dart';

/// "누구랑 더 이야기해볼까?" — 완주한 이야기의 인물을 고르는 화면.
///
/// ## 완주하지 않은 이야기로 들어오면
///
/// 서버가 404(또는 403)로 돌려세웁니다. 그때 **에러 화면을 띄우지 않습니다** —
/// 아이가 뭔가 잘못한 게 아니라 아직 안 들은 것뿐이라, "끝까지 들으면 친구들이
/// 기다린다"고 말하고 이야기로 돌려보냅니다.
///
/// 정상 경로에서는 이 화면이 완주 직후 완료 화면에서만 열리므로 이 분기를 볼
/// 일이 없습니다. 주소로 바로 들어오는 경우를 위한 방벽입니다.
class FreeTalkCharactersPage extends StatefulWidget {
  const FreeTalkCharactersPage({
    required this.storyId,
    required this.repository,
    super.key,
  });

  final String storyId;
  final FreeTalkRepository repository;

  @override
  State<FreeTalkCharactersPage> createState() => _FreeTalkCharactersPageState();
}

class _FreeTalkCharactersPageState extends State<FreeTalkCharactersPage> {
  List<FreeTalkCharacter> _characters = const <FreeTalkCharacter>[];
  DialogueCharacterManifest? _manifest;
  bool _loading = true;

  /// 다시 시도할 수 있는 실패. 완주 전(404)은 여기 담지 않습니다 — 다시
  /// 눌러도 같은 답이 오므로 재시도 버튼을 주면 안 됩니다.
  String? _loadError;

  /// 완주 전이라 들어올 수 없는 이야기.
  bool _notCompleted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadManifest());
    unawaited(_load());
  }

  /// 표정 에셋 매니페스트. **실패해도 화면이 죽지 않습니다** — 카드는 서버
  /// 썸네일이나 기본 그림으로 떨어집니다. (`play_view.dart` 와 같은 원칙)
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _notCompleted = false;
    });
    try {
      final List<FreeTalkCharacter> characters = await widget.repository
          .characters(widget.storyId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _characters = characters;
      });
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notCompleted = _isNotCompleted(error);
        _loadError = _notCompleted ? null : FreeTalkStrings.pickFailed;
      });
    }
  }

  /// 완주 전이라 막힌 것인지. 서버는 404(그 이야기를 안 끝냄)와 403(아이가
  /// 다름)을 같은 자리에서 씁니다 — 아이에게는 둘 다 "아직 못 들어가"입니다.
  bool _isNotCompleted(Failure error) {
    if (error is UnauthorizedFailure) return true;
    if (error is! ServerFailure) return false;
    return error.code == 'STORY_NOT_COMPLETED' ||
        error.code == 'FREE_TALK_NOT_AVAILABLE' ||
        error.code == 'NOT_FOUND' ||
        error.code == 'FORBIDDEN';
  }

  void _openChat(FreeTalkCharacter character) {
    context.go(
      AppRoutes.freeTalkChatOf(widget.storyId, character.characterId),
      extra: character,
    );
  }

  /// 뒤로 — 완료 화면에서 `go` 로 들어와 되돌아갈 화면이 없을 수 있습니다.
  /// 그때는 이야기 상세로 보냅니다(홈보다 가까운 자리입니다).
  void _back() {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null || Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    router.go(AppRoutes.storyDetailOf(widget.storyId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.day(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final ScreenMetrics metrics = ScreenMetrics.of(
                constraints.maxWidth,
              );
              return Padding(
                padding: EdgeInsets.all(metrics.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    KidBackButton(
                      onPressed: _back,
                      labelStyle: metrics.text(AppTypography.kidLabel),
                    ),
                    SizedBox(height: metrics.screenPadding),
                    Text(
                      FreeTalkStrings.pickTitle,
                      style: metrics.text(AppTypography.kidTitle),
                    ),
                    SizedBox(height: metrics.screenPadding),
                    Expanded(child: _buildBody(metrics)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ScreenMetrics metrics) {
    if (_loading) return const AppLoadingView();

    if (_notCompleted) {
      return AppKidMessageView(
        message: FreeTalkStrings.notCompleted,
        messageStyle: metrics.text(AppTypography.kidBody),
        actionIcon: AppIcons.stories,
        actionLabel: FreeTalkStrings.farewellStory,
        onAction: _back,
      );
    }

    final String? error = _loadError;
    if (error != null) {
      return AppKidErrorView(
        message: error,
        messageStyle: metrics.text(AppTypography.kidBody),
        onRetry: () => unawaited(_load()),
      );
    }

    if (_characters.isEmpty) {
      return AppKidEmptyView(
        message: FreeTalkStrings.noCharacters,
        messageStyle: metrics.text(AppTypography.kidBody),
        actionIcon: AppIcons.stories,
        actionLabel: FreeTalkStrings.farewellStory,
        onAction: _back,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.only(bottom: metrics.screenPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.isWide ? 3 : 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        // 세로로 더 길게 잡으면 태블릿 가로(1280x720)에서 카드 한 장이
        // 화면보다 커집니다 - 이름이 접힌 화면 밖으로 나가서 아이가 누구인지
        // 못 읽고, 눌러도 안 눌립니다(실제로 그랬습니다).
        childAspectRatio: .9,
      ),
      itemCount: _characters.length,
      itemBuilder: (BuildContext context, int index) {
        final FreeTalkCharacter character = _characters[index];
        return FreeTalkCharacterCard(
          character: character,
          metrics: metrics,
          scene: _manifest?.sceneForCharacter(
            characterId: character.characterId,
            name: character.name,
          ),
          onTap: () => _openChat(character),
        );
      },
    );
  }
}
