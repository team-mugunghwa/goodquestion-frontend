# 로그인 연동 설정

이 문서는 로컬 환경에서 GoodQuestion 프론트엔드와 백엔드를 연결하고 이메일·카카오 로그인을 테스트하는 방법을 설명합니다.

## 현재 구현 범위

- 이메일 회원가입 및 로그인은 백엔드의 `/api/auth/signup`, `/api/auth/login`과 연결되어 있습니다.
- 카카오 로그인은 프론트엔드에서 인가 코드를 받은 뒤 `/api/auth/social/kakao`로 전달합니다.
- 백엔드는 인가 코드를 카카오 액세스 토큰으로 교환하고 사용자 정보를 조회한 뒤 GoodQuestion JWT를 발급합니다.
- 발급된 JWT는 이후 `/api/children` 등 인증이 필요한 API 요청에 `Bearer` 토큰으로 첨부됩니다.
- 아이 프로필이 없는 계정은 아이 프로필 등록 화면으로 이동합니다.
- 아이 프로필이 있는 계정은 현재 선택된 아이 이름으로 `하늘이, 환영해요!`와 같은 문구를 잠깐 표시한 뒤 홈으로 이동합니다.
- 로그인 유지가 꺼져 있으면 토큰은 현재 실행 세션에서만 유지됩니다.

카카오 로그인은 프론트엔드만 실행해서는 완료되지 않습니다. 프론트엔드와 백엔드, PostgreSQL이 모두 실행 중이어야 합니다.

## 1. 카카오 개발자 콘솔 설정

현재 구현은 카카오 REST API 방식입니다. JavaScript 키나 네이티브 앱 키가 아니라 **REST API 키**를 사용합니다.

웹 개발용 Redirect URI를 다음 값과 정확히 일치하도록 등록합니다.

```text
http://localhost:7357/auth.html
```

다음 값들은 서로 다른 Redirect URI로 처리됩니다.

```text
http://localhost:7357/auth.html
http://127.0.0.1:7357/auth.html
http://localhost:7357/auth.html/
```

Client Secret을 카카오 콘솔에서 사용하도록 설정했다면 별도로 발급된 Client Secret을 사용합니다. JavaScript 키, 네이티브 앱 키, REST API 키를 Client Secret 자리에 넣으면 안 됩니다. Client Secret 기능을 사용하지 않는다면 백엔드 값을 비워 둡니다.

## 2. 백엔드 환경변수

백엔드 폴더의 `.env`를 설정합니다.

```text
C:\MVP GoodQuestion 2\goodquestion-backend\.env
```

예시:

```dotenv
DB_URL=jdbc:postgresql://localhost:5432/goodquestion
DB_USERNAME=<PostgreSQL 사용자>
DB_PASSWORD=<PostgreSQL 비밀번호>

JWT_SECRET=<충분히 긴 임의의 비밀 값>
JWT_EXPIRATION_MS=604800000

KAKAO_CLIENT_ID=<카카오 REST API 키>
KAKAO_CLIENT_SECRET=
```

Client Secret 기능을 켠 경우에만 다음처럼 입력합니다.

```dotenv
KAKAO_CLIENT_SECRET=<카카오에서 별도로 발급한 Client Secret>
```

`.env`는 Git에 커밋하지 않습니다.

## 3. 백엔드 실행

PostgreSQL을 Docker Compose로 실행합니다.

```powershell
cd "C:\MVP GoodQuestion 2\goodquestion-backend"
docker compose up -d
```

백엔드를 실행합니다.

```powershell
cd "C:\MVP GoodQuestion 2\goodquestion-backend"
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
.\gradlew.bat bootRun
```

다음과 비슷한 로그가 나오면 정상입니다.

```text
Tomcat started on port 8080
Started GoodquestionBackendApplication
```

브라우저에서 상태를 확인합니다.

```text
http://127.0.0.1:8080/actuator/health
```

정상 응답:

```json
{"status":"UP"}
```

### 8080 포트 충돌

다음 오류는 이전 백엔드가 아직 실행 중이라는 뜻입니다.

```text
Web server failed to start. Port 8080 was already in use.
```

사용 중인 프로세스를 확인합니다.

```powershell
netstat -ano | Select-String ':8080\s+.*LISTENING'
```

출력 마지막에 표시된 PID가 실제로 이전 백엔드인지 확인한 뒤 종료합니다.

```powershell
Get-Process -Id <PID>
Stop-Process -Id <PID>
```

그다음 백엔드를 한 번만 다시 실행합니다. `.env`를 수정한 경우에도 기존 프로세스를 완전히 종료하고 재실행해야 변경 내용이 반영됩니다.

## 4. 프론트엔드 실제 로그인 설정

프론트엔드 루트에 개인용 `env.json`을 만듭니다.

