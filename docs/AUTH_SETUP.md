# 로그인 연동 설정

이메일 로그인은 로컬 백엔드가 실행 중이면 별도 공급자 키 없이 동작합니다.

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api
```

Android 에뮬레이터의 기본 API 주소는 `http://10.0.2.2:8080/api`입니다.

## 카카오·구글 OAuth

Chrome 개발 환경에서는 카카오 및 구글 개발자 콘솔에
`http://localhost:7357/auth.html`을 콜백 URI로 등록하고, 항상 같은 포트로
실행합니다.

```powershell
flutter run -d chrome --web-port=7357 `
  --dart-define=API_BASE_URL=http://localhost:8080/api `
  --dart-define=KAKAO_CLIENT_ID=<카카오 REST API 키> `
  --dart-define=GOOGLE_CLIENT_ID=<구글 웹 OAuth 클라이언트 ID>
```

Android/iOS 앱에서는 기본 콜백 `goodquestion://oauth`를 사용합니다. 다른 콜백
URI를 사용하면 `OAUTH_REDIRECT_URI`를 넘기고 Android Manifest와 iOS URL
Scheme도 같은 scheme으로 바꿔야 합니다.

백엔드 `.env`에도 같은 공급자 정보를 설정합니다.

```dotenv
KAKAO_CLIENT_ID=
KAKAO_CLIENT_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
```

`GOOGLE_CLIENT_SECRET`은 웹 클라이언트에서 사용하며, 네이티브 클라이언트는
비워 둘 수 있습니다. 공급자 콘솔의 클라이언트 유형과 콜백 URI는 반드시 서로
일치해야 합니다.
