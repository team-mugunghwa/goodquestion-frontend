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
| `GET` | `/questions` | 질문 목록 (페이지네이션) | 🚧 협의 중 |
| `GET` | `/questions/{id}` | 질문 상세 | 🚧 협의 중 |
| `POST` | `/questions` | 질문 생성 | 🚧 협의 중 |

상태: 🚧 협의 중 · ⏳ 백엔드 구현 중 · ✅ 사용 가능

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
