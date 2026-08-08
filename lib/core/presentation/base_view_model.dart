import 'package:flutter/foundation.dart';

import '../error/failure.dart';
import '../state/view_state.dart';

/// 모든 ViewModel 의 부모.
///
/// ## 규칙
/// - `package:flutter/material.dart` 를 import 하지 않습니다. (`foundation.dart` 만)
/// - **`BuildContext` 를 필드로 갖지 않습니다.** 화면 이동·스낵바가 필요하면
///   ViewModel 은 상태만 바꾸고 View 가 반응하게 하세요. 그래야 단위 테스트가 됩니다.
/// - DTO·`Response` 를 들고 있지 않습니다. domain Entity 만 보관합니다.
abstract class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  bool _disposed = false;

  ViewState get state => _state;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state.isLoading;

  @protected
  void setLoading() => _setState(ViewState.loading, null);

  @protected
  void setSuccess() => _setState(ViewState.success, null);

  @protected
  void setError(Object error) => _setState(
    ViewState.error,
    error is Failure ? error.message : Failure.fromException(error).message,
  );

  void _setState(ViewState next, String? message) {
    _state = next;
    _errorMessage = message;
    safeNotify();
  }

  /// dispose 이후에 `notifyListeners()` 를 부르면 앱이 죽습니다.
  ///
  /// 비동기 요청이 끝나기 전에 사용자가 화면을 나가면 실제로 자주 발생합니다.
  /// ViewModel 안에서는 `notifyListeners()` 대신 이 메서드를 쓰세요.
  @protected
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// 로딩 → 실행 → 성공/실패 를 한 번에 처리하는 헬퍼.
  ///
  /// ```dart
  /// Future<void> load() => guard(() async {
  ///       _questions = await _getQuestions();
  ///     });
  /// ```
  @protected
  Future<void> guard(Future<void> Function() action) async {
    setLoading();
    try {
      await action();
      setSuccess();
    } catch (e) {
      setError(e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
