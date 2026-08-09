import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/exceptions.dart';
import '../dtos/home_summary_dto.dart';

/// 앱에 번들된 더미 JSON 을 읽습니다. 서버가 나오기 전까지의 임시 출처입니다.
///
/// 더미를 `Map` 리터럴로 코드에 박지 않고 **파일로 두는 이유**: 기획이 바꾼
/// 문구·개수를 코드 수정 없이 반영할 수 있고, 파일 모양이 곧 서버와의 계약
/// 초안이 되기 때문입니다. → `docs/DECISIONS.md` 015
class HomeLocalDataSource {
  const HomeLocalDataSource({this.bundle});

  /// 테스트에서 다른 번들을 끼워 넣기 위해 열어 둔 자리입니다.
  /// `null` 이면 앱에 번들된 [rootBundle] 을 씁니다.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  /// 더미를 읽어 DTO 로 만듭니다.
  ///
  /// 파일이 없거나 JSON 이 깨졌으면 [ParseException] 을 던집니다.
  /// 화면은 이걸 `Failure` 로 받아 "다시 불러오기" 버튼을 띄웁니다.
  Future<HomeSummaryDto> fetchHomeSummary() async {
    final String raw = await _assets.loadString(AppAssets.homeDummy);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const ParseException('홈 더미(home.json)의 최상위가 객체가 아닙니다.');
    }
    return HomeSummaryDto.fromJson(decoded);
  }
}