```text
C:\MVP GoodQuestion 2\goodquestion-frontend\env.json
```

```json
{
  "API_BASE_URL": "http://127.0.0.1:8080/api",
  "KAKAO_CLIENT_ID": "<카카오 REST API 키>",
  "MOCK_SOCIAL_LOGIN": false
}
```

프론트엔드와 백엔드의 `KAKAO_CLIENT_ID`는 동일한 REST API 키여야 합니다. `env.json`은 `.gitignore`에 포함되어 있으므로 커밋하지 않습니다.

`env/local_web.json`은 UI 확인용 목 로그인 설정인 `MOCK_SOCIAL_LOGIN=true`를 사용합니다. 실제 카카오 로그인 테스트에는 사용하지 않습니다.

Chrome을 고정 포트로 실행합니다.

```powershell
cd "C:\MVP GoodQuestion 2\goodquestion-frontend"
flutter run -d chrome --web-port=7357 --dart-define-from-file=env.json
```

`dart-define` 값은 빌드 시 적용됩니다. `env.json`을 변경했다면 Hot Reload만 하지 말고 프론트엔드를 완전히 종료한 뒤 다시 실행합니다.

## 5. 로그인 처리 흐름

카카오 로그인은 다음 순서로 동작합니다.

1. 프론트엔드가 카카오 인증 화면을 엽니다.
2. 사용자가 카카오에서 로그인을 승인합니다.
3. 카카오가 `http://localhost:7357/auth.html`로 인가 코드를 전달합니다.
4. `auth.html`이 인가 코드를 Flutter 앱으로 돌려줍니다.
5. 프론트엔드가 인가 코드와 Redirect URI를 백엔드 `/api/auth/social/kakao`로 전송합니다.
6. 백엔드가 카카오 토큰과 사용자 정보를 조회합니다.
7. 백엔드가 GoodQuestion JWT를 발급하고 프론트엔드가 저장합니다.
8. 등록된 아이 프로필을 조회해 신규 동의·아이 등록 또는 홈 화면으로 이동합니다.

카카오 앱에서 승인을 마쳤는데 로그인 화면에 그대로 남아 있다면 5~7단계의 실패일 가능성이 큽니다.

## 6. 자주 발생하는 오류

### `Did not find the file passed to --dart-define-from-file`

현재 터미널 위치에 `env.json`이 없거나 파일명이 `env.json.txt`인 경우입니다.

```powershell
Test-Path "C:\MVP GoodQuestion 2\goodquestion-frontend\env.json"
```

`True`가 나오는지 확인하고 프론트엔드 폴더에서 실행합니다.

### `소셜 로그인 키가 설정되어 있지 않습니다`

프론트엔드 실행 설정에 `KAKAO_CLIENT_ID`가 없거나 변경 후 완전히 재실행하지 않은 경우입니다. `env.json`과 실행 명령을 확인합니다.

### `로그인이 필요합니다`

프론트엔드가 백엔드의 HTTP 401을 받은 경우입니다. 다음을 확인합니다.

- 프론트엔드와 백엔드가 같은 REST API 키를 사용하는지
- JavaScript 키나 네이티브 앱 키를 사용하지 않았는지
- Client Secret 사용 여부와 `.env` 값이 일치하는지
- Redirect URI가 정확히 `http://localhost:7357/auth.html`인지
- `.env` 변경 후 이전 백엔드를 종료하고 다시 실행했는지
- 8080 포트에서 예전 백엔드 프로세스가 실행 중이지 않은지

### `네트워크에 연결할 수 없습니다`

백엔드 상태와 API 주소를 확인합니다.

```text
http://127.0.0.1:8080/actuator/health
```

Chrome에서는 프론트엔드가 `http://localhost:7357`, 백엔드가 `http://127.0.0.1:8080`에서 실행됩니다. 백엔드의 CORS 허용 주소에는 두 로컬 프론트엔드 주소가 설정되어 있습니다.

### 카카오 승인 후에도 다시 로그인 화면이 표시됨

백엔드 실행 터미널에서 `APPLICATION FAILED TO START` 또는 `Port 8080 was already in use`가 있는지 먼저 확인합니다. `BUILD SUCCESSFUL` 문구가 있더라도 애플리케이션 시작 실패 로그가 함께 있으면 서버가 정상 실행된 것이 아닙니다.

## 7. 모바일 실행 참고

Android 에뮬레이터에서 호스트 PC의 백엔드에 접근할 때는 다음 주소를 사용합니다.

```text
http://10.0.2.2:8080/api
```

Android/iOS의 기본 OAuth 콜백은 `goodquestion://oauth`입니다. 모바일에서 실제 소셜 로그인을 연결할 때는 Android Manifest와 iOS URL Scheme도 같은 콜백 scheme으로 설정해야 합니다.
