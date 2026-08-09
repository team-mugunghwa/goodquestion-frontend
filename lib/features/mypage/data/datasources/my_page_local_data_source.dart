import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/exceptions.dart';
import '../dtos/my_page_dto.dart';

/// 보호자 화면 4개의 더미를 읽습니다.
/// → `docs/DECISIONS.md` 015
class MyPageLocalDataSource {
  const MyPageLocalDataSource({this.bundle});

  /// 테스트에서 다른 번들을 끼워 넣기 위해 열어 둔 자리입니다.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  Future<MyPageSummaryDto> fetchSummary() async =>
      MyPageSummaryDto.fromJson(await _readObject(AppAssets.myPageDummy));

  Future<ReportListDto> fetchReportList() async =>
      ReportListDto.fromJson(await _readObject(AppAssets.reportListDummy));

  /// 없는 세션이면 `null`.
  Future<ReportDetailDto?> fetchReportDetail(int sessionId) async {
    final Map<String, dynamic> all = await _readObject(
      AppAssets.reportDetailsDummy,
    );
    final Object? entry = all['$sessionId'];
    if (entry is! Map<String, dynamic>) return null;
    return ReportDetailDto.fromJson(entry);
  }

  Future<AppSettingsDto> fetchSettings() async =>
      AppSettingsDto.fromJson(await _readObject(AppAssets.settingsDummy));

  Future<Map<String, dynamic>> _readObject(String asset) async {
    final String raw = await _assets.loadString(asset);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ParseException('$asset 의 최상위가 객체가 아닙니다.');
    }
    return decoded;
  }
}
