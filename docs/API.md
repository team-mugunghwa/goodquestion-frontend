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
| `GET` | `/children/{childId}/words` | 담은 단어 (평면 목록) | ✅ 연동됨 |
| `PATCH` | `/children/{childId}/words/{wordId}/favorite` | 모르는 말 ↔ 좋아하는 말 | ✅ 연동됨 |
| `GET` | `/mypage` | 마이페이지 요약 (아이·활동·리포트 배지) | 🚧 협의 중 |
| `GET` | `/reports` | 보호자 리포트 목록 | 🚧 협의 중 |
| `GET` | `/reports/{sessionId}` | 리포트 상세 | 🚧 협의 중 |
| `POST` | `/reports/{sessionId}/read` | 리포트 열람 처리 | 🚧 협의 중 |
| `GET` | `/settings` | 알림·계정 설정 | 🚧 협의 중 |
| `PATCH` | `/settings` | 알림 토글 | 🚧 협의 중 |
| `GET` | `/auth/options` | 로그인 수단 · 동의 항목 · 나이 선택지 | 🚧 협의 중 |
| `POST` | `/auth/consents` | 동의 확정 (항목 + 시각) | 🚧 협의 중 |
| `POST` | `/children` | 최초 아이 프로필 생성 | 🚧 협의 중 |
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

### `GET /children/{childId}/words`

**평면 배열**을 최신순(`createdAt` 내림차순)으로 받습니다. 감싸는 객체가 없습니다.

| 필드 | 타입 | null 가능 | 설명 |
|---|---|---|---|
| `id` | string(UUID) | ❌ | 단어 ID |
| `word` | string | ❌ | 표제어 |
| `meaning` | string | ✅ | 쉬운 뜻. **없을 수 있습니다** — 서버가 LLM 으로 만들지만 실패하거나 아직 안 만든 단어가 있습니다 |
| `exampleSentence` | string | ✅ | 이야기 속 문장 |
| `entryType` | string | ❌ | `UNKNOWN`(모르는 말) / `FAVORITE`(좋아하는 말) |
| `sourceSceneId` | string(UUID) | ✅ | 단어가 나온 장면 |
| `storyId` `storyTitle` `storyImageUrl` | string | ✅ | 이야기 정보. 장면 없이 저장된 단어는 셋 다 `null` |
| `createdAt` | string | ❌ | ISO 8601 |

**이야기별 묶음은 앱이 만듭니다.** 서버 응답을 그룹 구조로 바꾸면 저장·즐겨찾기
응답까지 같이 흔들려서, 서버는 평면을 유지하고 `WordRepositoryImpl` 이 묶습니다.

이야기를 모르는 단어(`storyId == null`)는 이름 없는 묶음 하나로 모으고, 화면은
그 묶음의 **헤더와 필터 칩을 그리지 않습니다** — 붙일 이름이 없는데 지어내면
아이가 그걸 이야기 제목으로 읽습니다.

> **`entryType` 으로 목록을 거르지 마세요.** 화면의 하트가 이 값을 바꾸므로,
> 걸러서 받으면 하트를 켠 단어가 목록에서 사라집니다 — 아이는 자기가 지운 줄
> 압니다. 하트는 "분류를 바꾸는 것"이지 "목록에서 빼는 것"이 아닙니다.

**단어 음성 필드는 없습니다.** 화면은 기기 내장 목소리로 읽어 줍니다.
→ [DECISIONS.md](DECISIONS.md) 019

### `PATCH /children/{childId}/words/{wordId}/favorite`

`UNKNOWN` ↔ `FAVORITE` 토글. 바뀐 단어(`WordResponse`)를 그대로 돌려받습니다.
앱은 `entryType == 'FAVORITE'` 를 하트 켜짐으로 읽습니다.

### 아직 안 붙인 것

| 무엇 | API | 왜 |
|---|---|---|
| 단어 담기 | `POST /children/{childId}/words` | 이야기 재생 화면에 버튼이 아직 없음 |
| 단어 지우기 | `DELETE /children/{childId}/words/{wordId}` | 기획 요건 아님 |

담을 때는 **항상 `UNKNOWN` 으로** 저장해야 합니다. `FAVORITE` 으로 담으면
하트를 껐을 때 "모르는 말"로 잘못 분류됩니다.

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

### 보호자 인증 (`/auth`)

**`GET /auth/options`** — `providers[] {provider, label}` ·
`consents[] {id, title, required, docUrl}` · `ages[]`

동의 항목을 앱에 하드코딩하지 않는 이유: 문구 한 줄만 바뀌어도 재동의를
받아야 하는데, 그때마다 앱을 새로 배포할 수는 없습니다.

> ⚠️ **아동 개인정보 수집은 서비스 약관과 별도의 필수 항목**입니다.
> 하나로 묶어 내려주지 마세요 — 별도 동의를 받았다는 기록이 남지 않습니다.
> 마케팅은 반드시 `required: false`. (PRD F-01)

**로그인 응답은 "어디로 가야 하는가"를 함께 줘야 합니다.** 로그인 성공이 곧
홈 진입이 아닙니다 — 아이 프로필이 없으면 발화·단어장·리포트를 귀속시킬 데가
없습니다. 세 갈래를 서버가 알려주는 게 가장 정확합니다.

| 값 | 앱의 동작 |
|---|---|
| `needsConsent` | 동의 스텝으로 |
| `needsChild` | 아이 프로필 등록 스텝으로 |
| `ready` | 홈으로 |

**`POST /auth/consents`** — `{ "agreed": ["terms", "child_privacy"] }`.
**동의 시각은 서버가 기록**합니다. 클라이언트 시계는 믿을 수 없습니다.

**`POST /children`** — `{ "name": "하늘이", "age": 8 }`. 이 화면은 **최초 1명**만
책임집니다. 이후 추가는 마이페이지의 프로필 모달이 맡습니다.

> 목업은 실제 OAuth 를 붙이지 않았습니다. `auth_screen.json` 의 `demoAccounts`
> 는 **목업 전용**이고 서버 응답에는 없습니다. → `docs/DECISIONS.md` 018

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


