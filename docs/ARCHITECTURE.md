# 아키텍처

**MVVM + 클린 아키텍처**, 상태관리는 **Provider**.

이 문서의 목적은 하나입니다: **"새 기능을 추가할 때 어떤 파일을 어디에 만드는가"** 를 4명이 똑같이 답할 수 있게 하는 것.

---

## 1. 레이어

```
┌─────────────────────────────────────────────┐
│ presentation   View · ViewModel             │  화면과 상태
├─────────────────────────────────────────────┤
│ domain         Entity · Repository(추상)     │  순수 비즈니스 규칙
│                · UseCase                     │  Flutter를 몰라야 함
├─────────────────────────────────────────────┤
│ data           DTO · DataSource              │  서버·로컬 통신
│                · RepositoryImpl              │
└─────────────────────────────────────────────┘
```

### 의존성 규칙 (이것만 지키면 절반은 성공)

**바깥 레이어는 안쪽을 알아도 되지만, 안쪽은 바깥을 몰라야 합니다.**

```
presentation ──▶ domain ◀── data
```

- `domain`은 `presentation`도 `data`도 **import 하지 않습니다.**
- `domain`은 `package:flutter/...`, `package:dio/...` 를 **import 하지 않습니다.**
- `data`가 `domain`의 추상 Repository를 **구현**하고, DI가 둘을 연결합니다.

이게 성립하면 서버가 안 만들어졌을 때 `RepositoryImpl` 대신 `MockRepository`를 꽂아 화면을 먼저 개발할 수 있습니다. **클린 아키텍처를 쓰는 실질적인 이유가 이겁니다.**

---

## 2. 폴더 구조 (feature-first)

레이어를 최상위에 두면(`data/`, `domain/`, `presentation/`) 기능 하나 작업할 때 폴더 3군데를 왔다갔다 해야 합니다. **기능 단위로 먼저 나누고 그 안에서 레이어를 나눕니다.** 팀 작업에서 충돌도 적습니다.

```
lib/
├── main.dart
├── app.dart                         # MaterialApp, 전역 Provider 등록
│
├── core/                            # 기능에 종속되지 않는 공통 코드
│   ├── config/
│   │   └── app_config.dart          # API 주소 등 빌드 시점 설정
│   ├── constants/
│   │   └── app_breakpoints.dart     # 반응형 브레이크포인트
│   ├── di/
│   │   └── injector.dart            # get_it 등록 한 곳에 모음
│   ├── error/
│   │   ├── exceptions.dart          # data 레이어가 던지는 예외
│   │   └── failure.dart             # domain이 다루는 실패 타입
│   ├── network/
│   │   ├── api_response.dart        # 서버 공통 응답 봉투 파싱
│   │   └── dio_client.dart          # Dio 인스턴스 + 인터셉터
│   ├── presentation/
│   │   └── base_view_model.dart     # 모든 ViewModel의 부모
│   ├── state/
│   │   └── view_state.dart          # idle / loading / success / error
│   ├── theme/                       # 색·간격 토큰
│   └── widgets/                     # 여러 feature가 쓰는 공용 위젯
│       ├── app_state_views.dart     # 로딩·에러·빈 화면
│       └── responsive_layout.dart
│
└── features/
    └── question/
        ├── data/
        │   ├── datasources/
        │   │   └── question_remote_data_source.dart
        │   ├── dtos/
        │   │   └── question_dto.dart          # fromJson / toEntity
        │   └── repositories/
        │       ├── question_repository_impl.dart  # 실제 서버
        │       └── question_repository_mock.dart  # 서버 없이 개발용
        ├── domain/
        │   ├── entities/
        │   │   └── question.dart              # 순수 Dart
        │   ├── repositories/
        │   │   └── question_repository.dart   # abstract
        │   └── usecases/
        │       └── get_questions_use_case.dart
        └── presentation/
            ├── viewmodels/
            │   └── question_list_view_model.dart
            ├── views/
            │   ├── question_detail_panel.dart
            │   └── question_list_view.dart
            └── widgets/
                └── question_card.dart
```

---

## 3. 데이터 흐름

