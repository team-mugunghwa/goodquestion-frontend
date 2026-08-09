# API 계약

백엔드는 **Spring Boot + Spring Data JPA** (별도 저장소).
이 문서는 **프론트-백엔드 사이의 약속**입니다. 프론트가 임의로 추측해서 구현하면 안 되고, 백엔드가 말없이 바꿔도 안 됩니다.

> ⚙️ **가장 좋은 방법은 백엔드에 Swagger를 붙이는 것입니다.**
> `springdoc-openapi-starter-webmvc-ui` 의존성 한 줄이면 `/swagger-ui.html`이 뜹니다.
> 그러면 이 문서는 "합의 사항"만 남기고, 상세 스펙은 Swagger가 항상 최신으로 유지합니다. → [DECISIONS.md](DECISIONS.md)

---

## 1. 기본 정보

| 환경 | Base URL |
|---|---|
| local | `http://localhost:8080/api/v1` |
| dev | _(미정)_ |
| prod | _(미정)_ |

> ⚠️ Android 에뮬레이터에서 로컬 서버는 `localhost`가 아니라 **`10.0.2.2`** 입니다.
> iOS 시뮬레이터는 `localhost` 그대로. 실기기는 PC의 LAN IP.
> 이 값들은 `.env`로 주입하고 코드에 하드코딩하지 않습니다.

---

## 2. 공통 규칙 (⚠️ 백엔드와 먼저 합의)

### 응답 봉투

**모든** 응답을 아래 형태로 감쌉니다. 그래야 프론트가 성공/실패 처리를 한 곳에서 할 수 있습니다.

성공:

```json
{
  "success": true,
  "data": { "id": 1, "title": "좋은 질문이란?" },
  "error": null
}
```

