/// 아이별 개인정보 동의 기록에 실어 보내는 값.
///
/// **두 경로가 같은 값을 보내야 합니다** - 가입 흐름(`auth_remote_data_source`)과
/// 마이페이지 아이 추가(`child_profile_remote_data_source`)가 각각 이 상수를
/// 씁니다. 버전을 올릴 때 한쪽만 고치면 그 경로로 만든 아이만 옛 버전으로
/// 남고, 재동의 대상을 고를 때 조용히 어긋납니다.
library;

/// 지금 받고 있는 동의 문서의 버전.
const String childConsentVersion = 'v1';

/// 어떻게 확인한 동의인가. 앱은 이미 로그인한 보호자만 이 화면에 들어옵니다.
const String childConsentVerification = 'AUTHENTICATED_PARENT';
