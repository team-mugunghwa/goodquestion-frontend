# 협업 컨벤션

4명이 같은 코드베이스를 만지기 때문에, **규칙이 취향보다 우선**합니다.
애매하면 이 문서를 근거로 하고, 문서에 없으면 PR에서 논의 후 **문서를 갱신**합니다.

---

## 1. 브랜치 전략

```
main        ← 항상 실행 가능한 상태. 직접 push 금지
 └ feat/#12-question-list
 └ fix/#31-login-crash
```

팀 규모가 작아서 `develop` 없이 **main + 기능 브랜치**로 갑니다.

### 브랜치 이름

```
<타입>/#<이슈번호>-<영문-요약>
```

| 타입 | 용도 |
|---|---|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` | 동작 변경 없는 구조 개선 |
| `style` | UI/스타일만 |
| `chore` | 빌드, 설정, 패키지 |
| `docs` | 문서만 |

예시: `feat/#12-question-list`, `fix/#31-login-crash`

> 이슈 번호를 붙이는 이유: 3주 뒤에 "이 코드 왜 이래?" 할 때 브랜치 → 이슈 → 논의 기록으로 바로 추적됩니다.

---

## 2. 커밋 메시지

[Conventional Commits](https://www.conventionalcommits.org/ko/v1.0.0/) 를 씁니다.

```
<타입>(<범위>): <한글 요약>

<선택: 왜 이렇게 했는지>

Refs: #12
```

**예시**

```
feat(question): 질문 목록 화면 추가

Refs: #12
```

```
fix(auth): 토큰 만료 시 무한 로딩 되는 문제 수정

인터셉터에서 401을 잡고도 completer를 완료시키지 않아 발생.

Refs: #31
```

**규칙**

- 타입은 브랜치 타입과 동일한 목록 사용
- 범위(`<범위>`)는 feature 폴더 이름 (`question`, `auth`, `core` 등)
- 요약은 **한글**, 마침표 없이, 50자 이내
- **"수정", "작업중", "ㅇㅇ" 같은 커밋 금지.** 무엇을 왜 바꿨는지 쓰세요
- 커밋은 의미 단위로. 파일 저장할 때마다 커밋하지 않기

---

## 3. PR (Pull Request)

### 규칙

1. **`main`에 직접 push 금지** — 반드시 PR
2. **리뷰어 1명 이상 승인** 후 머지
3. **CI(format / analyze / test) 통과** 필수
4. PR은 작게. 변경 파일이 **20개를 넘으면 쪼개기**
5. 본인 PR은 본인이 머지 (머지 후 브랜치 삭제)

### 머지 방식

**Squash and merge**를 씁니다. main 히스토리가 PR 단위로 깔끔하게 남습니다.

### 리뷰 문화

- 리뷰는 **24시간 안에** 남기기. 못 하면 팀 채널에 알리기
- 코드에 대한 지적이지 사람에 대한 지적이 아닙니다
- 코멘트 앞에 의도를 붙이면 오해가 줄어듭니다:
  - `[필수]` — 고쳐야 머지 가능
  - `[제안]` — 이렇게 하면 더 좋을 듯 (반영은 선택)
  - `[질문]` — 이해가 안 돼서 물어봄
  - `[칭찬]` — 좋은 코드 발견

---

## 4. 이슈

- 작업은 **이슈부터** 만들고 시작합니다
- 라벨: `feat` / `fix` / `refactor` / `design` / `docs` / `question`
- 담당자(Assignee)를 반드시 지정
- GitHub Projects 보드로 `Todo → In Progress → In Review → Done` 관리

---

## 5. 코드 스타일

포맷은 **`dart format`이 정답**입니다. 논쟁하지 않습니다. 저장 시 자동 포맷을 켜두세요.

### 네이밍

| 대상 | 규칙 | 예시 |
|---|---|---|
| 파일 | `snake_case.dart` | `question_list_view.dart` |
| 클래스 / enum | `PascalCase` | `QuestionViewModel` |
| 변수 / 함수 | `lowerCamelCase` | `fetchQuestions()` |
| 상수 | `lowerCamelCase` | `defaultPageSize` |
| private | `_` 접두사 | `_repository` |

### 파일 접미사 (레이어가 이름에서 드러나게)

| 레이어 | 접미사 | 예시 |
|---|---|---|
| 화면 | `_view.dart` | `question_list_view.dart` |
| 위젯 | `_widget.dart` 또는 그냥 명사 | `question_card.dart` |
| ViewModel | `_view_model.dart` | `question_list_view_model.dart` |
| UseCase | `_use_case.dart` | `get_questions_use_case.dart` |
| Repository 인터페이스 | `_repository.dart` | `question_repository.dart` |
| Repository 구현 | `_repository_impl.dart` | `question_repository_impl.dart` |
| DataSource | `_data_source.dart` | `question_remote_data_source.dart` |
| DTO(서버 응답) | `_dto.dart` | `question_dto.dart` |
| Entity(도메인) | 그냥 명사 | `question.dart` |

### 하지 말아야 할 것

- `print()` — 대신 `debugPrint()` 또는 로거
- 하드코딩된 색상/사이즈 — `core/theme`의 토큰 사용
- 하드코딩된 문자열(사용자에게 보이는 것) — `core/constants` 또는 l10n
- `// TODO` 남긴 채 머지 — 남길 거면 이슈를 만들고 `// TODO(#42):` 형태로

---

## 6. 충돌이 자주 나는 파일

아래 파일은 여러 명이 동시에 건드리기 쉬워서, **수정 전에 팀 채널에 알립니다.**

- `pubspec.yaml` / `pubspec.lock` — 패키지 추가
- `lib/core/di/injector.dart` — DI 등록
- `lib/core/router/` — 라우트 등록
- `lib/core/theme/` — 디자인 토큰

충돌이 났을 때 `pubspec.lock`은 **손으로 고치지 말고** 삭제 후 `flutter pub get`으로 재생성하세요.

---

## 7. 문서 갱신 의무

아래를 바꿨다면 **같은 PR에서** 문서도 갱신합니다.

| 바꾼 것 | 갱신할 문서 |
|---|---|
| API 호출 추가/변경 | [`docs/API.md`](API.md) |
| 폴더 구조·레이어 규칙 변경 | [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) |
| 패키지 추가/제거, 기술 선택 | [`docs/DECISIONS.md`](DECISIONS.md) |
| 실행 절차·환경변수 변경 | [`docs/SETUP.md`](SETUP.md) |
