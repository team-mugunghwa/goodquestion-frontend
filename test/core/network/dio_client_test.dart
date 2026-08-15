import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/exceptions.dart';
import 'package:goodquestion/core/network/dio_client.dart';

/// 요청 경로별로 정해 둔 응답을 순서대로 돌려주는 가짜 어댑터.
///
/// 실제 서버 없이 "401 → 재발급 → 재시도" 흐름을 확인하려면 같은 경로로
/// 두 번째 호출됐을 때 다른 응답을 줄 수 있어야 합니다 — 그래서 경로별로
/// 응답을 큐에 쌓아 두고 호출될 때마다 하나씩 꺼냅니다.
class _QueuedAdapter implements HttpClientAdapter {
  final Map<String, List<ResponseBody Function()>> _queues =
      <String, List<ResponseBody Function()>>{};
  final List<String> requestedPaths = <String>[];

  void enqueue(String path, ResponseBody Function() response) {
    _queues.putIfAbsent(path, () => <ResponseBody Function()>[]).add(response);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    final List<ResponseBody Function()>? queue = _queues[options.path];
    if (queue == null || queue.isEmpty) {
      throw StateError('예상하지 못한 요청: ${options.path}');
    }
    return queue.removeAt(0)();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object? data, int statusCode) => ResponseBody.fromString(
  jsonEncode(data),
  statusCode,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

void main() {
  late _QueuedAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _QueuedAdapter();
    dio = Dio()..httpClientAdapter = adapter;
  });

  test('401을 받으면 재발급 후 한 번 더 시도해 성공한다', () async {
    adapter.enqueue(
      '/children',
      () => _jsonBody(<String, dynamic>{'code': 'UNAUTHORIZED'}, 401),
    );
    adapter.enqueue(
      '/children',
      () => _jsonBody(<Map<String, dynamic>>[
        <String, dynamic>{'id': '1'},
      ], 200),
    );

    bool refreshCalled = false;
    final client = DioClient(
      dio: dio,
      tokenRefresher: () async {
        refreshCalled = true;
        return true;
      },
      onUnauthorized: () => fail('재발급이 됐으면 로그아웃을 부르면 안 됩니다'),
    );

    final result = await client.get<int>(
      '/children',
      parse: (Object? data) => (data as List<dynamic>).length,
    );

    expect(result, 1);
    expect(refreshCalled, isTrue);
    expect(adapter.requestedPaths, <String>['/children', '/children']);
  });

  test('재발급 자체가 실패하면 로그아웃 훅을 부른다', () async {
    adapter.enqueue(
      '/children',
      () => _jsonBody(<String, dynamic>{'code': 'UNAUTHORIZED'}, 401),
    );

    bool unauthorizedCalled = false;
    final client = DioClient(
      dio: dio,
      tokenRefresher: () async => false,
      onUnauthorized: () => unauthorizedCalled = true,
    );

    await expectLater(
      client.get<int>(
        '/children',
        parse: (Object? data) => (data as List<dynamic>).length,
      ),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(unauthorizedCalled, isTrue);
    // 재발급이 실패했으니 재시도는 없어야 합니다 — 요청은 한 번만.
    expect(adapter.requestedPaths, <String>['/children']);
  });

  test('로그인 요청 자체의 401은 재발급을 시도하지 않는다', () async {
    adapter.enqueue(
      '/auth/login',
      () => _jsonBody(<String, dynamic>{'code': 'INVALID_CREDENTIALS'}, 401),
    );

    final client = DioClient(
      dio: dio,
      tokenRefresher: () async {
        fail('로그인 실패를 토큰 만료로 착각하면 안 됩니다');
      },
      onUnauthorized: () => fail('로그인 실패는 로그아웃이 아닙니다'),
    );

    await expectLater(
      client.post<void>('/auth/login', parse: (_) {}),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(adapter.requestedPaths, <String>['/auth/login']);
  });
}
