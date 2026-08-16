import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 뒤로 가기 - 스택이 있으면 pop, 없으면 [fallback] 으로 이동합니다.
///
/// 알림 딥링크(`/support/{inquiryId}`)나 주소 직접 입력으로 화면에 곧장
/// 들어오면 pop 할 스택이 없습니다. 이때 `context.pop()` 은
/// `GoError: There is nothing to pop` 을 던져 뒤로 버튼이 죽은 것처럼
/// 보입니다(실서버에서 재현). 갈 곳을 정해 보내는 쪽이 낫습니다.
void popOrGo(BuildContext context, String fallback, {Object? result}) {
  if (context.canPop()) {
    context.pop(result);
  } else {
    context.go(fallback);
  }
}
