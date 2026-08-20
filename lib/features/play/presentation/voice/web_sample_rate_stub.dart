/// 웹이 아닌 플랫폼의 대체 구현.
///
/// 네이티브에서는 record 패키지가 요청한 샘플레이트를 실제로 리샘플링해
/// 그대로 돌려주므로 이 함수가 호출되지 않습니다(호출부가 kIsWeb일 때만
/// 부릅니다). 조건부 export의 두 구현이 같은 시그니처를 가져야 해서 남겨둡니다.
Future<int?> readWebMicSampleRate() async => null;
