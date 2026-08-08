# GoodQuestion — Frontend

Flutter로 만드는 GoodQuestion 앱. **태블릿/iPad 우선**, Android + iOS 지원.

| | |
|---|---|
| 프레임워크 | Flutter **3.44.9** (stable) / Dart 3.12.2 |
| 아키텍처 | MVVM + 클린 아키텍처 (feature-first) |
| 상태관리 | provider (`ChangeNotifier`) |
| DI | get_it (Repository·UseCase) + provider (ViewModel) |
| 네트워크 | dio |
| 백엔드 | Spring Boot + Spring Data JPA (별도 저장소) |

---

## 빠르게 시작하기

```bash
git clone https://github.com/team-mugunghwa/goodquestion-frontend.git
cd goodquestion-frontend
flutter pub get
flutter run
```

**백엔드 없이도 바로 실행됩니다.** `lib/core/di/injector.dart`의 `_useMockRepository`가
`true`라서 목업 데이터로 화면이 뜹니다. 서버가 준비되면 이 값을 `false`로 바꾸면 됩니다.

Flutter 설치부터 필요하면 → **[docs/SETUP.md](docs/SETUP.md)**

---

## 문서

| 문서 | 언제 보나 |
|---|---|
| [SETUP.md](docs/SETUP.md) | 처음 세팅할 때, 빌드가 안 될 때 |
| [CONVENTIONS.md](docs/CONVENTIONS.md) | 브랜치·커밋·PR 규칙. **작업 시작 전 필독** |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | 새 기능을 어디에 어떻게 만들지 |
| [API.md](docs/API.md) | 서버와 주고받는 형식 |
| [DECISIONS.md](docs/DECISIONS.md) | "이거 왜 이렇게 돼 있어요?" |

---

## 프로젝트 구조

```
lib/
├── app.dart              # MaterialApp
├── main.dart             # 진입점 (DI 초기화)
├── core/                 # 공통 — network, error, theme, di, widgets
└── features/
    └── question/         # 기능 단위. 그 안에서 data / domain / presentation
```

의존성 방향은 **한쪽으로만** 흐릅니다.

```
presentation ──▶ domain ◀── data
```

`domain`은 Flutter도 Dio도 JSON도 모릅니다. 자세한 건 [ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 자주 쓰는 명령

```bash
flutter pub get                                        # 패키지 설치
flutter run                                            # 실행
flutter run -d chrome                                  # Android SDK 없이 화면만 보기
flutter run --dart-define=API_BASE_URL=<주소>          # 다른 서버 보기

dart run build_runner build                            # DTO 코드 생성

dart format .                                          # 포맷
flutter analyze                                        # 정적 분석
flutter test                                           # 테스트
```

**push 전에** 아래를 통과시키세요. CI가 같은 걸 검사합니다.

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

---

## 작업 흐름

`main`에 **직접 push할 수 있습니다.** 브랜치 보호를 걸지 않았으니 CI는 각자 지킵니다.

1. 이슈 생성 → 담당자 지정
2. `feat/#12-question-list` 형태로 브랜치 생성 (작은 변경은 생략 가능)
3. 작업 → 커밋 (`feat(question): 질문 목록 화면 추가`)
4. **로컬 검증 통과** 후 push
5. **Actions 탭에서 초록불 확인.** 빨간 X면 그 자리에서 고치기

`lib/core/`·`pubspec.yaml` 같은 공용 파일이나 구조 변경은 PR로 올려 리뷰받기를 권합니다.
자세한 규칙은 [CONVENTIONS.md](docs/CONVENTIONS.md).

> iOS 빌드 CI는 macOS 러너가 무료 분량을 10배로 쓰기 때문에 **평소에는 돌지 않습니다.**
> Actions 탭 → CI → **Run workflow**로 수동 실행하거나, 매주 일요일 자동 검증됩니다.

---

## 팀

[@0804sally](https://github.com/0804sally) · [@leeseowoo](https://github.com/leeseowoo) · [@frihett](https://github.com/frihett) · [@hyunwoo1229](https://github.com/hyunwoo1229)
