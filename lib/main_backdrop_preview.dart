import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/story/data/datasources/story_local_data_source.dart';
import 'features/story/data/repositories/story_repository_mock.dart';
import 'features/story/domain/usecases/get_story_catalog_use_case.dart';
import 'features/story/presentation/viewmodels/story_list_view_model.dart';
import 'features/story/presentation/views/story_list_view.dart';
import 'features/word/data/datasources/word_local_data_source.dart';
import 'features/word/data/repositories/word_repository_mock.dart';
import 'features/word/domain/usecases/get_word_book_use_case.dart';
import 'features/word/domain/usecases/toggle_word_like_use_case.dart';
import 'features/word/presentation/viewmodels/word_list_view_model.dart';
import 'features/word/presentation/views/word_list_view.dart';

/// 백엔드·로그인 없이 우주 배경(CosmicBackdrop)이 적용된 로그인 이후
/// 화면(단어장·이야기 목록)을 확인하는 개발용 진입점입니다.
/// 데이터는 번들 더미(목업 Repository)에서 읽습니다.
///
/// 실행:
/// flutter run -d chrome -t lib/main_backdrop_preview.dart --web-port 7366
void main() => runApp(const _BackdropPreviewApp());

final WordRepositoryMock _wordRepository = WordRepositoryMock(
  const WordLocalDataSource(),
);

const StoryRepositoryMock _storyRepository = StoryRepositoryMock(
  StoryLocalDataSource(),
);

final GoRouter _router = GoRouter(
  initialLocation: AppRoutes.words,
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.words,
      builder: (_, _) => ChangeNotifierProvider<WordListViewModel>(
        create: (_) => WordListViewModel(
          GetWordBookUseCase(_wordRepository),
          ToggleWordLikeUseCase(_wordRepository),
        )..load(),
        child: const WordListView(),
      ),
    ),
    GoRoute(
      path: AppRoutes.stories,
      builder: (_, _) => ChangeNotifierProvider<StoryListViewModel>(
        create: (_) =>
            StoryListViewModel(const GetStoryCatalogUseCase(_storyRepository))
              ..load(),
        child: const StoryListView(),
      ),
    ),
    // 프리뷰 범위 밖의 목적지들. 하단 내비·카드 탭이 죽지 않게만 받아 줍니다.
    GoRoute(path: AppRoutes.home, builder: (_, _) => const _OutOfScope()),
    GoRoute(path: AppRoutes.myPage, builder: (_, _) => const _OutOfScope()),
    GoRoute(
      path: AppRoutes.storyDetailPath,
      builder: (_, _) => const _OutOfScope(),
    ),
    GoRoute(
      path: AppRoutes.wordPracticePath,
      builder: (_, _) => const _OutOfScope(),
    ),
  ],
);

class _BackdropPreviewApp extends StatelessWidget {
  const _BackdropPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 우주 배경 미리보기',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

/// 프리뷰가 다루지 않는 화면의 자리 표시.
class _OutOfScope extends StatelessWidget {
  const _OutOfScope();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('미리보기 범위 밖')),
      body: const Center(child: Text('이 화면은 본 앱에서 확인하세요.')),
    );
  }
}