실패:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "QUESTION_NOT_FOUND",
    "message": "존재하지 않는 질문입니다."
  }
}
```

### 규칙

| 항목 | 약속 |
|---|---|
| 인코딩 | UTF-8 |
| 날짜/시간 | **ISO 8601 UTC** — `2026-08-08T01:23:45Z` (문자열, 타임존 포함 필수) |
| 필드 네이밍 | `lowerCamelCase` (서버가 snake_case면 DTO에서 매핑) |
| 없는 값 | 필드를 **생략하지 말고** `null`로 내려주기 (프론트 파싱이 안정적) |
| 빈 목록 | `null`이 아니라 `[]` |
| ID | `int` (문자열 아님) |
| 불리언 | `isXxx` / `hasXxx` 형태 |

### HTTP 상태 코드

| 코드 | 의미 |
|---|---|
| 200 | 성공 |
| 201 | 생성 성공 |
| 400 | 잘못된 요청 (유효성 실패) |
| 401 | 인증 안 됨 / 토큰 만료 |
| 403 | 권한 없음 |
| 404 | 리소스 없음 |
| 409 | 충돌 (중복 등) |
| 500 | 서버 오류 |

### 페이지네이션

요청: `?page=1&size=20` (page는 **1부터**)

응답 `data`:

```json
{
  "items": [],
  "page": 1,
  "size": 20,
  "totalElements": 137,
  "totalPages": 7,
  "hasNext": true
}
```

> Spring의 `Page<T>`는 page가 **0부터** 시작합니다. **1-based로 맞출지 0-based로 맞출지 반드시 먼저 정하세요.** 여기서 어긋나면 목록 첫 페이지가 통째로 빠지는 버그가 납니다.

---

## 3. 인증

_(방식 확정 후 작성 — 아래는 JWT를 쓸 경우의 합의 항목)_

| 항목 | 값 |
|---|---|
| 방식 | JWT Bearer _(미정)_ |
| 헤더 | `Authorization: Bearer <accessToken>` |
| Access Token 만료 | _(미정)_ |
| Refresh Token 만료 | _(미정)_ |
| 재발급 엔드포인트 | _(미정)_ |
| 401 받았을 때 | 재발급 시도 → 실패 시 로그아웃 후 로그인 화면 |

토큰 저장은 `flutter_secure_storage`. **`SharedPreferences`에 토큰을 저장하지 않습니다.**

---

## 4. 에러 코드

프론트는 `error.code`(문자열)로 분기하고, **HTTP 상태 코드나 `message` 문자열로 분기하지 않습니다.** 메시지는 언제든 바뀝니다.

| code | HTTP | 의미 | 프론트 처리 |
|---|---|---|---|
| `INVALID_INPUT` | 400 | 유효성 실패 | 필드 에러 표시 |
| `UNAUTHORIZED` | 401 | 토큰 없음/만료 | 재발급 → 실패 시 로그인 |
| `FORBIDDEN` | 403 | 권한 없음 | 안내 후 뒤로 |
| `NOT_FOUND` | 404 | 리소스 없음 | 빈 화면 |
| `INTERNAL_ERROR` | 500 | 서버 오류 | 재시도 버튼 |

_(도메인별 코드는 기능 추가 시 여기에 계속 채웁니다)_

---

## 5. 엔드포인트

> 📌 **API를 추가·변경하는 PR은 이 표도 같이 갱신합니다.** ([CONVENTIONS.md](CONVENTIONS.md#7-문서-갱신-의무))

| Method | Path | 설명 | 상태 |
|---|---|---|---|
| `GET` | `/home` | 홈 화면 데이터 한 묶음 | 🚧 협의 중 |
| `GET` | `/stories` | 이야기 목록 + 주제 필터 | 🚧 협의 중 |
| `GET` | `/stories/{id}` | 이야기 상세 (요약·역할·도입 음성) | 🚧 협의 중 |
| `POST` | `/sessions` | 이야기 시작 → 세션 생성 | 🚧 협의 중 |
| `GET` | `/words` | 담은 단어 (이야기별 그룹) | 🚧 협의 중 |
| `PATCH` | `/words/{id}/like` | 단어 좋아요 토글 | 🚧 협의 중 |
| `GET` | `/mypage` | 마이페이지 요약 (아이·활동·리포트 배지) | 🚧 협의 중 |
| `GET` | `/reports` | 보호자 리포트 목록 | 🚧 협의 중 |
| `GET` | `/reports/{sessionId}` | 리포트 상세 | 🚧 협의 중 |
| `POST` | `/reports/{sessionId}/read` | 리포트 열람 처리 | 🚧 협의 중 |
| `GET` | `/settings` | 알림·계정 설정 | 🚧 협의 중 |
| `PATCH` | `/settings` | 알림 토글 | 🚧 협의 중 |
| `GET` | `/questions` | 질문 목록 (페이지네이션) | 🚧 협의 중 |
| `GET` | `/questions/{id}` | 질문 상세 | 🚧 협의 중 |
| `POST` | `/questions` | 질문 생성 | 🚧 협의 중 |

상태: 🚧 협의 중 · ⏳ 백엔드 구현 중 · ✅ 사용 가능

### `GET /home`

홈은 "이어하기 / 새 이야기 / 내 행성" 세 갈래의 출발점입니다. 섹션마다 따로
호출하면 화면이 세 번 덜컹이므로 **한 번에 묶어서** 받습니다.
현재 선택된 아이는 서버가 세션에서 판단합니다 (쿼리 파라미터 없음).

**Response `data`**

| 필드 | 타입 | null 가능 | 설명 |
|---|---|---|---|
| `child` | object | ✅ | 현재 아이. **아이 프로필 미등록이면 `null`** |
| `child.name` | string | ❌ | 아이 이름 |
| `child.avatar` | string | ✅ | 아바타 이미지 |
| `inProgressSession` | object | ✅ | `status=in_progress` 최신 1건. 없으면 `null` |
| `inProgressSession.sessionId` | int | ❌ | 재개할 세션 |
| `inProgressSession.storyTitle` | string | ❌ | 이야기 제목 |
| `inProgressSession.storyImage` | string | ✅ | 대표 이미지 |
| `inProgressSession.lastCompletedScene` | int | ❌ | 마지막으로 **완료한** 장면 번호 |
| `inProgressSession.totalScenes` | int | ❌ | 전체 장면 수 |
| `recommendedStories[]` | array | ❌ | 고정 큐레이션 2~3개. 없으면 `[]` |
| `recommendedStories[].storyId` | int | ❌ | 이야기 ID |
| `recommendedStories[].title` | string | ❌ | 제목 |
| `recommendedStories[].image` | string | ✅ | 대표 이미지 |
| `recommendedStories[].estimatedMinutes` | int | ❌ | 예상 소요 시간(분) |
| `recommendedStories[].topicTag` | string | ❌ | 주제 태그 한 단어 |
| `planet.stardustBalance` | int | ❌ | 별가루 잔액 |
| `planet.thumbnailImage` | string | ✅ | 내 행성 미니 썸네일 |

> ⚠️ **`lastCompletedScene` 은 "완료한" 장면입니다.** "지금 볼 장면"으로 해석하면
> 재개 위치가 한 칸 밀립니다. 여기서 어긋나면 아이가 같은 장면을 두 번 말합니다.
>
> **개인화 추천은 범위 밖입니다.** `recommendedStories` 는 서버가 고정으로 정한
> 큐레이션이고, 순서도 서버 순서 그대로 씁니다.

이 모양의 더미가 `assets/dummy/home.json` 에 **1:1** 로 있습니다. 스키마를 바꾸면
더미와 이 표를 같이 고치세요. → [DECISIONS.md](DECISIONS.md) 015

### `GET /stories`

목록과 **주제 필터를 함께** 내려줍니다. 주제는 콘텐츠와 함께 늘어나므로 앱에
하드코딩하지 않습니다. MVP 콘텐츠 수가 적어서 필터링은 앱에서 하고, 서버에는
주제별 재조회를 요청하지 않습니다.

| 필드 | 타입 | null 가능 | 설명 |
|---|---|---|---|
| `topics[]` | array | ❌ | 필터 칩. **첫 항목은 항상 `id: "all"`** |
| `topics[].id` | string | ❌ | `all` · `folk` · `animal` · `adventure` · `daily` |
| `topics[].label` | string | ❌ | 칩에 보이는 한글 |
| `topics[].icon` | string | ✅ | 아이콘 키. 앱이 Material 아이콘으로 번역 |
| `stories[]` | array | ❌ | **서버 순서 그대로** 그립니다 (정렬·개인화 없음) |
| `stories[].storyId` | int | ❌ | 이야기 ID |
| `stories[].title` | string | ❌ | 제목 |
| `stories[].image` | string | ✅ | 대표 이미지 |
| `stories[].estimatedMinutes` | int | ❌ | 예상 소요 시간(분) |
| `stories[].topicIds` | array | ❌ | 이 이야기의 주제들 |

> ⚠️ **`topicIds` 에 `topics` 에 없는 id 를 넣지 마세요.** 그 이야기는 어떤 필터로도
> 안 보입니다. 더미에는 이걸 검사하는 테스트가 걸려 있습니다.
>
> 목록에는 난이도·요약을 내려주지 않습니다. 카드에 정보가 늘면 아이가 그림이
> 아니라 글로 고르게 됩니다. (PRD F-03)

### `GET /stories/{id}`

| 필드 | 타입 | null 가능 | 설명 |
|---|---|---|---|
| `storyId` | int | ❌ | 이야기 ID |
| `title` | string | ❌ | 제목 |
| `coverImage` | string | ✅ | 대표 이미지 |
| `estimatedMinutes` | int | ❌ | 예상 소요 시간(분) |
| `difficulty` | string | ❌ | "쉬움" · "보통" — 숫자가 아니라 말 |
| `topics[]` | array | ❌ | 주제 태그 |
| `introText` | string | ❌ | 도입문. **글자는 보조**, 음성이 본체 |
| `situationText` | string | ❌ | 지금 어떤 상황인지 |
| `introAudio` | string | ✅ | 도입문 + 역할 설명 음성 |
| `role.name` | string | ❌ | 아이가 맡을 역할 이름 |
| `role.description` | string | ❌ | 무엇을 하게 되는지 1~2문장 |
| `role.characterImage` | string | ✅ | 역할 캐릭터 일러스트 |

> **없는 이야기는 404 + `NOT_FOUND`** 로 주세요. 앱은 이걸 "찾을 수 없어" 화면으로
> 그리고, 로드 실패(재시도 버튼)와 구분합니다.

### `POST /sessions`

이야기를 시작합니다. **서비스 전체에서 세션이 생성되는 유일한 지점**입니다.
(이어하기는 기존 세션을 재개하므로 여기를 거치지 않습니다.)

**Request** `{ "storyId": 11 }` · **Response `data`** `{ "sessionId": 9011 }`

### `GET /words`

| 필드 | 타입 | null 가능 | 설명 |
|---|---|---|---|
| `child.name` / `child.avatar` | string | ✅ | 헤더 표시용 |
| `totalCount` | int | ❌ | 헤더 배지 숫자 |
| `groups[]` | array | ❌ | **이야기별 그룹.** 최근 담은 이야기가 위 |
| `groups[].storyId` | int | ❌ | 이야기 ID |
| `groups[].storyTitle` | string | ❌ | 이야기 제목 |
| `groups[].storyImage` | string | ✅ | 필터 칩·그룹 헤더 이미지 |
| `groups[].words[].wordId` | int | ❌ | 단어 ID |
| `groups[].words[].word` | string | ❌ | 표제어 |
| `groups[].words[].meaning` | string | ❌ | 쉬운 뜻 (모달 전용) |
| `groups[].words[].sentence` | string | ❌ | 이야기 속 문장 (모달 전용) |
| `groups[].words[].audio` | string | ✅ | 발음 음성 |
| `groups[].words[].liked` | bool | ❌ | 좋아요 여부 |
| `groups[].words[].savedAt` | string | ✅ | ISO 8601 |

> **평면 리스트로 주지 마세요.** 아이의 기억 단서는 "언제 담았나"가 아니라
> "어떤 이야기에서 만났나"입니다. 그룹핑을 앱에서 하면 순서 기준이 서버와
> 어긋납니다. (PRD F-10)

### `PATCH /words/{id}/like`

좋아요 토글. **Response `data`** `{ "liked": true }`

### 보호자 화면 (`/mypage` · `/reports` · `/settings`)

이 묶음은 **보호자 전용**입니다. 아이 화면과 달리 텍스트 중심이고, 응답에
분석 문장이 그대로 들어옵니다.

**`GET /mypage`** — `child {childId, name, age, avatar}`(미등록 시 `null`) ·
`childCount` · `activity {completedStories, stardust}` · `hasNewReport`

**`GET /reports`** — `childName` · `totalCount` · `newCount` ·
`reports[] {sessionId, storyTitle, storyImage, completedAt, isNew, playCount, highlightUtterance}`

**`GET /reports/{sessionId}`** — 세션 메타 + `summary`(한 줄 총평) +
`skills[]`(어휘·표현·논리) + `highlight {utterance, reason}` +
`questionGroups[] {title, questions[]}`

`skills[]` 각 항목: `name` · `feature` · `evidence[]` · `strength` ·
`improvement` · `askedWords[]`(어휘 영역 전용)

**`GET /settings`** · **`PATCH /settings`** — `reportNotification` ·
`marketingConsent` · `consentAt` · `accountType` · `accountLabel`(마스킹) ·
`hasNewNotice` · `appVersion`

> ⚠️ **리포트 텍스트에 내부 태그(DECISION·REASON 등)를 넣지 마세요.** 그대로
> 보호자에게 보입니다. `improvement` 는 **권유형 문장만** ("~해보면 좋아요") —
> 단정적 부정 표현은 금지입니다. (PRD F-09)
>
> 리포트 응답에 **음성 파일 경로를 넣지 않습니다.** 음성 원본을 저장하지 않는
> 게 정책이고, 경로가 오면 화면에 재생 버튼을 만들고 싶어집니다.
>
> 아직 분석이 안 끝난 세션은 **404** 로 주세요. 앱은 이걸 "만들고 있어요"로
> 그리고, 로드 실패(재시도)와 구분합니다.

### `GET /questions`

**Query**

| 이름 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|
| `page` | int | ❌ | 1 | 페이지 번호 |
| `size` | int | ❌ | 20 | 페이지 크기 |

**Response `data.items[]`**

| 필드 | 타입 | null 가능 | 설명 |
|---|---|---|---|
| `id` | int | ❌ | 질문 ID |
| `title` | string | ❌ | 제목 |
| `content` | string | ❌ | 본문 |
| `authorName` | string | ❌ | 작성자 표시명 |
| `createdAt` | string | ❌ | ISO 8601 |

> 위 스키마는 **임시 예시**입니다. 백엔드와 확정한 뒤 이 문서를 갱신하고,
> `lib/features/question/data/dtos/question_dto.dart` 를 맞춰 수정하세요.

---

## 6. 서버 없이 개발하기

백엔드가 준비되기 전에는 **Mock Repository**로 화면을 먼저 만듭니다.
`RepositoryImpl` 대신 `RepositoryMock`을 DI에 등록하면 화면 코드는 한 줄도 안 바꿔도 됩니다.
자세한 건 [ARCHITECTURE.md](ARCHITECTURE.md#8-새-기능-추가-레시피) 참고.
