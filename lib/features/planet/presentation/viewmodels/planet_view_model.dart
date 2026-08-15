import '../../../../core/presentation/base_view_model.dart';
import '../../../auth/data/datasources/auth_token_store.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';

/// 행성 웹앱에 넘길 신원(부모 토큰 + childId)을 준비합니다.
///
/// 행성은 본체와 별도로 렌더되는 웹앱입니다(→ `web/planet_app/`). 서버 API가
/// 전부 `/api/children/{childId}/...` 인데 토큰은 **부모 것**이라, 둘 다
/// 넘기지 않으면 행성은 서버를 한 줄도 부를 수 없습니다.
/// → 팀원공유 `행성_연동규약.md` §1
class PlanetViewModel extends BaseViewModel {
  PlanetViewModel(this._tokenStore, this._childProfileRepository);

  final AuthTokenStore _tokenStore;
  final ChildProfileRepository _childProfileRepository;

  String? _token;
  String? _childId;

  String? get token => _token;
  String? get childId => _childId;

  /// 로그인은 라우터 가드가 보장하므로, 여기서 걸러 낼 것은 아이 프로필이
  /// 아직 없는 계정뿐입니다.
  bool get hasChild => _childId != null;

  /// 홈과 같은 규칙입니다: 이미 고른 아이가 있으면 그 아이, 없으면 첫 번째
  /// 아이를 고르고 선택을 기록합니다. (HomeRepositoryImpl 참고)
  Future<void> load() => guard(() async {
    _token = await _tokenStore.read();
    String? childId = _childProfileRepository.selectedChildId;
    if (childId == null) {
      final children = await _childProfileRepository.getChildren();
      if (children.isNotEmpty) {
        childId = children.first.childId;
        await _childProfileRepository.selectChild(childId);
      }
    }
    _childId = childId;
  });
}
