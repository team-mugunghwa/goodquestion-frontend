# 푸시 알림(FCM) 설정

고객센터 답변이 등록되면 관리자 콘솔 서버가 FCM 으로 푸시를 보냅니다. 이 문서는
**앱 쪽에서 그 푸시를 받으려면 무엇을 채워야 하는지**만 다룹니다.

## 설정하지 않으면 어떻게 되나

**앱은 그대로 뜹니다.** 설정값이 비어 있으면 Firebase 초기화 자체를 건너뛰고
`NoopPushService` 가 등록됩니다. → [`lib/core/push/push_service.dart`](../lib/core/push/push_service.dart)

푸시만 나가지 않고 **알림은 서버에 쌓이므로 설정 > 알림함에서 답변을 확인할 수
있습니다.** 푸시는 알리는 수단이지 전달 경로가 아닙니다. 로컬과 CI 에 Firebase
키를 두지 않는 이유가 이것입니다.

## 왜 FCM 인가

| 후보 | 판단 |
| --- | --- |
| **FCM** | 발송량 무료, Flutter 공식 플러그인이 iOS/안드로이드/웹을 모두 덮음. **채택** |
| OneSignal | 콘솔은 편하지만 무료 구간에 사용자 수 제한이 있고, 안드로이드 전달은 결국 FCM 을 거쳐 의존 대상만 하나 늘어남 |
| Expo Push | Expo 로 만든 React Native 앱 전용. Flutter 에서 쓸 수 없음 |

## 채워야 하는 값

`env/*.json` 에 넣고 `--dart-define-from-file` 로 넘깁니다.

```json
{
  "API_BASE_URL": "...",
  "FIREBASE_API_KEY": "AIza...",
  "FIREBASE_APP_ID": "1:1234567890:web:abcdef",
  "FIREBASE_PROJECT_ID": "goodquestion",
  "FIREBASE_MESSAGING_SENDER_ID": "1234567890",
  "FIREBASE_VAPID_KEY": "B..."
}
```

넷(`API_KEY`, `APP_ID`, `PROJECT_ID`, `SENDER_ID`) 중 하나라도 비면 푸시를 켜지
않습니다. 반쯤 채워진 설정으로 초기화하면 실패 지점이 앱 기동 한복판이 됩니다.

| 값 | 어디서 |
| --- | --- |
| `FIREBASE_*` 넷 | Firebase 콘솔 > 프로젝트 설정 > 내 앱 > SDK 설정 |
| `FIREBASE_VAPID_KEY` | Firebase 콘솔 > 클라우드 메시징 > 웹 푸시 인증서. **웹에서만 필요합니다** |

### 웹 추가 작업

앱이 백그라운드일 때 알림을 받으려면 서비스 워커가 필요합니다.
`web/firebase-messaging-sw.js` 를 만들고 위와 같은 값을 넣습니다
(Firebase 문서의 예제 그대로입니다). 없어도 앱이 떠 있는 동안의 알림은 동작합니다.

### 안드로이드 / iOS 추가 작업

`google-services.json`(안드로이드), `GoogleService-Info.plist`(iOS)를 각 플랫폼
폴더에 넣고 iOS 는 APNs 인증 키를 Firebase 콘솔에 등록합니다. 이 파일들은
**저장소에 커밋하지 않습니다** — `.gitignore` 에 이미 들어 있습니다.

## 서버 쪽

발송은 관리자 콘솔 서버가 합니다. `FCM_CREDENTIALS`(서비스 계정 JSON)를 그쪽
환경변수에 넣으면 됩니다. 자세한 내용은 admin-goodquestion-backend 의
`docs/admin-backend-guide.md` 를 보세요.

## 동작 확인

1. 앱에 로그인합니다. 로그인 직후 기기 토큰이 서버에 등록됩니다
   (`POST /api/notifications/devices`).
2. 앱에서 문의를 하나 등록합니다.
3. 관리자 콘솔 > 고객센터에서 그 문의에 답변을 등록합니다.
4. 기기에 푸시가 오고, 누르면 문의 상세(`/support/{inquiryId}`)가 열립니다.
5. 푸시가 오지 않아도 설정 > 알림함에 같은 알림이 있어야 합니다. 없다면 푸시가
   아니라 **알림 생성** 쪽 문제입니다 — 서버 로그를 봅니다.

## 알아 둘 것

- **토큰은 바뀝니다.** 앱 재설치, 데이터 삭제, 장기 미사용으로 갱신됩니다.
  `PushRegistrar` 가 `onTokenRefresh` 를 구독해 다시 등록합니다. 이걸 놓치면
  그 뒤로 푸시가 가지 않는데 서버는 성공으로 알고 있습니다.
- **로그아웃할 때 토큰을 해제합니다.** 하지 않으면 기기를 물려받거나 다른
  계정으로 로그인한 사람에게 앞사람의 알림이 갑니다.
- 알림 권한을 거부하면 토큰을 등록하지 않습니다. 서버에 죽은 토큰을 남기지
  않는 편이 깨끗합니다.
