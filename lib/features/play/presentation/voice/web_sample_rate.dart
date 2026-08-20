/// 웹에서 마이크가 실제로 협상한 샘플레이트를 읽는 플랫폼 분기.
///
/// `record_web`(우리가 쓰는 record 패키지의 웹 구현)은 `getUserMedia`로 연
/// 오디오 트랙의 `getSettings().sampleRate`를 읽어 그 값으로 `AudioContext`를
/// 열고, 그 컨텍스트로 실제 오디오 처리를 합니다(record_web
/// `recorder_delegate.dart`의 `_adjustContext`) - 즉 실제로 녹음되는
/// 샘플레이트는 우리가 요청한 값도, 출력 장치 기본값도 아니라 **마이크가
/// 협상한 값**입니다. 이 함수는 같은 값을 같은 출처에서 미리 읽어 옵니다.
///
/// 네이티브(Android/iOS 등)는 record 패키지가 요청한 샘플레이트를 실제로
/// 리샘플링해 그대로 돌려주므로 이 값이 필요 없습니다 - 스텁 구현이 늘 null을
/// 돌려주고, 호출부도 웹일 때만 부릅니다.
library;

export 'web_sample_rate_stub.dart'
    if (dart.library.js_interop) 'web_sample_rate_web.dart';
