/// 모든 화면이 공유하는 상태 표현.
///
/// 화면마다 `isLoading`, `busy`, `loaded` 같은 필드를 제각각 만들면
/// 4명이 각자 다른 방식으로 로딩/에러를 그리게 됩니다. 전 ViewModel 이
/// 이 enum 하나만 씁니다.
enum ViewState {
  /// 아직 아무것도 시작하지 않음.
  idle,

  /// 요청 진행 중.
  loading,

  /// 성공. 데이터가 준비됨.
  success,

  /// 실패. `errorMessage` 를 표시.
  error;

  bool get isLoading => this == ViewState.loading;
  bool get isError => this == ViewState.error;
  bool get isSuccess => this == ViewState.success;
}
