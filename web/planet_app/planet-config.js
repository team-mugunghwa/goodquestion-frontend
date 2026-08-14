/*
 * 행성 앱 배포 설정 — **이 파일 하나만 고치면 된다. 재빌드가 필요 없다.**
 *
 * `web/planet_app/` 은 행성 웹앱(별도 저장소 Vite 빌드)의 산출물이고,
 * 이 파일만 본체(플러터) 저장소에서 관리한다. 나머지 파일은 손대지 말 것 —
 * 새 빌드를 받으면 이 파일을 남기고 통째로 갈아끼운다.
 *
 * apiBaseUrl 규칙 (행성_연동규약.md):
 *   - 끝에 슬래시를 붙이지 않는다. 코드가 `${apiBaseUrl}/api/...`를 만든다.
 *   - 빈 문자열은 "서버 없음"(독립 모드)이라는 뜻이다.
 */
window.__PLANET__ = (function () {
  // 본체(플러터 웹)가 iframe 주소에 ?api=<백엔드 origin>을 실어 준다.
  // 그래야 본체가 --dart-define=API_BASE_URL 로 어느 백엔드를 보든 행성도
  // 같은 백엔드를 본다. 행성만 따로 열었을 때는 배포 백엔드(Railway)로 붙는다.
  var api = null;
  try {
    api = new URL(window.location.href).searchParams.get('api');
  } catch (e) {
    /* URL 파싱이 안 되는 환경이면 기본값을 쓴다 */
  }
  return {
    apiBaseUrl: api || 'https://goodquestion-backend-production.up.railway.app',

    /*
     * 시연용 무한 별가루. true면 **서버에 붙지 않는다.**
     * 실제 연동을 보여줘야 하면 false로 두고 데모 계정 지갑을 채운다.
     */
    demoUnlimited: false,
  };
})();
