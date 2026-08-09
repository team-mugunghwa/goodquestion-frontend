import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/exceptions.dart';
import '../dtos/story_dto.dart';

/// 번들된 더미 JSON 에서 이야기 목록·상세를 읽습니다.
/// 서버가 나오면 `StoryRemoteDataSource` 로 갈아 끼웁니다.
/// → `docs/DECISIONS.md` 015
class StoryLocalDataSource {
  const StoryLocalDataSource({this.bundle});

  /// 테스트에서 다른 번들을 끼워 넣기 위해 열어 둔 자리입니다.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  Future<StoryCatalogDto> fetchCatalog() async {
    final Map<String, dynamic> json = await _readObject(
      AppAssets.storiesListDummy,
    );
    return StoryCatalogDto.fromJson(json);
  }

  /// 없는 id 면 `null`. 예외를 던지지 않습니다 —
  /// "잘못된 주소"와 "로드 실패"는 화면이 다르게 그려야 합니다.
  Future<StoryDetailDto?> fetchStoryDetail(int storyId) async {
    final Map<String, dynamic> all = await _readObject(
      AppAssets.storyDetailsDummy,
    );
    final Object? entry = all['$storyId'];
    if (entry is! Map<String, dynamic>) return null;
    return StoryDetailDto.fromJson(entry);
  }

  Future<Map<String, dynamic>> _readObject(String asset) async {
    final String raw = await _assets.loadString(asset);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ParseException('$asset 의 최상위가 객체가 아닙니다.');
    }
    return decoded;
  }
}
