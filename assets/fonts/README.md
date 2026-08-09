# 폰트

이 폴더에 폰트 파일을 넣고 `pubspec.yaml` 에 등록해야 디자인대로 보입니다.
**폰트 파일이 없어도 앱은 그냥 돕니다** — Flutter 가 시스템 기본 글꼴로 조용히
대체합니다. 그래서 "왜 시안이랑 다르지?" 의 첫 번째 원인이 대개 이겁니다.

폰트를 왜 이 두 개로 골랐는지는 [`docs/DESIGN_SYSTEM.md`](../../docs/DESIGN_SYSTEM.md) 참고.

---

## 1. 받을 파일

### Pretendard — 본문·보호자 화면

- 받는 곳: https://github.com/orioncactus/pretendard/releases (`Pretendard-x.x.x.zip` → `public/static/`)
- 라이선스: **SIL Open Font License 1.1** — 상업적 이용·임베딩·재배포 허용
- 넣을 파일 4개 (`.otf` 말고 **`.ttf`** 를 쓰세요. 용량이 작고 Flutter 웹에서 안전합니다)

```
Pretendard-Regular.ttf     (400)
Pretendard-Medium.ttf      (500)
Pretendard-SemiBold.ttf    (600)
Pretendard-Bold.ttf        (700)
```

### 나눔스퀘어라운드 — 아이 화면 제목·버튼

- 받는 곳: https://hangeul.naver.com/font (나눔스퀘어라운드)
- 라이선스: **네이버 나눔글꼴 라이선스** — 무료, 상업적 이용·임베딩·재배포 허용.
  ⚠️ **폰트 자체를 유료로 판매하는 것만 금지**입니다. 앱에 넣는 건 허용됩니다.
  배포 전에 라이선스 원문을 한 번 읽고, 아래 3번대로 출처를 기록하세요.
- 넣을 파일 3개

```
NanumSquareRoundR.ttf      (400)
NanumSquareRoundB.ttf      (700)
NanumSquareRoundEB.ttf     (800)
```

> **대안**: 라이선스 검토가 부담되면 Google Fonts 의 **Jua**(주아체, OFL, 400 한 종)로
> 바꿔도 됩니다. 굵기가 하나뿐이라 위계는 크기로만 잡아야 합니다.
> 바꾼다면 `AppFonts.display` 한 줄만 고치면 됩니다.

---

## 2. `pubspec.yaml` 에 등록

파일을 넣은 뒤 `flutter:` 아래에 붙이고 `flutter pub get` 을 돌립니다.
**파일이 없는데 아래를 먼저 쓰면 빌드가 실패합니다.** 순서를 지키세요.

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/

  fonts:
    - family: Pretendard
      fonts:
        - asset: assets/fonts/Pretendard-Regular.ttf
          weight: 400
        - asset: assets/fonts/Pretendard-Medium.ttf
          weight: 500
        - asset: assets/fonts/Pretendard-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Pretendard-Bold.ttf
          weight: 700

    - family: NanumSquareRound
      fonts:
        - asset: assets/fonts/NanumSquareRoundR.ttf
          weight: 400
        - asset: assets/fonts/NanumSquareRoundB.ttf
          weight: 700
        - asset: assets/fonts/NanumSquareRoundEB.ttf
          weight: 800
```

`family` 이름은 `lib/core/theme/app_typography.dart` 의 `AppFonts` 와
**한 글자도 다르면 안 됩니다.** 오타가 나면 에러 없이 기본 글꼴로 나옵니다.

---

## 3. 라이선스 기록 (배포 전 필수)

폰트 파일과 함께 받은 `LICENSE` / `OFL.txt` 를 이 폴더에 같이 커밋하고,
앱의 **설정 → 오픈소스 라이선스** 화면에 표시합니다. Flutter 는
`showLicensePage()` 를 기본 제공하지만 에셋 폰트는 자동으로 잡히지 않으므로,
`main.dart` 에서 한 번 등록해 주세요.

```dart
LicenseRegistry.addLicense(() async* {
  yield LicenseEntryWithLineBreaks(
    const ['Pretendard'],
    await rootBundle.loadString('assets/fonts/Pretendard-OFL.txt'),
  );
  yield LicenseEntryWithLineBreaks(
    const ['NanumSquareRound'],
    await rootBundle.loadString('assets/fonts/NanumSquareRound-LICENSE.txt'),
  );
});
```

Kenney 3D 에셋(내 행성)과 효과음도 같은 규칙입니다 — 출처와 라이선스를
`assets/models/README.md` · `assets/sounds/README.md` 에 남깁니다. (PRD F-08)

---

## 4. 폰트 용량 주의

한글 폰트는 파일 하나에 4~8MB 입니다. 7개면 앱 용량이 30MB 넘게 늘어납니다.
굵기를 더 늘리고 싶으면 **먼저 기존 굵기로 표현이 안 되는지** 확인하세요.
필요해지면 `fonttools` 로 한글 상용 2,780자만 남기는 서브셋을 검토합니다.
