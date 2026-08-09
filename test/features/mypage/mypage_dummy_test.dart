import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/mypage/data/datasources/my_page_local_data_source.dart';
import 'package:goodquestion/features/mypage/data/repositories/my_page_repository_mock.dart';
import 'package:goodquestion/features/mypage/domain/entities/app_settings.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_detail.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_summary.dart';

/// 보호자 화면 더미가 화면이 기대하는 모양인지 검사합니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MyPageRepositoryMock repositoryOf() => MyPageRepositoryMock(
    const MyPageLocalDataSource(),
    latency: Duration.zero,
  );

  test('마이페이지 더미가 파싱된다', () async {
    final MyPageSummary summary = await repositoryOf().getSummary();

    expect(summary.child?.name, isNotEmpty);
    expect(summary.child?.age, greaterThan(0));
    // 전환 버튼 강조 분기를 시연하려면 아이가 2명 이상이어야 합니다.
    expect(summary.canSwitchChild, isTrue);
    expect(summary.hasNewReport, isTrue);
  });

  test('리포트 목록 더미의 개수가 실제와 맞는다', () async {
    final ReportList list = await repositoryOf().getReportList();

    expect(list.reports, isNotEmpty);
    expect(list.totalCount, list.reports.length);
    expect(
      list.newCount,
      list.reports.where((ReportSummary r) => r.isNew).length,
    );
    // 반복 회차 케이스가 없으면 회차 표기가 의미 있는지 확인할 수 없습니다.
    expect(list.reports.any((ReportSummary r) => r.playCount > 1), isTrue);
  });

  test('리포트를 읽으면 NEW 와 마이페이지 배지가 함께 사라진다', () async {
    final MyPageRepositoryMock repository = repositoryOf();
    final ReportList before = await repository.getReportList();
    final ReportSummary unread = before.reports.firstWhere(
      (ReportSummary r) => r.isNew,
    );

    await repository.markAsRead(unread.sessionId);

    final ReportList after = await repository.getReportList();
    expect(after.newCount, 0);
    // 목록과 마이페이지가 어긋나면 보호자는 안 읽은 게 남은 줄 압니다.
    expect((await repository.getSummary()).hasNewReport, isFalse);
  });

  test('리포트 상세 더미가 5단 구조를 갖춘다', () async {
    final ReportDetail? report = await repositoryOf().getReportDetail(104);

    expect(report, isNotNull);
    expect(report!.summary, isNotEmpty);
    expect(report.skills, hasLength(3), reason: '어휘·표현·논리 세 영역');
    for (final SkillReport skill in report.skills) {
      expect(skill.name, isNotEmpty);
      expect(skill.feature, isNotEmpty);
      expect(skill.strength, isNotEmpty);
      expect(skill.improvement, isNotEmpty);
    }
    expect(report.highlight.utterance, isNotEmpty);
    expect(report.questionGroups, hasLength(2));
  });

  test('리포트 텍스트에 내부 태그가 새어 나오지 않는다', () async {
    final ReportDetail report = (await repositoryOf().getReportDetail(104))!;
    // PRD F-09 — DECISION·REASON 같은 내부 태그가 보호자에게 보이면 실패입니다.
    const List<String> forbidden = <String>[
      'DECISION',
      'REASON',
      'TAG',
      'EMOTION',
    ];
    final String all = <String>[
      report.summary,
      report.highlight.utterance,
      report.highlight.reason,
      for (final SkillReport s in report.skills) ...<String>[
        s.feature,
        s.strength,
        s.improvement,
        ...s.evidence,
      ],
    ].join(' ');

    for (final String tag in forbidden) {
      expect(all.contains(tag), isFalse, reason: '내부 태그 "$tag" 노출');
    }
  });

  test('보완할 부분은 권유형 문장이다', () async {
    final ReportDetail report = (await repositoryOf().getReportDetail(104))!;
    for (final SkillReport skill in report.skills) {
      // 단정적 부정("부족합니다", "못합니다")을 쓰지 않기로 했습니다.
      expect(skill.improvement.contains('부족'), isFalse);
      expect(skill.improvement.contains('못합'), isFalse);
    }
  });

  test('없는 세션은 예외가 아니라 null 이다', () async {
    expect(await repositoryOf().getReportDetail(999999), isNull);
  });

  test('설정 토글이 다음 조회에 반영된다', () async {
    final MyPageRepositoryMock repository = repositoryOf();
    final AppSettings before = await repository.getSettings();

    await repository.setReportNotification(enabled: !before.reportNotification);

    final AppSettings after = await repository.getSettings();
    expect(after.reportNotification, !before.reportNotification);
    // 다른 값은 건드리지 않습니다.
    expect(after.marketingConsent, before.marketingConsent);
    expect(after.appVersion, before.appVersion);
  });
}
