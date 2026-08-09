import '../entities/home_summary.dart';
import '../repositories/home_repository.dart';

/// 홈 진입·아이 전환·재시도 시 홈 데이터를 가져옵니다.
///
/// 지금은 Repository 를 그대로 통과시킵니다. 그래도 자리를 만들어 두는 이유는
/// 곧 여기에 **아이 전환 시 캐시 무효화**와 **프로필 미등록 판단**이 들어오기
/// 때문입니다. → `docs/ARCHITECTURE.md` 4장
class GetHomeSummaryUseCase {
  const GetHomeSummaryUseCase(this._repository);

  final HomeRepository _repository;

  Future<HomeSummary> call() => _repository.getHomeSummary();
}
