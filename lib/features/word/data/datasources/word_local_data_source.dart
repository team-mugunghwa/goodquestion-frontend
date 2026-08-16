import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/exceptions.dart';
import '../dtos/word_response_dto.dart';

/// 번들된 더미 JSON 에서 단어장을 읽습니다.
/// 더미는 서버 `GET /children/{childId}/words` 응답(`List<WordResponse>`)과
/// 1:1 입니다. → `docs/DECISIONS.md` 015
class WordLocalDataSource {
  const WordLocalDataSource({this.bundle});

  /// 테스트에서 다른 번들을 끼워 넣기 위해 열어 둔 자리입니다.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  Future<List<WordResponseDto>> fetchWords() async {
    final String raw = await _assets.loadString(AppAssets.wordsDummy);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const ParseException('단어장 더미(words_screen.json)의 최상위가 배열이 아닙니다.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WordResponseDto.fromJson)
        .toList(growable: false);
  }
}