```
[사용자 탭]
     │
     ▼
View ──(메서드 호출)──▶ ViewModel
                          │
                          ▼
                       UseCase
                          │
                          ▼
                  Repository(추상)
                          │
                          ▼
                  RepositoryImpl ──▶ RemoteDataSource ──▶ Dio ──▶ 서버
                          │                                        │
                          │◀────── DTO ◀───────────────── JSON ◀───┘
                          │
                    DTO.toEntity()
                          │
                          ▼
                       Entity
                          │
                          ▼
ViewModel  state = success(entities)
     │
  notifyListeners()
     │
     ▼
View 리빌드
```

---

## 4. 각 레이어의 책임과 금지사항

### presentation / View

**한다**: 화면 그리기, 사용자 입력을 ViewModel에 전달
**안 한다**: 비즈니스 로직, Repository·UseCase 직접 호출, HTTP 호출

```dart
// ✅ 좋음
context.read<QuestionListViewModel>().load();

// ❌ 나쁨 — View가 data 레이어를 앎
final questions = await getIt<QuestionRepository>().getQuestions();
```

**상태 구독은 `watch`, 이벤트 호출은 `read`.**
`build()` 안에서 `read`로 상태를 읽으면 리빌드가 안 됩니다. 반대로 콜백에서 `watch`를 쓰면 에러가 납니다.

```dart
@override
Widget build(BuildContext context) {
  final vm = context.watch<QuestionListViewModel>();   // 상태 구독
  return ElevatedButton(
    onPressed: () => context.read<QuestionListViewModel>().refresh(),  // 이벤트
    child: Text(vm.questions.length.toString()),
  );
}
```

### presentation / ViewModel

**한다**: 화면 상태 보유(`ViewState`, 데이터, 에러 메시지), UseCase 호출, `notifyListeners()`
**안 한다**:

- ❌ **`BuildContext`를 필드로 갖지 않기.** ViewModel이 화면 생명주기에 묶여 테스트가 불가능해집니다. `Navigator`·`SnackBar`가 필요하면 ViewModel은 상태만 바꾸고 View가 반응하게 하세요.
- ❌ `package:flutter/material.dart` import 하지 않기 (`foundation.dart`의 `ChangeNotifier`만)
- ❌ DTO나 `Response` 객체를 그대로 들고 있지 않기 (Entity만)

### domain

**한다**: 앱의 규칙. Entity, 추상 Repository, UseCase
**안 한다**: `fromJson` / `toJson` (❌ 이게 생기면 클린 아키텍처의 의미가 사라짐), Flutter·Dio import

UseCase는 **하나의 동작 = 하나의 클래스**, 진입점은 `call()` 하나입니다.

```dart
class GetQuestionsUseCase {
  const GetQuestionsUseCase(this._repository);
  final QuestionRepository _repository;

  Future<List<Question>> call({int page = 1}) => _repository.getQuestions(page: page);
}
```

> UseCase가 Repository 메서드를 단순 통과만 시키는 경우가 많습니다. 그래도 둡니다 —
> 나중에 캐싱·권한 체크·여러 Repository 조합이 들어갈 자리이고, 자리가 정해져 있어야 4명이 같은 곳에 넣습니다.

### data

**한다**: HTTP 호출, JSON ↔ DTO 변환, DTO → Entity 변환, 예외를 `Failure`로 번역
**안 한다**: Entity에 `fromJson` 달기, UI 문구 만들기

**DTO와 Entity를 분리하는 이유**: 서버 응답 필드명이 바뀌어도 `toEntity()` 한 곳만 고치면 됩니다. 화면 코드는 안 건드립니다.

---

## 5. 상태 표현 (전 화면 통일)

`core/` 에 정의된 `ViewState`를 **모든 ViewModel이 씁니다.** 화면마다 `isLoading`, `loading`, `busy` 제각각 만들지 않습니다.

```dart
enum ViewState { idle, loading, success, error }
```

View는 이 하나의 패턴으로 분기합니다.

```dart
switch (vm.state) {
  ViewState.loading => const Center(child: CircularProgressIndicator()),
  ViewState.error   => ErrorView(message: vm.errorMessage, onRetry: vm.load),
  _                 => QuestionListBody(questions: vm.questions),
}
```

---

## 6. 의존성 주입 (DI)

**두 가지를 역할로 나눠 씁니다.** 헷갈리면 이 표만 보세요.

| 도구 | 담당 | 이유 |
|---|---|---|
| **get_it** | Repository, UseCase, DataSource, DioClient | 위젯 트리와 무관한 순수 객체. `BuildContext` 없이 꺼내야 함 |
| **provider** | ViewModel | 위젯 트리에 붙어 생명주기를 따라가고, 화면이 사라지면 `dispose` 돼야 함 |

