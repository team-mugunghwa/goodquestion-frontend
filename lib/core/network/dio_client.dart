import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';

/// 앱 전체가 공유하는 HTTP 클라이언트.
///
/// **이 파일이 네트워크의 단일 진입점입니다.** feature 안에서 `Dio()` 를
/// 새로 만들지 마세요. 토큰 첨부·에러 변환·로깅이 전부 빠집니다.
///
/// 수정할 때는 팀에 공유하세요. → `docs/CONVENTIONS.md` (충돌이 잦은 파일)
class DioClient {
  /// [dio] 는 테스트에서 가짜 인스턴스를 주입하기 위한 것입니다.
  /// 실제 코드에서는 넘기지 마세요.
  DioClient({Dio? dio, TokenProvider? tokenProvider})
    : _dio = dio ?? Dio(),
      // 이름 있는 매개변수는 밑줄로 시작할 수 없어 초기화 형식 매개변수를 쓸 수 없습니다.
      // ignore: prefer_initializing_formals
      _tokenProvider = tokenProvider {
    _dio.options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      // 4xx/5xx 도 예외로 던지지 않고 우리가 직접 처리합니다.
      validateStatus: (status) => status != null && status < 500,
    );

    _dio.interceptors.add(_authInterceptor());
    if (AppConfig.enableNetworkLog) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          // debugPrint 는 시그니처가 달라 그대로 넘길 수 없습니다.
          logPrint: (line) => debugPrint(line.toString()),
        ),
      );
    }
  }

  final Dio _dio;
  final TokenProvider? _tokenProvider;

  Dio get raw => _dio;

  InterceptorsWrapper _authInterceptor() => InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  );

  /// GET 요청 후 `data` 를 [parse] 로 변환해 돌려줍니다.
  ///
  /// 성공/실패 판별과 예외 변환이 여기서 끝나므로, DataSource 는
  /// 엔드포인트와 파싱 함수만 신경 쓰면 됩니다.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? data) parse,
  }) => _request(
    () => _dio.get<dynamic>(path, queryParameters: queryParameters),
    parse,
  );

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) => _request(() => _dio.post<dynamic>(path, data: body), parse);

  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) => _request(() => _dio.patch<dynamic>(path, data: body), parse);

  Future<void> delete(String path) =>
      _request<void>(() => _dio.delete<dynamic>(path), (_) {});

  Future<T> _request<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Object? data) parse,
  ) async {
    try {
      final response = await send();
      final status = response.statusCode ?? 0;
      final body = response.data;

      if (status == 401) {
        final map = body is Map<String, dynamic> ? body : null;
        final error = map?['error'];
        final String? message = error is Map<String, dynamic>
            ? error['message'] as String?
            : map?['message'] as String?;
        throw UnauthorizedException(message ?? '로그인이 필요합니다.');
      }
      if (status < 200 || status >= 300) {
        final map = body is Map<String, dynamic> ? body : null;
        final error = map?['error'];
        throw ServerException(
          message: error is Map<String, dynamic>
              ? (error['message'] as String? ?? '요청을 처리하지 못했습니다.')
              : (map?['message'] as String? ?? '요청을 처리하지 못했습니다.'),
          code: error is Map<String, dynamic>
              ? (error['code'] as String? ?? 'UNKNOWN')
              : (map?['code'] as String? ?? 'UNKNOWN'),
          statusCode: status,
        );
      }

      // 일부 API는 {success,data}, 백엔드는 DTO/목록을 그대로 반환합니다.
      if (body is Map<String, dynamic> && body.containsKey('success')) {
        if (body['success'] != true) {
          throw const ServerException(
            message: '요청을 처리하지 못했습니다.',
            code: 'UNKNOWN',
          );
        }
        return parse(body['data']);
      }
      return parse(body);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  AppException _mapDioException(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      '서버 응답이 너무 느립니다. 잠시 후 다시 시도해 주세요.',
    ),
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => NetworkException(
      kDebugMode
          ? '백엔드에 연결할 수 없습니다. (${AppConfig.apiBaseUrl})'
          : '네트워크에 연결할 수 없습니다.',
    ),
    DioExceptionType.badCertificate => const NetworkException(
      '보안 인증서에 문제가 있습니다.',
    ),
    DioExceptionType.cancel => const NetworkException('요청이 취소되었습니다.'),
    DioExceptionType.badResponse => ServerException(
      message: '서버 오류가 발생했습니다.',
      code: 'INTERNAL_ERROR',
      statusCode: e.response?.statusCode,
    ),
    // dio 가 새 타입을 추가해도 앱이 깨지지 않게 기본 케이스를 둡니다.
    _ => const NetworkException(),
  };
}

/// 저장된 액세스 토큰을 돌려주는 함수.
///
/// 인증 기능을 붙일 때 `flutter_secure_storage` 에서 읽어오도록 구현하고
/// `injector.dart` 에서 주입하세요. **`SharedPreferences` 에 토큰을 저장하지 않습니다.**
typedef TokenProvider = Future<String?> Function();
