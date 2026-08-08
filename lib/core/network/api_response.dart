import '../error/exceptions.dart';

/// 서버 공통 응답 봉투.
///
/// ```json
/// { "success": true, "data": { ... }, "error": null }
/// { "success": false, "data": null, "error": { "code": "...", "message": "..." } }
/// ```
///
/// 백엔드와의 합의 사항입니다. → `docs/API.md`
class ApiResponse<T> {
  const ApiResponse({required this.success, this.data, this.error});

  final bool success;
  final T? data;
  final ApiError? error;

  /// [fromData] 는 `data` 필드(JSON)를 원하는 타입으로 바꾸는 함수입니다.
  ///
  /// ```dart
  /// ApiResponse.fromJson(json, (d) => QuestionDto.fromJson(d as Map<String, dynamic>))
  /// ```
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) fromData,
  ) {
    final success = json['success'] as bool? ?? false;
    final rawError = json['error'];

    return ApiResponse<T>(
      success: success,
      data: success && json['data'] != null ? fromData(json['data']) : null,
      error: rawError is Map<String, dynamic>
          ? ApiError.fromJson(rawError)
          : null,
    );
  }

  /// 성공이면 데이터를 꺼내고, 실패면 [ServerException] 을 던집니다.
  ///
  /// DataSource 에서 이걸 쓰면 매번 success 를 검사하는 코드를 안 써도 됩니다.
  T unwrap() {
    if (!success || data == null) {
      throw ServerException(
        message: error?.message ?? '요청을 처리하지 못했습니다.',
        code: error?.code ?? 'UNKNOWN',
      );
    }
    return data as T;
  }
}

class ApiError {
  const ApiError({required this.code, required this.message});

  /// 프론트는 이 값으로 분기합니다. HTTP 상태 코드나 message 문자열로 분기하지 마세요.
  final String code;
  final String message;

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
    code: json['code'] as String? ?? 'UNKNOWN',
    message: json['message'] as String? ?? '알 수 없는 오류가 발생했습니다.',
  );
}

/// 페이지네이션 응답.
///
/// ⚠️ `page` 는 **1부터** 시작하기로 합의했습니다.
/// Spring 의 `Page<T>` 는 0부터라서, 백엔드가 그대로 내려주면 첫 페이지가
/// 통째로 빠지는 버그가 납니다. 연동 시 반드시 확인하세요. → `docs/API.md`
class PageResponse<T> {
  const PageResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromItem,
  ) {
    final rawItems = json['items'];
    return PageResponse<T>(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(fromItem)
                .toList(growable: false)
          : const [],
      page: json['page'] as int? ?? 1,
      size: json['size'] as int? ?? 0,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}
