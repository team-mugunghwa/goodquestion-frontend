# 로컬 로그인 테스트

백엔드와 PostgreSQL을 실행한 뒤 아래 명령으로 Chrome을 시작합니다.

```powershell
flutter run -d chrome --web-port=7357 `
  --dart-define=API_BASE_URL=http://localhost:8080/api `
  --dart-define=MOCK_SOCIAL_LOGIN=true
```

- 이메일 로그인은 실제 로컬 백엔드와 통신합니다.
- 데모 계정은 `demo@goodquestion.kr` / `demo1234!`입니다.
- Google/Kakao 버튼은 공급자 키가 준비되기 전 화면 이동만 모의 테스트합니다.
- `MOCK_SOCIAL_LOGIN=true`는 실제 OAuth나 토큰 발급을 하지 않으므로 배포에 사용하지 않습니다.
- 실제 소셜 로그인을 시험할 때는 이 옵션을 제거하고 `AUTH_SETUP.md`의 공급자 키를 설정합니다.

## 실행 환경별 API 주소

Chrome:

```powershell
flutter run -d chrome --web-port=7357 --dart-define-from-file=env/local_web.json
```

Android 에뮬레이터:

```powershell
flutter run -d <emulator-device-id> --dart-define-from-file=env/local_android_emulator.json
```

실제 Android 휴대폰은 `10.0.2.2`를 사용할 수 없습니다. 휴대폰과 PC를 같은
Wi-Fi에 연결하고 PC의 IPv4 주소를 사용합니다. 현재 PC 주소가 `192.168.0.10`이라면:

```powershell
flutter run -d <device-id> `
  --dart-define=API_BASE_URL=http://192.168.0.10:8080/api `
  --dart-define=MOCK_SOCIAL_LOGIN=true
```

Android 로컬 디버그 빌드는 `http` 통신을 허용하지만, 운영 빌드는 반드시 HTTPS API를
사용해야 합니다.
