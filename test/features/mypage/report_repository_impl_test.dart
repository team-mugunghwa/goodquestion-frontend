import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/exceptions.dart';
import 'package:goodquestion/core/network/dio_client.dart';
import 'package:goodquestion/features/mypage/data/datasources/report_remote_data_source.dart';
import 'package:goodquestion/features/mypage/data/dtos/report_response_dto.dart';
import 'package:goodquestion/features/mypage/data/repositories/report_repository_impl.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_detail.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';

class _Remote extends ReportRemoteDataSource {
  _Remote({
    this.reports = const <ReportListResponseDto>[],
    this.detail,
    this.error,
  }) : super(DioClient());

  final List<ReportListResponseDto> reports;
  final ReportDetailResponseDto? detail;
  final Object? error;

  @override
  Future<List<ReportListResponseDto>> fetchReports(String childId) async =>
      reports;

  @override
  Future<ReportDetailResponseDto> fetchReport(String sessionId) async {
    if (error != null) throw error!;
    return detail!;
  }
}

class _Children implements ChildProfileRepository {
  @override
  String? selectedChildId = 'child-uuid';

  @override
  Future<void> createChild({required String name, required int age}) async {}

  @override
  Future<List<MyPageChild>> getChildren() async => const <MyPageChild>[
    MyPageChild(childId: 'child-uuid', name: '지우', age: 8),
  ];

  @override
  Future<void> selectChild(String childId) async {
    selectedChildId = childId;
  }
}

void main() {
  test('UUID 목록 응답을 선택된 아이의 리포트 카드로 구성한다', () async {
    final ReportRepositoryImpl repository = ReportRepositoryImpl(
      _Remote(
        reports: <ReportListResponseDto>[
          ReportListResponseDto(
            sessionId: 'session-new',
            storyTitle: '방귀 뀌는 며느리',
            createdAt: DateTime(2026, 8, 15),
          ),
          ReportListResponseDto(
            sessionId: 'session-old',
            storyTitle: '방귀 뀌는 며느리',
            createdAt: DateTime(2026, 8, 10),
          ),
        ],
      ),
      _Children(),
    );

    final ReportList list = await repository.getReportList();

    expect(list.childName, '지우');
    expect(list.reports.first.sessionId, 'session-new');
    expect(list.reports.first.playCount, 2);
    expect(list.reports.last.playCount, 1);
  });

  test('상세 응답은 내부 태그를 숨긴 어휘·역량 카드가 된다', () async {
    final ReportRepositoryImpl repository = ReportRepositoryImpl(
      _Remote(
        detail: ReportDetailResponseDto(
          sessionId: 'session-uuid',
          storyTitle: '방귀 뀌는 며느리',
          summary: '상대의 마음을 헤아리고 자기 생각을 잘 말했어요.',
          vocabulary: const VocabularyResponseDto(
            mainWords: <String>['며느리', '참다'],
            askedWords: <String>['며느리'],
            repeatedExpressions: <String>[],
            feedback: '이야기에 나온 낱말을 스스로 물어보고 자기 문장에 담아 봤어요.',
          ),
          competencies: const <CompetencyResponseDto>[
            CompetencyResponseDto(
              name: '관점과 공감',
              finding: '다른 사람의 마음을 먼저 생각했어요.',
              evidenceUtterance: '가족이니까 이해해 줄 거예요.',
              strength: '인물의 마음을 헤아려 말했어요.',
              nextFocus: '다음에는 이유를 덧붙이면 더 잘 전해져요.',
            ),
          ],
          representativeUtterance: const RepresentativeUtteranceResponseDto(
            text: '가족이니까 이해해 줄 거예요.',
            reason: '인물의 마음을 헤아리고 자기 말로 풀어서 표현했어요.',
          ),
          homeGuide: const HomeGuideResponseDto(
            storyQuestions: <String>['며느리가 계속 참았으면 어떻게 됐을까?'],
            dailyLifeQuestions: <String>['너도 참았던 것 때문에 힘들었던 적 있어?'],
          ),
          createdAt: DateTime(2026, 8, 15),
        ),
      ),
      _Children(),
    );

    final ReportDetail report = (await repository.getReportDetail(
      'session-uuid',
    ))!;

    expect(report.skills.map((SkillReport skill) => skill.name), <String>[
      '어휘',
      '관점과 공감',
    ]);
    expect(report.highlight.utterance, '가족이니까 이해해 줄 거예요.');
    expect(report.questionGroups, hasLength(2));
    expect(report.questionGroups.first.questions, hasLength(1));
    final String visibleText = <String>[
      report.summary,
      report.highlight.reason,
      for (final SkillReport skill in report.skills) ...<String>[
        skill.feature,
        skill.strength,
        skill.improvement,
      ],
    ].join(' ');
    expect(visibleText, isNot(contains('PERSPECTIVE')));
    expect(visibleText, isNot(contains('REASON')));
  });

  test('아직 생성되지 않은 리포트의 409는 pending 상태인 null로 바꾼다', () async {
    final ReportRepositoryImpl repository = ReportRepositoryImpl(
      _Remote(
        error: const ServerException(
          message: '리포트를 준비 중입니다.',
          code: 'REPORT_NOT_READY',
          statusCode: 409,
        ),
      ),
      _Children(),
    );

    expect(await repository.getReportDetail('pending-session'), isNull);
  });
}
