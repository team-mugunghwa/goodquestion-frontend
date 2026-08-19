import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/network/dio_client.dart';
import 'package:goodquestion/features/mypage/data/datasources/my_page_local_data_source.dart';
import 'package:goodquestion/features/mypage/data/datasources/settings_remote_data_source.dart';
import 'package:goodquestion/features/mypage/data/repositories/settings_repository_impl.dart';
import 'package:goodquestion/features/mypage/domain/entities/app_settings.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';

class _Remote extends SettingsRemoteDataSource {
  _Remote({required this.parent, required this.consent}) : super(DioClient());

  final Map<String, dynamic> parent;
  final Map<String, dynamic> consent;

  @override
  Future<Map<String, dynamic>> getParent() async => parent;

  @override
  Future<Map<String, dynamic>> getChildConsent(String childId) async => consent;
}

class _Children implements ChildProfileRepository {
  @override
  Future<void> updateChild({
    required String childId,
    required String name,
    required int age,
  }) async {}
  @override
  String? selectedChildId = 'child-1';

  @override
  Future<void> createChild({required String name, required int age}) async {}

  @override
  Future<List<MyPageChild>> getChildren() async => const <MyPageChild>[
    MyPageChild(childId: 'child-1', name: '하늘이', age: 7),
  ];

  @override
  Future<void> selectChild(String childId) async {
    selectedChildId = childId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('보호자 계정과 현재 아이 동의 상태를 서버 응답에서 구성한다', () async {
    final SettingsRepositoryImpl repository = SettingsRepositoryImpl(
      const MyPageLocalDataSource(),
      _Remote(
        parent: <String, dynamic>{
          'id': 'parent-1',
          'email': 'guardian@example.com',
          'name': '보호자',
          'provider': 'GOOGLE',
        },
        consent: <String, dynamic>{
          'current': <String, dynamic>{
            'id': 'consent-1',
            'consentedAt': '2026-08-11T03:00:00Z',
          },
          'history': <dynamic>[],
        },
      ),
      _Children(),
    );

    final AppSettings settings = await repository.getSettings();

    expect(settings.accountType, 'google');
    expect(settings.accountLabel, 'gu***@example.com');
    expect(settings.consentAt, DateTime.parse('2026-08-11T03:00:00Z'));
  });

  test('서버 API가 없는 알림 설정은 현재 앱 세션에서 유지한다', () async {
    final SettingsRepositoryImpl repository = SettingsRepositoryImpl(
      const MyPageLocalDataSource(),
      _Remote(
        parent: <String, dynamic>{
          'email': 'parent@example.com',
          'name': '보호자',
          'provider': null,
        },
        consent: <String, dynamic>{'current': null, 'history': <dynamic>[]},
      ),
      _Children(),
    );

    await repository.getSettings();
    final AppSettings changed = await repository.setReportNotification(
      enabled: false,
    );

    expect(changed.accountType, 'email');
    expect(changed.reportNotification, isFalse);
    expect(changed.consentAt, isNull);
  });
}