등록은 **`core/di/injector.dart` 한 곳에서만** 합니다. (자주 충돌나는 파일 — [CONVENTIONS.md](CONVENTIONS.md#6-충돌이-자주-나는-파일) 참고)

```dart
// 화면 단위 ViewModel — 화면 진입 시 생성, 나가면 dispose
ChangeNotifierProvider(
  create: (_) => QuestionListViewModel(getIt<GetQuestionsUseCase>())..load(),
  child: const QuestionListView(),
)
```

전역으로 살아야 하는 것(로그인 상태 등)만 `app.dart`의 `MultiProvider`에 올립니다. **습관적으로 전역에 올리지 마세요.** 메모리에 계속 남고 상태가 화면 간에 새어 나갑니다.

---

## 7. 반응형 — 태블릿/iPad 우선

이 앱은 **태블릿이 1순위**입니다. 폰에서만 확인하고 PR 올리면 안 됩니다.

### 브레이크포인트

| 이름 | 너비 | 대상 |
|---|---|---|
| `compact` | < 600 | 폰 |
| `medium` | 600 – 839 | 작은 태블릿, 폴더블, 폰 가로 |
| `expanded` | ≥ 840 | **iPad·태블릿 (주 타겟)** |

### 규칙

1. **`MediaQuery.of(context).size`로 분기하지 마세요.** 화면 전체 크기라서 분할 화면(Split View)이나 중첩 레이아웃에서 틀립니다. `LayoutBuilder`의 `constraints.maxWidth` 를 쓰세요.
2. 폭이 넓으면 늘리지 말고 **레이아웃을 바꿉니다.** 리스트를 가로로 늘리는 대신 `expanded`에서는 **목록 + 상세 2단**으로.
3. 콘텐츠 최대 폭을 제한하세요. 한 줄이 너무 길면 읽기 힘듭니다 (`maxWidth: 720` 정도).
4. 고정 픽셀 대신 `Expanded` / `Flexible` / `AspectRatio`.
5. iPad는 **가로 방향이 기본**입니다. 세로 전제로 짜지 마세요.
6. `SafeArea` 필수 (노치·홈 인디케이터).

```dart
LayoutBuilder(
  builder: (context, constraints) => constraints.maxWidth >= 840
      ? const QuestionSplitView()   // 목록 + 상세
      : const QuestionListView(),   // 목록만
)
```

### PR 전 확인

**폰 1개 + 태블릿/iPad 1개**에서 확인하고, 태블릿 스크린샷을 PR에 첨부합니다.

---

## 8. 새 기능 추가 레시피

`bookmark` 기능을 추가한다고 할 때, **아래 순서 그대로** 만듭니다.

```
1. domain/entities/bookmark.dart                  # 순수 데이터 모양 정의
2. domain/repositories/bookmark_repository.dart   # abstract — 무엇이 필요한지 선언
3. domain/usecases/get_bookmarks_use_case.dart    # 동작 하나
4. data/dtos/bookmark_dto.dart                    # 서버 JSON 모양 + toEntity()
5. data/datasources/bookmark_remote_data_source.dart
6. data/repositories/bookmark_repository_impl.dart
7. presentation/viewmodels/bookmark_list_view_model.dart
8. presentation/views/bookmark_list_view.dart
9. core/di/injector.dart 에 등록
10. docs/API.md 에 사용한 엔드포인트 기록
```

> **서버가 아직 없다면** 1~3번까지 만들고, 6번 대신 `BookmarkRepositoryMock`을 만들어 7~8번을 먼저 진행하세요.
> 서버가 나오면 DI 등록 한 줄만 바꾸면 됩니다. 화면 코드는 손대지 않습니다.

---

## 9. 테스트

전부 테스트할 필요는 없습니다. **우선순위대로**:

1. **UseCase / RepositoryImpl** — 순수 Dart라 테스트가 가장 쉽고 값어치가 큼
2. **ViewModel** — mock Repository를 주입해 상태 전이 검증 (loading → success/error)
3. Widget 테스트 — 핵심 화면만

```
test/
└── features/question/
    ├── domain/usecases/get_questions_use_case_test.dart
    └── presentation/viewmodels/question_list_view_model_test.dart
```

mock은 `mocktail`을 씁니다 (코드 생성이 필요 없음).
