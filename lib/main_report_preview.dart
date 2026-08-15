import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/mypage/data/datasources/my_page_local_data_source.dart';
import 'features/mypage/data/repositories/my_page_repository_mock.dart';
import 'features/mypage/domain/usecases/my_page_use_cases.dart';
import 'features/mypage/presentation/viewmodels/report_detail_view_model.dart';
import 'features/mypage/presentation/views/report_detail_view.dart';

/// 백엔드와 로그인 없이 보호자 리포트 상세 UI를 확인하는 개발용 진입점입니다.
///
/// flutter run -d chrome -t lib/main_report_preview.dart
void main() {
  final MyPageRepositoryMock repository = MyPageRepositoryMock(
    const MyPageLocalDataSource(),
    latency: Duration.zero,
  );
  runApp(_ReportPreviewApp(repository: repository));
}

class _ReportPreviewApp extends StatelessWidget {
  const _ReportPreviewApp({required this.repository});

  final MyPageRepositoryMock repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 보호자 리포트 미리보기',
      theme: AppTheme.light,
      home: ChangeNotifierProvider<ReportDetailViewModel>(
        create: (_) => ReportDetailViewModel(
          GetReportDetailUseCase(repository),
          sessionId: '104',
        )..load(),
        child: const ReportDetailView(),
      ),
    );
  }
}
