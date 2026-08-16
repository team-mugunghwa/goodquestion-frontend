import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/widgets/cosmic_backdrop.dart';

/// `test/` 아래 모든 테스트가 시작하기 전에 한 번 불립니다.
/// (파일 이름이 `flutter_test_config.dart` 여야 flutter_test 가 찾아 씁니다)
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 우주 배경의 반짝임은 무한 반복이라 pumpAndSettle 이 끝나지 않습니다.
  // 테스트에서는 멈춘 별만 그립니다.
  CosmicBackdrop.animationsEnabled = false;

  goldenFileComparator = _TolerantGoldenComparator(
    // LocalFileComparator 는 넘긴 파일의 **디렉터리**를 기준 경로로 씁니다.
    // 골든 경로를 'goldens/x.png' 처럼 상대경로로 쓰고 있어서, 기본 비교기가
    // 이미 잡아 둔 기준 경로를 그대로 물려받아야 합니다.
    Uri.parse('${(goldenFileComparator as LocalFileComparator).basedir}x.dart'),
  );
  await testMain();
}

/// 아주 작은 픽셀 차이를 통과시키는 골든 비교기.
///
/// ## 왜 필요한가
///
/// 골든 PNG 는 만든 사람의 OS 에서 찍힙니다. 그런데 CI 는 리눅스라 **글자
/// 안티에일리어싱이 미세하게 달라서** 눈에는 똑같은 화면이 픽셀 비교에서는
/// 어긋납니다. 실제로 이 저장소에서 나던 차이는 0.33% 와 0.78% 였고, 레이아웃이
/// 아니라 글자 테두리 수준이었습니다.
///
/// 그대로 두면 CI 가 상시 빨간불이 되는데, 그게 골든이 잡아야 할 진짜 회귀보다
/// 위험합니다. "원래 빨간불"이 되는 순간 아무도 CI 를 안 보게 됩니다.
///
/// ## 한계 — 이 값을 올리지 마세요
///
/// [_threshold] 는 **글자 렌더링 차이를 덮을 만큼만** 두었습니다. 색이 바뀌거나
/// 요소가 사라지는 정도의 회귀는 이 값을 훌쩍 넘기므로 여전히 잡힙니다.
/// 골든이 실패할 때 이 값을 올려서 통과시키는 건, 회귀를 못 잡게 만드는 것과
/// 같습니다. 실패하면 먼저 diff 이미지(`failures/`)를 열어 보세요.
///
/// 더 나은 해결은 CI 와 같은 환경(리눅스)에서 골든을 다시 뽑는 것입니다.
/// 그 준비가 되면 이 파일은 지워도 됩니다.
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  /// 1% = 1280x720 기준 약 9200px. 관측된 차이(0.33%, 0.78%)보다 조금 위입니다.
  static const double _threshold = 0.01;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed) {
      result.dispose();
      return true;
    }

    if (result.diffPercent <= _threshold) {
      // 통과시키되 조용히 넘어가지는 않습니다. 임계값 아래 차이가 계속 쌓이면
      // 골든이 실제 화면과 서서히 멀어지는데, 로그가 없으면 눈치채지 못합니다.
      debugPrint(
        '골든 "${golden.pathSegments.last}" 차이 '
        '${(result.diffPercent * 100).toStringAsFixed(2)}% — '
        '허용치(${(_threshold * 100).toStringAsFixed(0)}%) 안이라 통과시킵니다.',
      );
      result.dispose();
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