20260812 12:48 am  노션으로 부터 추가 ( api 
# 굿퀘스천 API 요청·응답 DTO

> 원본은 `src/main/java/.../dto/` 의 record들이다. **불일치가 생기면 코드가 맞다.**
스키마 대응은 DB설계.md를 참고한다.
> 

---

## 1. 공통 규약

### 1.1 인증

- `/api/auth/**` 와 `/actuator/health` 만 인증 없이 접근한다. 나머지는 전부 Bearer 토큰이 필요하다.
- **보호자 식별자는 요청에 담지 않는다.** `@CurrentParentId`가 JWT에서 꺼내 주입한다. 아래 표의 요청 필드에 `parentId`가 없는 이유다.
- 아이·세션 리소스는 컨트롤러 진입 시 **소유권을 검증**한다. 남의 아이면 403.

### 1.2 오류 응답

모든 오류는 형태가 같다.

```json
{ "code": "CONSENT_REQUIRED", "message": "유효한 아동 동의가 필요합니다." }
```

| 상황 | 상태 | `code` |
| --- | --- | --- |
| 검증 실패(`@Valid`) | 400 | `INVALID_REQUEST` — message는 `필드명: 사유` |
| 토큰 없음·위조·**만료** | 401 | `UNAUTHORIZED` |
| 남의 리소스 | 403 | `FORBIDDEN` |
| 없는 리소스 | 404 | `NOT_FOUND` |
| 상태 충돌 | 409 | 아래 목록 |
| 값이 규칙에 안 맞음 | 422 | `STT_EMPTY_TEXT`, `GRID_OUT_OF_RANGE` |
| 미구현 스텁 | **501** | `NOT_IMPLEMENTED` |
| 그 외 | 500 | `INTERNAL_ERROR` |

409 코드: `CONSENT_REQUIRED` `SESSION_NOT_IN_PROGRESS` `SCENE_NOT_STORY` `SCENE_NOT_DIALOGUE` `REPORT_NOT_READY` `DUPLICATE_WORD` `DUPLICATE_EMAIL` `CELL_OCCUPIED` `ITEM_ALREADY_PLACED` `ITEM_LOCKED` `STARDUST_INSUFFICIENT` `MAX_TURNS_EXCEEDED` `MISSION_NOT_EXPOSED` `MISSION_ALREADY_SUBMITTED` `RETELLING_BEFORE_ORDER`

**501을 쓰는 이유** — 컨트롤러 골격만 있고 로직이 없는 엔드포인트가 200에 빈 본문을 돌려주면 프론트가 구현된 것으로 오해한다. 명시적으로 알린다.

**401과 403은 반드시 갈라 처리한다.** 리프레시 토큰이 없어 만료 복구 경로가 재로그인 하나뿐이므로, 클라이언트는 **401을 받으면 로그인 화면으로** 보내야 하고 403은 그냥 오류로 표시하면 된다. 스프링 시큐리티 기본값은 둘 다 403 + 빈 본문이라 `RestAuthenticationEntryPoint`·`RestAccessDeniedHandler`로 갈라 두었고, 두 응답 모두 위의 `{code, message}` 형태를 지킨다.

### 1.3 구현 상태 표기

| 표기 | 뜻 |
| --- | --- |
| ✅ | 호출하면 실제 값이 온다 |
| ⚠️ | 일부 경로만 동작 (설명 참고) |
| ⛔ | 호출하면 **501** — DTO 계약만 확정된 상태 |

---

## 2. 엔드포인트 총괄

### 2.1 인증 — `/api/auth` (인증 불필요)

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `/signup` | `SignUpRequest` | 201 `AuthResponse` | ✅ |
| POST | `/login` | `LoginRequest` | 200 `AuthResponse` | ✅ |
| POST | `/social/{provider}` | `SocialLoginRequest` | 200 `SocialAuthResponse` | ⚠️ `kakao`만. 그 외 501 |
| POST | `/refresh` | `TokenRefreshRequest` | 200 `TokenResponse` | ⛔ |
| POST | `/logout` | `LogoutRequest` | 204 (본문 없음) | ⛔ |

### 2.2 보호자 — `/api/parents`

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/me` | — | `ParentResponse` | ✅ |
| PATCH | `/me` | `ParentUpdateRequest` | `ParentResponse` | ⚠️ 이름만. `newPassword`를 보내면 501 |

### 2.3 아이 — `/api/children`

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `| `ChildCreateRequest` | 201 `ChildResponse` | ✅ | | GET |` | — | `List<ChildResponse>` | ✅ |
| GET | `/{childId}` | — | `ChildResponse` | ✅ |
| PATCH | `/{childId}` | `ChildUpdateRequest` | `ChildResponse` | ✅ |
| DELETE | `/{childId}` | — | 204 | ✅ |

아이를 만들면 행성·별가루 지갑이 같은 트랜잭션에서 함께 생긴다(응답에는 담지 않는다).

### 2.4 아동 동의 — `/api/children/{childId}/consents`

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `| `ConsentCreateRequest` | 201 `ConsentResponse` | ✅ | | GET |` | — | `ConsentStatusResponse` | ✅ |
| POST | `/withdraw` | — | `ConsentResponse` | ✅ |

### 2.5 홈

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/api/children/{childId}/home` | — | `HomeResponse` | ✅ |

### 2.6 콘텐츠

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/api/stories` | `?topic=` (선택) | `StoryListResponse` | ✅ |
| GET | `/api/stories/{storyId}` | — | `StoryDetailResponse` | ✅ |
| GET | `/api/stories/{storyId}/scenes` | — | `List<SceneContentResponse>` | ✅ |
| GET | `/api/topics` | — | `List<TopicResponse>` | ✅ |

### 2.7 세션

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `/api/children/{childId}/sessions` | `SessionStartRequest` | 201 `SessionStartResponse` | ✅ |
| GET | `/api/sessions/{sessionId}` | — | `SessionResponse` | ✅ |
| GET | `/api/sessions/{sessionId}/resume` | — | `SessionResumeResponse` | ⛔ |
| GET | `/api/sessions/{sessionId}/messages` | `?sceneId=` (선택) | `List<MessageResponse>` | ✅ |
| POST | `/api/sessions/{sessionId}/scenes/current/story-complete` | — | `SceneAdvanceResponse` | ✅ |
| POST | `/api/sessions/{sessionId}/stop` | — | 200 (본문 없음) | ✅ |
| POST | `/api/sessions/{sessionId}/scenes/current/opening` | — | `SceneOpeningResponse` | ⛔ |
| GET | `/api/sessions/{sessionId}/scenes/current` | — | `CurrentSceneResponse` | ⛔ |

### 2.8 대화(턴) — `/api/sessions/{sessionId}`

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `/utterances` | `UtteranceRequest` | `UtteranceResponse` | ⛔ 하위 파이프라인 미구현 |
| GET | `/turn-state` | — | `TurnStateResponse` | ⛔ |

### 2.9 미션 — `/api/sessions/{sessionId}/missions`

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/current` | — | `CurrentMissionResponse` | ⛔ |
| POST | `/{missionId}/result` | `MissionResultRequest` | 201 `MissionResultResponse` | ⛔ |

### 2.10 말하기 후 활동 — `/api/sessions/{sessionId}/post-activity`

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `/start` | — | `PostActivityStartResponse` | ⛔ |
| GET | ``| — |`PostActivityStatusResponse`| ⛔ | | POST |`/order`|`CardSubmitRequest`|`CardSubmitResponse`| ⛔ | | POST |`/retelling`|`RetellingRequest`|`RetellingResponse` | ⛔ |  |  |

### 2.10-1 후속 자유 대화 — `/api/.../free-talk`

이야기를 **완주한 아이만** 그 이야기의 인물과 이어서 대화합니다. 학습 대화와
달리 목표 요소·미션·별가루가 없고, 리포트에도 반영되지 않습니다.
→ 설계 문서 「후속 자유 대화」

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/api/children/{childId}/stories/{storyId}/free-talk/characters` | — | `List<FreeTalkCharacterResponse>` | ⛔ |
| POST | `/api/children/{childId}/free-talk` | `{ storyId, characterId }` | `FreeTalkStartResponse` | ⛔ |
| POST | `/api/free-talk/{freeTalkId}/messages` | `{ text }` + `Idempotency-Key` | `FreeTalkTurnResponse` | ⛔ |
| POST | `/api/free-talk/{freeTalkId}/end` | — | `{ closing }` | ⛔ |

- `FreeTalkCharacterResponse` — `characterId` · `name` · `characterKey` ·
  `thumbnailUrl`(선택) · `lastTalkedAt`(선택)
- `FreeTalkStartResponse` — `freeTalkId` · `character` · `opening{text,audioUrl,emotion}` · `maxTurns`
- `FreeTalkTurnResponse` — `characterMessage{text,audioUrl,emotion}` · `turnCount` · `ended`
- 완주하지 않은 이야기는 인물 목록에서 404. 화면은 에러가 아니라 안내로 돌려세웁니다.
- **STT·TTS 는 학습 대화와 같은 `/api/stt` · `/api/tts` 를 씁니다.** 자유 대화
  전용 음성 엔드포인트를 따로 두지 않습니다.
- `maxTurns` 를 받지만 **화면에 그리지 않습니다**. 대화가 닫히는 판단은
  `ended` 하나로 합니다 — 프런트가 세면 서버가 안전 사유로 일찍 닫은 대화를
  계속 이어 가려 듭니다.
- `opening.audioUrl` 이 있으면 대사를 **문장으로 쪼개지 않고 통째로** 띄웁니다.
  문장별 실측 구간(`audioTimings`)이 없어서, 쪼개면 자막이 소리와 어긋납니다.

### 2.11 리포트

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/api/children/{childId}/reports` | — | `List<ReportListResponse>` | ⛔ |
| GET | `/api/sessions/{sessionId}/report` | — | `ReportDetailResponse` | ⛔ |
| POST | `/api/sessions/{sessionId}/report` | — | 201 `ReportDetailResponse` | ⛔ |

### 2.12 단어장

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `/api/children/{childId}/words` | `WordCreateRequest` | 201 `WordResponse` | ⛔ |
| GET | `/api/children/{childId}/words` | `?entryType=` (선택) | `List<WordResponse>` | ✅ |
| PATCH | `/api/children/{childId}/words/{wordId}/favorite` | — | `WordResponse` | ✅ |
| POST | `/api/children/{childId}/words/{wordId}/sentence-practice` | `SentencePracticeRequest` | `SentencePracticeResponse` | ✅ |
| DELETE | `/api/words/{wordId}` | — | 204 | ⛔ |

### 2.13 보상 — 상점·보관함

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/api/children/{childId}/shop/items` | — | `List<ShopItemResponse>` | ⛔ |
| POST | `/api/children/{childId}/items` | `ItemPurchaseRequest` | 201 `ItemPurchaseResponse` | ⛔ |
| GET | `/api/children/{childId}/items` | `?placed=` (선택) | `List<ChildItemResponse>` | ⛔ |

### 2.14 보상 — 별가루

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/api/children/{childId}/stardust` | — | `StardustWalletResponse` | ⛔ |
| POST | `/api/children/{childId}/stardust/acknowledge` | — | `StardustAcknowledgeResponse` | ⛔ |

### 2.15 보상 — 행성·배치

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| GET | `/api/children/{childId}/planet` | — | `PlanetResponse` | ⛔ |
| PATCH | `/api/children/{childId}/planet` | `PlanetRenameRequest` | `PlanetRenameResponse` | ⛔ |
| POST | `/api/children/{childId}/planet/tutorial-complete` | — | `TutorialCompleteResponse` | ⛔ |
| POST | `/api/children/{childId}/planet/placements` | `PlacementCreateRequest` | 201 `PlacementResponse` | ⛔ |
| PATCH | `/api/planet/placements/{placementId}` | `PlacementMoveRequest` | `PlacementResponse` | ⛔ |
| DELETE | `/api/planet/placements/{placementId}` | — | 204 | ⛔ |

배치 3종은 **행 단위 조작**이다. 스냅샷 통짜 저장이 아니라 놓기·옮기기·치우기를 각각 호출한다. 되돌리기 전용 API는 없고 클라이언트가 직전 조작의 역조작을 부른다.

### 2.16 음성

| 메서드 | 경로 | 요청 | 응답 | 상태 |
| --- | --- | --- | --- | --- |
| POST | `/api/stt` | `multipart/form-data`, 파트명 `audio` | `TranscriptionResponse` | ✅ |
| POST | `/api/tts` | `SynthesisRequest` | `SynthesisResponse` | ✅ |

> **멀티파트 한도 주의** — 30초 16kHz mono WAV가 약 960KB인데 Spring Boot 기본 `max-file-size`가 1MB다. 아슬아슬하게 걸리므로 설정을 올려야 한다. (→ §6)
> 

---

## 3. DTO 상세

각 DTO 아래의 **사용처**가 그 DTO를 주고받는 엔드포인트다. `X에 중첩`은 단독 응답이 아니라 다른 DTO의 필드로만 실려 나간다는 뜻이고, 그때는 최종적으로 어느 엔드포인트가 전달하는지도 함께 적었다.

여기에 없는 엔드포인트는 **요청·응답 본문이 아예 없는 둘**뿐이다 — `POST /api/sessions/{sessionId}/stop`(200, 빈 본문)과 `DELETE /api/words/{wordId}`(204).

### 3.1 공통

#### `ErrorResponse`

> **사용처** — 모든 엔드포인트의 4xx·5xx 응답 본문
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `code` | String | `ErrorCode` 이름 또는 `INVALID_REQUEST` |
| `message` | String | 사람이 읽는 설명 |

---

### 3.2 인증·계정

#### `SignUpRequest`

> **사용처** — `POST /api/auth/signup` 요청
> 

| 필드 | 타입 | 검증 |
| --- | --- | --- |
| `email` | String | `@NotBlank @Email @Size(max=255)` |
| `password` | String | `@NotBlank @Size(min=8, max=64)` |
| `name` | String | `@NotBlank @Size(max=50)` |

#### `LoginRequest`

> **사용처** — `POST /api/auth/login` 요청
> 

| 필드 | 타입 | 검증 |
| --- | --- | --- |
| `email` | String | `@NotBlank @Email` |
| `password` | String | `@NotBlank` |

#### `SocialLoginRequest`

> **사용처** — `POST /api/auth/social/{provider}` 요청
> 

| 필드 | 타입 | 검증 |
| --- | --- | --- |
| `authorizationCode` | String | `@NotBlank` |
| `redirectUri` | String | `@NotBlank` |

**서버가 인가 코드를 제공자 토큰으로 교환한다.** 클라이언트가 액세스 토큰을 직접 넘기지 않는다 — 넘기면 검증 없이 신뢰해야 한다.

#### `TokenRefreshRequest` / `LogoutRequest`

> **사용처** — `POST /api/auth/refresh` 요청 / `POST /api/auth/logout` 요청
> 

| 필드 | 타입 | 검증 |
| --- | --- | --- |
| `refreshToken` | String | `@NotBlank` |

#### `TokenResponse`

> **사용처** — `POST /api/auth/refresh` 응답 · `AuthResponse`·`SocialAuthResponse`에 중첩
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `accessToken` | String |  |
| `refreshToken` | String | **현재 항상 null** — 회전 정책 미구현 |
| `accessTokenExpiresIn` | long | 초 |

#### `AuthResponse` / `SocialAuthResponse`

> **사용처** — `POST /api/auth/signup`·`/login` 응답 / `POST /api/auth/social/{provider}` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `tokens` | `TokenResponse` |  |
| `parent` | `ParentResponse` |  |
| `isNewUser` | boolean | **`SocialAuthResponse`에만** — 최초 가입이면 true |

#### `ParentResponse`

> **사용처** — `GET /api/parents/me`·`PATCH /api/parents/me` 응답 · `AuthResponse`·`SocialAuthResponse`에 중첩
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | UUID |  |
| `email` | String | 소셜 전용 계정은 null |
| `name` | String |  |
| `provider` | `AuthProvider` | **소셜일 때만 값.** 이메일 계정은 null |

DB의 `provider`는 `LOCAL`/`KAKAO` 둘 다 NOT NULL이지만, 응답에서는 `LOCAL`을 null로 바꿔 내린다. 클라이언트는 “값이 있으면 소셜”로만 판단하면 된다.

#### `ParentUpdateRequest`

> **사용처** — `PATCH /api/parents/me` 요청
> 

| 필드 | 타입 | 검증 | 설명 |
| --- | --- | --- | --- |
| `name` | String | `@Size(max=50)` | 전달한 필드만 반영 |
| `currentPassword` | String |  | `newPassword`와 함께 보낸다 |
| `newPassword` | String | `@Size(min=8)` | 보내면 현재 501 |

---

### 3.3 아이·동의

#### `ChildCreateRequest` / `ChildUpdateRequest`

> **사용처** — `POST /api/children` 요청 / `PATCH /api/children/{childId}` 요청
> 

| 필드 | 타입 | 검증 |
| --- | --- | --- |
| `name` | String | Create `@NotBlank @Size(max=50)` / Update `@Size(max=50)` |
| `birthYear` | Short | Create `@NotNull @Min(2000) @Max(2100)` / Update 동일하되 선택 |

#### `ChildResponse`

> **사용처** — `POST /api/children` · `GET /api/children` · `GET /api/children/{childId}` · `PATCH /api/children/{childId}` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | UUID |  |
| `name` | String |  |
| `birthYear` | short |  |
| `age` | int | **저장하지 않는다** — 현재연도 − 출생연도 |
| `consentStatus` | `ConsentStatus` |  |

#### `ConsentCreateRequest`

> **사용처** — `POST /api/children/{childId}/consents` 요청
> 

| 필드 | 타입 | 검증 |
| --- | --- | --- |
| `consentVersion` | String | `@NotBlank` (예: `mvp_v1`) |
| `verificationMethod` | `VerificationMethod` | `@NotNull` — `AUTHENTICATED_PARENT` / `INSTITUTION_PAPER` / `MOBILE_VERIFICATION` |

#### `ConsentResponse`

> **사용처** — `POST /api/children/{childId}/consents` · `POST /api/children/{childId}/consents/withdraw` 응답 · `ConsentStatusResponse`에 중첩
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` `consentVersion` `consentedAt` |  |  |
| `withdrawnAt` | OffsetDateTime | null이면 유효 |

#### `ConsentStatusResponse`

> **사용처** — `GET /api/children/{childId}/consents` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `current` | `ConsentResponse` | **null이면 새 세션을 시작할 수 없다** |
| `history` | `List<ConsentResponse>` | 철회분 포함 전체 이력 |

---

### 3.4 홈

#### `HomeResponse`

> **사용처** — `GET /api/children/{childId}/home` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `inProgressSession` | `SessionSummaryResponse` | 없으면 null |
| `recommendedStories` | `List<StoryCardResponse>` | 현재는 PUBLISHED 최신 3개 |
| `planetWidget` | `PlanetWidget` |  |

**`PlanetWidget`**: `stardustBalance` int, `placedCount` int, `hasUnacknowledged` boolean

`hasUnacknowledged`가 true면 행성 진입 전에 연출 예고 점을 표시한다.

---

### 3.5 콘텐츠

#### `StoryCardResponse` — 목록과 홈 추천이 공유

> **사용처** — `StoryListResponse`·`StoryDetailResponse`·`HomeResponse`에 중첩 → 최종 전달: `GET /api/stories` · `GET /api/stories/{storyId}` · `GET /api/children/{childId}/home`
> 

`id` · `title` · `summary` · `difficulty` · `estimatedMinutes`(Short) · `imageUrl` · `topics`(`List<String>`)

#### `StoryListResponse`

> **사용처** — `GET /api/stories` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `stories` | `List<StoryCardResponse>` | `?topic=` 필터 적용 결과 |
| `topics` | `List<String>` | **필터와 무관하게 항상 전체** — 필터 칩을 그리는 용도 |

페이징은 없다. MVP 콘텐츠 수가 한 화면에 들어간다.

#### `StoryDetailResponse`

> **사용처** — `GET /api/stories/{storyId}` 응답
> 

| 필드 | 타입 |
| --- | --- |
| `story` | `StoryCardResponse` (중첩) |
| `sceneCount` | int |
| `childRole` | String |
| `intro` | String |

#### `SceneContentResponse` — 세션 시작·이어하기·장면 전환·현재 장면이 공유

> **사용처** — `GET /api/stories/{storyId}/scenes` 응답 · `SessionStartResponse`·`SessionResumeResponse`·`SceneAdvanceResponse`·`CurrentSceneResponse`에 중첩
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `sceneId` | UUID |  |
| `sceneOrder` | short |  |
| `sceneType` | `SceneType` | `STORY` / `DIALOGUE` |
| `narrationSentences` | `List<String>` | STORY만. DIALOGUE는 빈 배열 |
| `imageUrl` | String |  |
| `characterName` | String | DIALOGUE만 |
| `maxTurns` | Short | DIALOGUE만 — 남은 턴 UI |

**내레이션 분리는 서버가 한다.** 줄바꿈 기준으로 자른다 — 마침표로 자르면 `1.5km` 같은 표현이 깨진다.

**서버 내부 설정은 담지 않는다.** `element_criteria`·`remaining_worries`·`mission_config`·`scene_stance`·`proper_nouns`·`character_persona`는 전부 LLM·STT 입력이라 클라이언트가 알 필요가 없다.

#### `TopicResponse`

> **사용처** — `GET /api/topics` 응답
> 

`id`(UUID) · `name`(String)

---

### 3.6 세션

#### `SessionStartRequest`

> **사용처** — `POST /api/children/{childId}/sessions` 요청
> 

`storyId`(UUID)

#### `SessionStartResponse`

> **사용처** — `POST /api/children/{childId}/sessions` 응답
> 

`sessionId` · `status`(`SessionStatus`) · `currentScene`(`SceneContentResponse`) · `phase`(`PlayPhase`)

도입 장면을 즉시 렌더할 수 있게 콘텐츠 전체를 함께 준다.

#### `SessionResponse`

> **사용처** — `GET /api/sessions/{sessionId}` 응답 · `SessionResumeResponse`에 중첩
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `sessionId` `childId` `storyId` | UUID |  |
| `status` | `SessionStatus` | `IN_PROGRESS`/`POST_ACTIVITY`/`COMPLETED`/`STOPPED` |
| `currentScene` | `SceneRef` | `{sceneId, sceneOrder, sceneType}` — 식별 정보만 |
| `phase` | `PlayPhase` | `STORY`/`DIALOGUE`/`POST_ACTIVITY`/`ENDED` |
| `progress` | `ProgressResponse` |  |
| `sceneGoalMet` | boolean |  |
| `lastActivityAt` | OffsetDateTime |  |

**`phase`는 저장값이 아니다.** `status` + 현재 장면 유형에서 파생한다. 프론트가 화면을 고르는 단일 근거라 서버가 계산해 내린다.

#### `ProgressResponse`

> **사용처** — `SessionResponse`·`UtteranceResponse`·`TurnStateResponse`에 중첩 → 최종 전달: `GET /api/sessions/{sessionId}` · `POST /api/sessions/{sessionId}/utterances` · `GET /api/sessions/{sessionId}/turn-state`
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `mode` | `ResponseMode` | `NORMAL`/`GUIDED`/`CLOSING` |
| `accumulatedElements` | `List<ThinkingElement>` | 현재 장면 누적 |
| `missingElements` | `List<ThinkingElement>` | **저장하지 않고 계산** (목표 − 누적) |
| `turnCount` `maxTurns` | int |  |
| `guidanceTarget` | `ThinkingElement` | GUIDED일 때만 |

#### `SessionResumeResponse`

> **사용처** — `GET /api/sessions/{sessionId}/resume` 응답
> 

`session`(`SessionResponse`) · `currentScene`(`SceneContentResponse`) · `messages`(`List<MessageResponse>`) · `lastCharacterMessage`(`CharacterMessageResponse`) · `exposedMission`(`MissionResponse`)

#### `SessionSummaryResponse` — 홈 이어하기 카드

> **사용처** — `HomeResponse`에 중첩 → 최종 전달: `GET /api/children/{childId}/home`
> 

`sessionId` · `storyId` · `storyTitle` · `storyImageUrl` · `status` · `currentSceneOrder`(short) · `totalScenes`(int) · `lastActivityAt`

#### `MessageResponse`

> **사용처** — `GET /api/sessions/{sessionId}/messages` 응답 · `SessionResumeResponse`·`UtteranceResponse`에 중첩
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `messageId` | UUID |  |
| `speakerType` | `SpeakerType` | `CHILD`/`CHARACTER`/`SYSTEM` |
| `turnOrder` | int | 세션 안에서 유일. 장면이 바뀌어도 이어진다 |
| `text` | String | 이름 치환이 끝난 상태 |
| `sttLowConfidence` | boolean | **아이 발화만 의미 있다** |
| `characterEmotion` | `CharacterEmotion` | 캐릭터 발화만 |
| `createdAt` | OffsetDateTime |  |

`sttConfidence` 원값은 내부 지표라 내리지 않는다. 화면은 “미덥지 않았다”는 사실만 알면 다시 말하기를 안내할 수 있다.

#### `CharacterMessageResponse`

> **사용처** — `SceneOpeningResponse`·`SceneAdvanceResponse`·`SessionResumeResponse`·`UtteranceResponse`에 중첩 → 최종 전달: `POST /api/sessions/{sessionId}/scenes/current/opening` · `POST /api/sessions/{sessionId}/scenes/current/story-complete` · `GET /api/sessions/{sessionId}/resume` · `POST /api/sessions/{sessionId}/utterances`
> 

`messageId` · `text` · `audioUrl`

`audioUrl`이 null이면 클라이언트가 `/api/tts`를 호출한다. 고정 대사는 사전 렌더 음성(`scene_audio`)을 내려줄 수 있다.

#### `SceneOpeningResponse`

> **사용처** — `POST /api/sessions/{sessionId}/scenes/current/opening` 응답
> 

`message`(`CharacterMessageResponse`) · `alreadyOpened`(boolean)

**멱등이다.** 재호출하면 새 메시지를 만들지 않고 `alreadyOpened=true`로 알린다.

#### `SceneAdvanceResponse`

> **사용처** — `POST /api/sessions/{sessionId}/scenes/current/story-complete` 응답
> 

`phase`(`PlayPhase`) · `currentScene`(`SceneContentResponse`) · `openingMessage`(`CharacterMessageResponse`)

다음 장면이 DIALOGUE면 고정 첫 대사를 함께 저장·반환한다. 마지막 장면이 STORY로 끝났다면 `phase=POST_ACTIVITY`이고 `currentScene`은 null이다.

#### `SceneTransitionResponse`

> **사용처** — `UtteranceResponse`에 중첩 — 장면 종료 턴에만 → 최종 전달: `POST /api/sessions/{sessionId}/utterances`
> 

`next`(`SceneTransitionTarget`) · `nextSceneId` · `nextSceneOrder`(Integer) · `nextSceneType` · `closingReason`(`SceneEndReason`)

#### `CurrentSceneResponse` / `TurnStateResponse`

> **사용처** — `GET /api/sessions/{sessionId}/scenes/current` 응답 / `GET /api/sessions/{sessionId}/turn-state` 응답
> 

`{currentScene, phase}` / `{progress, phase}`

---

### 3.7 대화(턴)

#### `UtteranceRequest`

> **사용처** — `POST /api/sessions/{sessionId}/utterances` 요청
> 

| 필드 | 타입 | 검증 | 설명 |
| --- | --- | --- | --- |
| `text` | String | `@NotBlank` | 확정 발화 텍스트 |
| `sttRawText` | String |  | STT 최초 변환 텍스트 |
| `sttConfidence` | BigDecimal | `@DecimalMin(0.0) @DecimalMax(1.0)` | 선택 |
| `sttRetryCount` | Short | `@PositiveOrZero` | 선택, 기본 0 |
| `missionId` | String |  | 이 발화가 미션 수행 결과일 때 |

**`sttLowConfidence`는 요청에 없다.** 기준값 판정은 서버가 한다 — 클라이언트마다 기준이 갈리면 리포트 필터링이 흔들린다. (기준값 자체는 아직 미정이라 지금은 저장만 한다.)

#### `UtteranceResponse` — 단일 스키마, null 여부로 분기

> **사용처** — `POST /api/sessions/{sessionId}/utterances` 응답
> 

| 필드 | 타입 | 언제 값이 있나 |
| --- | --- | --- |
| `childMessage` | `MessageResponse` | 항상 |
| `analysis` | `AnalysisResponse` | 항상 |
| `progress` | `ProgressResponse` | 항상 |
| `characterMessage` | `CharacterMessageResponse` | 항상 (종료 시엔 고정 마지막 대사) |
| `mission` | `MissionResponse` | **미션 노출 턴** |
| `sceneTransition` | `SceneTransitionResponse` | **장면 종료 턴** (`progress.mode=CLOSING`) |
| `safety` | `SafetyResponse` | **위험 신호로 대사 생성이 중단된 턴** |

**분기 판단**
- 대화 계속 → `mission`·`sceneTransition`·`safety` 모두 null
- 미션 노출 → `mission` 있음
- 장면 종료 → `sceneTransition` 있음
- 안전 개입 → `safety` 있음. 이때 `characterMessage`는 생성 대사가 아니라 **안전 문구**다

#### `AnalysisResponse`

> **사용처** — `UtteranceResponse`에 중첩 → 최종 전달: `POST /api/sessions/{sessionId}/utterances`
> 

`childIntent`(13종) · `mainPoint` · `detectedElements`(`List<DetectedElement>`) · `utteranceValidity`(5종)

**캐릭터 표정·태도 변화의 트리거를 겸한다.** 프론트가 자체 판단하지 않고 이 값으로만 연출한다.

`analysisVersion`·`modelId`·`droppedEvidence`는 내부 추적용이라 내리지 않는다.

**`DetectedElement`**: `type`(`ThinkingElement`) · `evidence`(String — 아이 발화 원문의 근거 문구)

#### `SafetyResponse`

> **사용처** — `UtteranceResponse`에 중첩 — 안전 개입 턴에만 → 최종 전달: `POST /api/sessions/{sessionId}/utterances`
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `categories` | `List<String>` | 감지 범주만. **아이 발화 원문은 담지 않는다** |
| `recoveryAvailable` | boolean | true면 오탐 복귀 버튼 노출 |

---

### 3.8 미션

#### `MissionResponse`

> **사용처** — `CurrentMissionResponse`·`UtteranceResponse`·`SessionResumeResponse`에 중첩 → 최종 전달: `GET /api/sessions/{sessionId}/missions/current` · `POST /api/sessions/{sessionId}/utterances` · `GET /api/sessions/{sessionId}/resume`
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `missionId` | String |  |
| `missionType` | `MissionType` | `PROBLEM_SOLVING` / `PERSPECTIVE_SHIFT` |
| `title` `description` | String |  |
| `payload` | `Payload` | `{questions, cards}` — **유형에 따라 한쪽만 값이 있다** |
- `Question`: `key`(`tool`/`safety`/`request`/`expectedResult`로 고정) · `label`
- `Card`: `key` · `label` · `imageUrl` · `template`

#### `CurrentMissionResponse`

> **사용처** — `GET /api/sessions/{sessionId}/missions/current` 응답
> 

`mission`(`MissionResponse`) — **미노출 상태면 null이고 404가 아니다.** 노출 여부는 정상 상태이지 오류가 아니다.

#### `MissionResultRequest`

> **사용처** — `POST /api/sessions/{sessionId}/missions/{missionId}/result` 요청
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `answers` | `Map<String,String>` | 미션1 — Question의 key별 답 |
| `cards` | `List<CardAnswer>` | 미션2 — `{key, strengthText}` |

#### `MissionResultResponse`

> **사용처** — `POST /api/sessions/{sessionId}/missions/{missionId}/result` 응답
> 

`missionId` · `accepted`(boolean) — 결과는 다음 턴 캐릭터 대사에 반영된다.

---

### 3.9 말하기 후 활동

#### `PostActivityStartResponse`

> **사용처** — `POST /api/sessions/{sessionId}/post-activity/start` 응답 · 중첩 `Card`는 `PostActivityStatusResponse`도 재사용
> 

`cards`(`List<Card>`) · `attemptCount`(short)
- `Card`: `cardId` · `text`

**정답 순서는 담지 않는다.** 판정은 서버만 한다.
카드 순서는 `card_order_seed`로 고정되어 재호출해도 같다.

#### `PostActivityStatusResponse`

> **사용처** — `GET /api/sessions/{sessionId}/post-activity` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `status` | String | 후속 활동 진행 단계 |
| `cards` | `List<PostActivityStartResponse.Card>` | 시작 응답과 **같은 순서** (시드로 고정) |
| `attemptCount` | short |  |
| `isOrderCorrect` | Boolean | 아직 제출 전이면 null |
| `retellingKeywords` | `List<String>` | 카드 순서를 맞춘 뒤에만 값이 있다 |
| `retellingText` | String |  |
| `completedAt` | OffsetDateTime |  |

**새로고침 복구용이다.** 앱을 껐다 켜도 이 응답 하나로 후속 활동 화면을 그대로 되살린다 — 카드 순서가 시드로 고정돼 있어 같은 화면이 나온다.

#### `CardSubmitRequest` / `CardSubmitResponse`

> **사용처** — `POST /api/sessions/{sessionId}/post-activity/order` 요청 / 응답
> 

|  | 필드 | 설명 |
| --- | --- | --- |
| 요청 | `submittedOrder` `List<String>` `@NotEmpty` | cardId 순서 |
| 응답 | `correct` boolean, `retellingKeywords` `List<String>` | **오답이면 `retellingKeywords`가 null** (재시도) |

#### `RetellingRequest`

> **사용처** — `POST /api/sessions/{sessionId}/post-activity/retelling` 요청
> 

`text`(`@NotBlank`) · `sttRawText`

#### `RetellingResponse` — 재구성 발화 제출 = 세션 완료 + 별가루 지급

> **사용처** — `POST /api/sessions/{sessionId}/post-activity/retelling` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `sessionStatus` | String |  |
| `completedAt` | OffsetDateTime |  |
| `stardust` | `Stardust` | `{earned, breakdown, balance}` |
| `unlockedItems` | `List<UnlockedItem>` | `{itemId, name, thumbnailUrl}` — 이번 완주로 열린 것 |

지급 결과를 이 응답에 담아야 하므로 **세션 완료 처리는 같은 트랜잭션에서 동기로 끝낸다.**

---

### 3.10 리포트

#### `ReportListResponse`

> **사용처** — `GET /api/children/{childId}/reports` 응답
> 

`id` · `sessionId` · `storyTitle` · `createdAt`

#### `ReportDetailResponse`

> **사용처** — `GET /api/sessions/{sessionId}/report` · `POST /api/sessions/{sessionId}/report` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` `sessionId` `storyTitle` `summary` |  |  |
| `strengths` | `List<ReportItem>` | `{element, comment}` |
| `nextFocus` | `List<ReportItem>` | `{element, comment}` |
| `representativeUtterances` | `List<RepresentativeUtterance>` | `{text, element}` |
| `createdAt` | OffsetDateTime |  |

**`ReportItem`을 그대로 내린다.** 요소 코드만 내리면 화면에 “REASON”만 뜨고 왜 잘했는지가 사라진다 — 보호자에게 보여줄 문장이 `comment`에 있다.

**대표 발화는 저장값이 아니다.** 조회 시 `messages` + `utterance_analyses`의 근거에서 구성하고, `sttLowConfidence=true`인 발화는 후보에서 제외한다.

---

### 3.11 단어장

#### `WordCreateRequest`

> **사용처** — `POST /api/children/{childId}/words` 요청
> 

| 필드 | 타입 | 검증 | 설명 |
| --- | --- | --- | --- |
| `word` | String | `@NotBlank @Size(max=50)` |  |
| `entryType` | `WordEntryType` | `@NotNull` | `UNKNOWN` / `FAVORITE` |
| `sourceSceneId` | UUID |  |  |
| `meaning` | String |  | **없으면 서버가 LLM으로 생성** |
| `exampleSentence` | String |  |  |

같은 아이가 같은 단어를 또 저장하면 409 `DUPLICATE_WORD`.

#### `WordResponse`

> **사용처** — `POST /api/children/{childId}/words` · `GET /api/children/{childId}/words` · `PATCH /api/children/{childId}/words/{wordId}/favorite` 응답
> 

`id` · `word` · `meaning` · `exampleSentence` · `exampleSentenceDaily` · `exampleSentenceAdvanced` · `entryType` · `sourceSceneId` · `storyId` · `storyTitle` · `storyImageUrl` · `createdAt`

예문 확장 전에 담은 단어는 `exampleSentenceDaily` / `exampleSentenceAdvanced` 가 null 이다. 목록은 평면이고, 프론트가 `storyId` 로 이야기별 그룹핑을 한다.

#### `SentencePracticeRequest` / `SentencePracticeResponse`

> **사용처** — `POST /api/children/{childId}/words/{wordId}/sentence-practice`
> 

요청: `sentenceType`(`STORY` / `DAILY` / `ADVANCED`) · `spokenText`(max 500)

응답: `matched` · `similarity`(0.00 ~ 1.00) · `targetSentence` · `rewarded` · `skipReason`(`ALREADY_REWARDED` / `DAILY_LIMIT` / null) · `stardustAmount` · `stardustBalance`

유사도 90% 이상이면 별가루 2개. 단, 같은 문장은 평생 1회, 하루 최대 2회까지만 지급하고 초과분은 `skipReason` 으로 알려 준다. 해당 종류의 예문이 없는 단어면 409 `EXAMPLE_SENTENCE_MISSING`.

---

### 3.12 보상

#### `ShopItemResponse`

> **사용처** — `GET /api/children/{childId}/shop/items` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `itemId` `name` `category` `price` `modelUrl` `thumbnailUrl` |  |  |
| `unlocked` | boolean |  |
| `silhouette` | boolean | 잠긴 아이템을 실루엣으로 표시할지 |
| `unlockGuide` | `UnlockGuide` | `{storyTitle, storyImageUrl}` — 이야기 완주 해금만 |
| `purchasable` | boolean | 해금 + 잔액 충분 |
| `shortfall` | int | 모자란 별가루 |

**해금·구매 가능·부족 수량은 전부 서버가 계산해 내린다.** 프론트 판정 금지 — 가격 규칙이 두 곳에 있으면 어긋난다.

`status=HIDDEN`인 아이템은 목록에서 빠진다(응답 필드로 노출하지 않는다).

#### `ItemPurchaseRequest` / `ItemPurchaseResponse`

> **사용처** — `POST /api/children/{childId}/items` 요청 / 응답
> 

`itemId`(`@NotNull`) → `{item: ChildItemResponse, balance: int}`

#### `ChildItemResponse`

> **사용처** — `GET /api/children/{childId}/items` 응답 · `ItemPurchaseResponse`에 중첩
> 

`childItemId` · `itemId` · `name` · `category` · `thumbnailUrl` · `modelUrl` · `acquiredAt` · `placed`(boolean)

**`placed=false`면 보관함에 있다.** 보관함은 `child_items` − `planet_items`로 계산하는 파생값이다.

#### `StardustWalletResponse`

> **사용처** — `GET /api/children/{childId}/stardust` 응답
> 

`balance` · `totalEarned` · `unacknowledged`(`List<StardustTransactionResponse>`)

`unacknowledged`가 비어 있지 않으면 행성 진입 시 별가루가 떨어지는 연출을 재생한다.

#### `StardustTransactionResponse`

> **사용처** — `StardustWalletResponse`·`RetellingResponse`에 중첩 → 최종 전달: `GET /api/children/{childId}/stardust` · `POST /api/sessions/{sessionId}/post-activity/retelling`
> 

`transactionId` · `amount`(지급 +, 사용 −) · `reason` · `createdAt`

`reason`: `STORY_COMPLETED` / `SCENE_BONUS` / `ITEM_PURCHASE` / `ADMIN_ADJUST`
한 세션에서 `SCENE_BONUS`가 **최대 2건** 나올 수 있다.

`sessionId`·`sceneId`는 서버 멱등 판정용이라 내리지 않는다.

#### `StardustAcknowledgeResponse`

> **사용처** — `POST /api/children/{childId}/stardust/acknowledge` 응답
> 

`acknowledgedCount`(int)

#### `PlanetResponse`

> **사용처** — `GET /api/children/{childId}/planet` 응답
> 

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `planetId` `name` |  |  |
| `tutorialCompleted` | boolean |  |
| `placedItems` | `List<PlacementResponse>` |  |
| `progress` | `Progress` | `{placedCount, nextUnlock}` |
- `NextUnlock`: `itemName` · `thumbnailUrl` · `conditionText` — 모두 해금되면 null

**판 크기·모양은 응답에 없다.** 클라이언트 카탈로그가 단일 소스다.

#### `PlacementCreateRequest` / `PlacementMoveRequest` / `PlacementResponse`

> **사용처** — `POST /api/children/{childId}/planet/placements` 요청 / `PATCH /api/planet/placements/{placementId}` 요청 / 두 엔드포인트의 응답 · `PlanetResponse`에 중첩
> 

|  | 필드 |
| --- | --- |
| Create | `childItemId`(`@NotNull`) · `placedQ`(`@NotNull`) · `placedR`(`@NotNull`) |
| Move | `placedQ` · `placedR` |
| Response | `placementId` · `childItemId` · `itemId` · `modelUrl` · `placedQ` · `placedR` |

**좌표는 축좌표(q, r)이고 음수가 유효하다.** 원점 기준이라 `@PositiveOrZero`를 붙이면 절반의 판이 막힌다.

같은 칸에 놓으면 409 `CELL_OCCUPIED`, 이미 배치된 아이템이면 409 `ITEM_ALREADY_PLACED`.

#### `PlanetRenameRequest` / `PlanetRenameResponse` / `TutorialCompleteResponse`

> **사용처** — `PATCH /api/children/{childId}/planet` 요청 / 응답 · `POST /api/children/{childId}/planet/tutorial-complete` 응답
> 

`name`(`@NotBlank @Size(1..30)`) → `{planetId, name}` / `{tutorialCompleted}`

---

### 3.13 음성

#### `TranscriptionResponse`

> **사용처** — `POST /api/stt` 응답
> 

`text`(String) — 인식 결과가 비면 422 `STT_EMPTY_TEXT`.

#### `SynthesisRequest` / `SynthesisResponse`

> **사용처** — `POST /api/tts` 요청 / 응답
> 

|  | 필드 | 설명 |
| --- | --- | --- |
| 요청 | `text`(`@NotBlank`) · `characterName` | 이름이 있으면 캐릭터 보이스, 없으면 내레이션 보이스 |
| 응답 | `audioUrl` · `expiresAt` | **바이트를 직접 내리지 않는다** — URL이라야 다시 듣기·캐싱이 된다 |

---

## 4. 여러 응답이 공유하는 DTO

정확한 경로는 §3의 각 DTO **사용처**에 있다. 이 표는 “어떤 것이 공유되는지”만 한눈에 보기 위한 것이다.

| DTO | 쓰이는 곳 |
| --- | --- |
| `StoryCardResponse` | 이야기 목록, 이야기 상세, 홈 추천 |
| `SceneContentResponse` | 세션 시작, 이어하기, 장면 전환, 현재 장면 |
| `ProgressResponse` | 세션 조회, 턴 처리, 턴 상태 |
| `MessageResponse` | 대화 기록 조회, 이어하기, 턴 처리 |
| `CharacterMessageResponse` | 턴 처리, 첫 대사 재생, 장면 이동, 이어하기 |
| `ParentResponse` | 회원가입, 로그인, 소셜 로그인, 내 정보 |
| `StardustTransactionResponse` | 지갑 조회, 후속 활동 완료 |
| `ChildItemResponse` | 보관함 조회, 구매 결과 |
| `PlacementResponse` | 행성 조회, 놓기, 옮기기 |
| `SessionSummaryResponse` | 홈 이어하기 |

한 화면이 아니라 **한 개념이 하나의 DTO를 갖는다.** 화면마다 DTO를 만들면 같은 개념이 여러 형태로 갈라진다.

---

## 5. 응답 설계 원칙

**1. 판정은 전부 서버가 한다.** 해금 여부·구매 가능·부족 수량·정답 여부·진행 단계·부족 요소를 클라이언트가 계산하지 않는다. 규칙이 두 곳에 있으면 반드시 어긋난다.

**2. 파생값은 저장하지 않고 응답에서 계산한다.** `age`, `missingElements`, `phase`, `placed`, 보관함, 대표 발화.

**3. 서버 내부 설정은 내리지 않는다.** LLM·STT 입력(`element_criteria`, `remaining_worries`, `character_persona`, `scene_stance`, `proper_nouns`), 추적용 메타(`analysisVersion`, `modelId`, `droppedEvidence`), 멱등 키(`card_order_seed`, 거래의 `sessionId`/`sceneId`).

**4. 분기는 필드 null로 표현한다.** 응답 스키마를 유형별로 나누지 않는다 — `UtteranceResponse` 하나로 대화 계속·미션 노출·장면 종료·안전 개입을 모두 표현한다.

**5. 정답은 내리지 않는다.** 카드 정답 순서, 미션 모범 답안.

**6. 아이 발화 원문은 안전 응답에 담지 않는다.** `SafetyResponse.categories`는 범주만 담는다.

---

## 6. 미해결 항목

| # | 항목 | 현재 | 조치 |
| --- | --- | --- | --- |
| 1 | **`TokenResponse.refreshToken`이 항상 null** | 저장소(`refresh_tokens` 테이블·`RefreshToken` 엔티티)는 준비됐고 발급·회전·무효화 로직만 없다 | 그때까지 **Access 토큰 단일 전략으로 완결 동작한다**(→ §8). 도입해도 응답 스키마는 그대로라 클라이언트 변경이 없다 |
| 2 | **멀티파트 1MB 한도** | `application.yml`에 `spring.servlet.multipart` 설정 없음 → Boot 기본 1MB | 30초 WAV ≈ 960KB라 아슬아슬하다. 10MB로 올린다 |
| 3 | **STT 신뢰도 기준값** | 미정이라 `sttLowConfidence`가 항상 false | 기준값 확정 후 서버 판정 |
| 4 | **`SafetyResponse` 감지 로직** | 계약 자리만 확정. 항상 null | AI 파이프라인 연동 시 |
| 5 | **`CharacterEmotion` 고정 6종** | 응답 enum이 고정인데 DB는 CHECK를 풀었다 | 캐릭터별 `expression_keys`로 옮기면 문자열 키 + fallback으로 바꾼다 |
| 6 | **`DELETE /api/words/{wordId}`** | 경로에 `childId`가 없어 소유권 검증 경로가 애매 | 경로를 `/api/children/{childId}/words/{wordId}`로 맞추거나 조회로 역추적 |
| 7 | **`SynthesisRequest.characterName`이 이름 문자열** | `characters` 테이블이 생겼으니 키로 지정하는 편이 안전 | `characterKey` 또는 `sceneId`+`slot`으로 전환 검토 |

---

## 7. 구현 현황 요약

| 영역 | 엔드포인트 | ✅ | ⚠️ | ⛔ |
| --- | --- | --- | --- | --- |
| 인증 | 5 | 2 | 1 | 2 |
| 보호자 | 2 | 1 | 1 | 0 |
| 아이·동의 | 8 | 8 | 0 | 0 |
| 홈 | 1 | 1 | 0 | 0 |
| 콘텐츠 | 4 | 4 | 0 | 0 |
| 세션·장면 | 8 | 5 | 0 | 3 |
| 대화·미션 | 4 | 0 | 0 | 4 |
| 후속 활동 | 4 | 0 | 0 | 4 |
| 리포트 | 3 | 0 | 0 | 3 |
| 단어장 | 4 | 2 | 0 | 2 |
| 보상 | 11 | 0 | 0 | 11 |
| 음성 | 2 | 2 | 0 | 0 |
| **합계** | **56** | **25** | **2** | **29** |

⛔ 29건은 **DTO 계약이 확정된 상태**다. 프론트는 이 문서의 스키마대로 붙여 두면 서비스 구현 후 계약 변경 없이 동작한다.

---

## 8. Access 토큰 단일 전략 — 동작 확인

리프레시 토큰 없이도 인증이 완결되는지 실제로 앱을 띄워 확인했다(2026-08-10).

**구조상 결합이 없다** — `RefreshToken` 엔티티와 `RefreshTokenRepository`는 존재하지만 **어떤 서비스도 참조하지 않는다.** 인증 경로는 `JwtProvider`(발급·검증) → `JwtAuthFilter`(헤더 파싱) → `SecurityContext`로 끝난다. 리프레시 미구현이 다른 기능을 막지 않는다.

**검증한 흐름**

| 단계 | 결과 |
| --- | --- |
| 가입 → 토큰 발급 | 201, `accessTokenExpiresIn=604800`(7일), `refreshToken=null` |
| 로그인 → 토큰 발급 | 200 |
| 토큰으로 아이 생성 | 201 — 행성·지갑이 각 1건 자동 생성됨 |
| 토큰으로 동의 등록 → 세션 시작 → 장면 진행 | 201 / 201 / 200 |
| 토큰 없음 / 위조 / **만료** | 전부 **401** `UNAUTHORIZED` |
| 남의 아이 조회 | **403** `FORBIDDEN` |
| 만료 후 **재로그인** → 같은 세션 재조회 | 200 — **진행 상태가 그대로 이어진다** |

**결론: 리프레시 없이 운영 가능하다.** 서버가 무상태라 토큰만 새로 받으면 세션·진행 기록이 그대로 살아 있다. 사용자 입장의 유일한 비용은 7일마다 재로그인이다.

**단, 확인 과정에서 결함 하나를 고쳤다.** 스프링 시큐리티 기본값은 미인증·권한없음을 **모두 403 + 빈 본문**으로 돌려줘서, 만료된 토큰이 “권한 없음”으로 보였다. 재로그인이 유일한 복구 경로인 상황에서 클라이언트가 그 시점을 알아챌 방법이 없다는 뜻이다. `RestAuthenticationEntryPoint`(401)와 `RestAccessDeniedHandler`(403)를 붙여 갈랐다.

**리프레시를 넣게 되면** — `TokenResponse` 스키마는 그대로 두고 `accessOnly(...)` 대신 두 토큰을 채우면 된다. 응답 형태가 바뀌지 않으므로 클라이언트 변경이 필요 없다. 액세스 토큰 만료를 짧게(예: 30분) 줄이는 것이 함께 따라온다.






