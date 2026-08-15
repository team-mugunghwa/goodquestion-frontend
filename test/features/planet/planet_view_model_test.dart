import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/auth/data/datasources/auth_token_store.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';
import 'package:goodquestion/features/planet/presentation/viewmodels/planet_view_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

class _MockChildProfileRepository extends Mock
    implements ChildProfileRepository {}

void main() {
  late _MockAuthTokenStore tokenStore;
  late _MockChildProfileRepository childRepository;
  late PlanetViewModel viewModel;

  const MyPageChild firstChild = MyPageChild(
    childId: 'child-1',
    name: '첫째',
    age: 8,
  );
  const MyPageChild secondChild = MyPageChild(
    childId: 'child-2',
    name: '둘째',
    age: 6,
  );

  setUp(() {
    tokenStore = _MockAuthTokenStore();
    childRepository = _MockChildProfileRepository();
    viewModel = PlanetViewModel(tokenStore, childRepository);

    when(() => tokenStore.read()).thenAnswer((_) async => 'token-abc');
    when(() => childRepository.selectChild(any())).thenAnswer((_) async {});
  });

  test('이미 고른 아이가 있으면 그 아이의 행성을 엽니다', () async {
    when(() => childRepository.selectedChildId).thenReturn('child-2');

    await viewModel.load();

    expect(viewModel.state, ViewState.success);
    expect(viewModel.token, 'token-abc');
    expect(viewModel.childId, 'child-2');
    // 이미 골라져 있으면 목록 조회 왕복을 하지 않습니다.
    verifyNever(() => childRepository.getChildren());
  });

  test('고른 아이가 없으면 첫 번째 아이를 골라 기록합니다', () async {
    when(() => childRepository.selectedChildId).thenReturn(null);
    when(
      () => childRepository.getChildren(),
    ).thenAnswer((_) async => const <MyPageChild>[firstChild, secondChild]);

    await viewModel.load();

    expect(viewModel.childId, 'child-1');
    verify(() => childRepository.selectChild('child-1')).called(1);
  });

  test('아이 프로필이 없으면 hasChild 가 거짓입니다 — 안내 화면으로 갑니다', () async {
    when(() => childRepository.selectedChildId).thenReturn(null);
    when(
      () => childRepository.getChildren(),
    ).thenAnswer((_) async => const <MyPageChild>[]);

    await viewModel.load();

    expect(viewModel.state, ViewState.success);
    expect(viewModel.hasChild, isFalse);
  });

  test('아이 목록 조회가 실패하면 에러 상태가 됩니다', () async {
    when(() => childRepository.selectedChildId).thenReturn(null);
    when(() => childRepository.getChildren()).thenThrow(Exception('network'));

    await viewModel.load();

    expect(viewModel.state, ViewState.error);
  });
}
