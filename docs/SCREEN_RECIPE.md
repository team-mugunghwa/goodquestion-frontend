# 화면 하나 만드는 절차

12개 화면을 4명이 나눠 만듭니다. **매번 다시 고민하지 않기 위한 체크리스트**입니다.
[홈(`/`)이 참조 구현](../lib/features/home/)이니, 막히면 거기를 열어 그대로 따라 하세요.

- 레이어 규칙 → [ARCHITECTURE.md](ARCHITECTURE.md)
- 색·크기·문구 규칙 → [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)
- 이 문서는 **그 둘을 화면 작업 순서로 눌러 놓은 것**입니다

---

## 0. 시작 전 30초

1. 이 화면은 **아이 화면인가 보호자 화면인가.** 바탕이 `day` / `night` / `guardian` 중 무엇인가
   - 아이 화면이면 `AppCanvas` + `ScreenMetrics` + `AppTypography.kid*`
   - 보호자 화면이면 `GuardianScaffold` + `Theme.of(context).textTheme`. 훨씬 빨리 끝납니다
2. 이 화면이 하는 **한 가지 일**은 무엇인가 (→ [DESIGN_SYSTEM.md 13장](DESIGN_SYSTEM.md#13-화면-12개-지도)의 표에 이미 적혀 있습니다)
3. 서버 응답을 어떤 모양으로 받을 건가 (→ 1번에서 더미로 씁니다)

---

## 1. 만드는 파일 (순서대로)

`<feature>` = `story` · `word` · `planet` · `play` · `mypage` · `auth`

```
assets/dummy/<screen>.json                       # 서버 응답 data 와 1:1
lib/features/<feature>/
├── domain/
│   ├── entities/<name>.dart                     # 순수 Dart. fromJson 금지
│   ├── repositories/<name>_repository.dart      # abstract
│   └── usecases/get_<name>_use_case.dart        # call() 하나
├── data/
│   ├── dtos/<name>_dto.dart                     # fromJson + toEntity
│   ├── datasources/<name>_local_data_source.dart
│   └── repositories/<name>_repository_mock.dart
└── presentation/
    ├── viewmodels/<name>_view_model.dart        # BaseViewModel 상속
    ├── views/<name>_view.dart                   # Page(Provider) + View(본체)
    └── widgets/                                 # 섹션별로 쪼갬
lib/core/di/injector.dart                        # 3줄 등록
test/features/<feature>/...                      # 아래 4장
```

**DTO 는 `fromJson` 을 손으로 씁니다.** `json_serializable` 을 쓰면 화면마다
`build_runner` 2분을 기다리게 됩니다. 이미 코드 생성을 쓰는 `question` 만 그대로 둡니다.

---

## 2. 이미 있는 것 — 다시 만들지 마세요

| 필요한 것 | 쓰세요 |
|---|---|
| 화면 바탕 | `AppCanvas.day / .night / .guardian` |
| 폭에 따른 여백·글자 | `ScreenMetrics.of(constraints.maxWidth)` |
| 누르는 카드·타일 | `PressScale` (포커스 링·시맨틱스 포함) |
| 아이 화면 주 버튼 | `KidPrimaryButton` (88 · pill · 아이콘+한 단어) |
| 아이 화면 뒤로가기 | `KidBackButton` |
| 이야기 카드 | `StoryCard` (홈 추천 · 목록 그리드 공용) |
| 정보 칩 (시간·주제·난이도) | `KidInfoChip` |
| 필터 칩 바 (단일 선택) | `KidFilterChips` + `KidFilterChipData` |
| 소리 듣기 | `SpeakerButton` (지금은 재생 상태만 시뮬레이션) |
| 별가루 잔액 | `StardustChip.day / .night` |
| 하단 내비 | `AppBottomNav(current: AppNavTab.xxx)` |
| 아이 화면 에러 | `AppKidErrorView` |
| 아이 화면 빈 상태 | `AppKidEmptyView` (**나가는 문을 반드시 함께**) |
| 보호자 화면 뼈대 | `GuardianScaffold` (헤더 + 720dp 본문 + 선택적 내비) |
| 보호자 그룹 목록·행·토글 | `GuardianSection` / `GuardianTile` / `GuardianSwitchTile` |
| 보호자 화면 로딩·에러·빈 상태 | `AppLoadingView` / `AppErrorView` / `AppEmptyView` |
| 로딩 스켈레톤 | `SkeletonBox` · `SkeletonCardList` |
| 이미지 자리 | `StoryThumbnail` (이미지 없으면 그라디언트) |

없는 게 필요하면 **화면 안에 숨기지 말고** `core/widgets/` 로 빼고
[DESIGN_SYSTEM.md 10장](DESIGN_SYSTEM.md#10-컴포넌트-규칙) 표에 한 줄 추가하세요.

---

## 3. 화면 코드에서 지킬 것

- 색·크기·시간은 `AppColors` / `AppSpacing`·`AppRadius`·`AppSizes` / `AppDurations`·`AppCurves`
- **문구는 `core/constants/app_strings.dart`** 에 화면별 클래스로. 위젯에 한글 리터럴 금지
- 아이콘은 `AppIcons`. `Icons.xxx` 직접 사용 금지
- 파스텔(`brandBlue/Green/Mint`)을 글자색으로 쓰지 않기. 글자는 `*Deep` 또는 `ink*`
- 아이 화면에 `danger`(빨강) 금지. 노랑은 별가루에만
- **폭이 넓으면 늘리지 말고 레이아웃을 바꾸기** (`isWide ? Row : Column`)
- 반경은 한 화면에 두 종류까지 (보통 `xl` 카드 + `pill` 칩·버튼)

### 자주 밟는 지뢰

- **`AnimatedSwitcher` 는 자식을 가운데에 느슨하게 놓습니다.** 스크롤 본문을 넣으면
  세로로 붕 뜹니다. `layoutBuilder` 로 `StackFit.expand` 를 주세요 (홈 참고)
- 고정 높이 안에 글자를 넣으면 **기기 글자 확대 설정에서 넘칩니다.**
  `ConstrainedBox(minHeight:)` 로 늘어날 수 있게 두세요
- 무한 반복 애니메이션(스켈레톤)이 화면에 남아 있으면 `pumpAndSettle` 이 타임아웃됩니다.
  에러·성공 상태에서는 스켈레톤을 반드시 걷어내세요
- **`Future.delayed` 대신 `Timer` 를 쓰고 `dispose` 에서 끄세요.** 안 그러면 화면을
  나간 뒤에 `setState` 가 불리고, 위젯 테스트는 "A Timer is still pending" 으로 죽습니다
- **목록 → 상세는 `context.go` 가 아니라 `context.push`.** `go` 는 스택을 갈아엎어서
  돌아왔을 때 필터·스크롤이 초기화되고, 상세의 뒤로가기가 갈 곳을 잃습니다
- **`ListTile` 계열을 `AppCanvas` 안에서 쓰지 마세요.** 캔버스가 배경을 칠하고
  있어서 "잉크 효과가 가려진다"는 프레임워크 단언이 뜹니다. `Row + Checkbox` 로 짜세요
- 라우터 테스트처럼 **여러 테스트가 같은 더미를 읽으면** `setUp(rootBundle.clear)`
  를 넣으세요. `rootBundle` 은 Future 를 캐시하는데 그게 앞 테스트의 async 존에
  묶여 있어서, 다음 테스트의 화면이 로딩 스피너에서 안 빠져나옵니다

---

## 4. 테스트 — 화면당 3개면 충분합니다

1. **더미 파싱** — `assets/dummy/<screen>.json` 이 Entity 로 올라오는가
   (더미는 컴파일러가 안 봅니다. 오타를 여기서 잡습니다)
2. **ViewModel** — `loading → success` / `loading → error` 전이
3. **View** — 주요 분기가 실제로 갈리는가 (있음/없음, 태블릿/폰 폭)

`test/features/home/` 을 복사해서 이름만 바꾸는 게 가장 빠릅니다.

---

## 5. 올리기 전

```bash
dart format . && flutter analyze && flutter test
```

문서도 같은 커밋에서 갱신합니다 ([CONVENTIONS.md 7장](CONVENTIONS.md#7-문서-갱신-의무)).
화면 작업에서 대개 걸리는 건 **[API.md](API.md) 엔드포인트 표 한 개**뿐입니다.
토큰이나 공용 위젯을 추가했다면 [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) 도.

---

## 6. 미리보기 (개발 중)

`flutter run -d chrome` 을 **한 번 띄워 놓고 계속 켜 둡니다.** 코드를 고칠 때마다
`r`(핫리로드), 레이아웃이 꼬이면 `R`(재시작). 브라우저 창 폭을 줄였다 늘리면
태블릿/폰 레이아웃을 즉시 비교할 수 있습니다. → [DECISIONS.md](DECISIONS.md) 011

**새 더미 JSON 을 추가했으면 프로세스를 껐다 켜야 합니다** — 에셋 목록은 실행 시점에
번들되므로 핫리스타트로는 안 잡힙니다.

> 최종 확인은 실기기/에뮬레이터에서. web 에서 잘 보인다고 태블릿에서 같지 않습니다.
