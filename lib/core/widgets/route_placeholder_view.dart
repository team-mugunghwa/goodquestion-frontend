import 'package:flutter/material.dart';

/// 아직 내용이 없는 화면의 자리 표시자.
///
/// 라우터 골격을 먼저 세우기 위한 것입니다. 각 화면 담당자는 자기 View 에서
/// 이 위젯을 걷어내고 실제 UI 로 바꾸세요. **새 화면을 만들 때 이걸 계속
/// 쓰지 마세요.**
class RoutePlaceholderView extends StatelessWidget {
  const RoutePlaceholderView({
    required this.path,
    required this.title,
    super.key,
  });

  /// 실제로 열린 경로. 파라미터가 있으면 채워진 값이 들어옵니다. (`/stories/12`)
  final String path;

  /// 화면 이름. (`이야기 상세`)
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '$path - $title',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
