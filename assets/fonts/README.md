# 폰트

**현재 상태: 파일이 들어 있고 `pubspec.yaml` 에 등록돼 있습니다** (2026-08-19).
아래는 폰트를 갈아 끼우거나 굵기를 더할 때 다시 따라가는 절차입니다.

| 패밀리 | 파일 | 굵기 | 라이선스 |
|---|---|---|---|
| Pretendard | `Pretendard-{Regular,Medium,SemiBold,Bold}.otf` | 400/500/600/700 | `Pretendard-OFL.txt` |
| NanumSquareRound | `NanumSquareRound{R,B,EB}.ttf` | 400/700/800 | `NanumSquareRound-OFL.txt` |

왜 번들하나: 등록하지 않으면 Flutter 가 시스템 기본 글꼴로 조용히 대체하고,
**웹에서는 구글 폰트 서버에서 한글 폴백을 받아올 때까지 글자가 네모(□)로
보입니다** (첫 로드·느린 망·차단된 망). 파일을 넣어 두면 그 구간이 사라집니다.

폰트를 왜 이 두 개로 골랐는지는 [`docs/DESIGN_SYSTEM.md`](../../docs/DESIGN_SYSTEM.md) 참고.

---

## 1. 받을 파일

### Pretendard — 본문·보호자 화면

- 받는 곳: https://github.com/orioncactus/pretendard/releases (`Pretendard-x.x.x.zip` → `public/static/`)
- 라이선스: **SIL Open Font License 1.1** — 상업적 이용·임베딩·재배포 허용
- 넣을 파일 4개. 공식 배포 zip 에는 `.otf`(CFF) 만 들어 있고 Flutter(Skia)는
  이를 그대로 읽습니다. 하나에 약 1.5MB 로 `.ttf` 변환본보다 오히려 작습니다.

```
public/static/Pretendard-Regular.otf     (400)
public/static/Pretendard-Medium.otf      (500)
public/static/Pretendard-SemiBold.otf    (600)
public/static/Pretendard-Bold.otf        (700)
```

### 나눔스퀘어라운드 — 아이 화면 제목·버튼

- 받는 곳: https://hangeul.naver.com/font (나눔스퀘어라운드)
- 라이선스: **SIL Open Font License 1.1** (네이버 공식 안내: Copyright 2010 NAVER
  Corporation, Reserved Font Name 에 NanumSquareRound 포함) — 무료, 상업적
  이용·임베딩·재배포 허용. 폰트 자체를 유료로 판매하는 것만 금지.
  원문: https://help.naver.com/service/30016/contents/18088
- 직접 받기: `https://hangeul.pstatic.net/hangeul_static/webfont/NanumSquareRound/NanumSquareRound{R,B,EB}.ttf`
  (네이버가 웹폰트로 서빙하는 TTF. 한글 11,172자 전부 들어 있음)
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
    - assets/fonts/Pretendard-OFL.txt          # 라이선스 화면에서 읽음
    - assets/fonts/NanumSquareRound-OFL.txt

  fonts:
    - family: Pretendard
      fonts:
        - asset: assets/fonts/Pretendard-Regular.otf
          weight: 400
        - asset: assets/fonts/Pretendard-Medium.otf
          weight: 500
        - asset: assets/fonts/Pretendard-SemiBold.otf
          weight: 600
        - asset: assets/fonts/Pretendard-Bold.otf
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

라이선스 원문(`Pretendard-OFL.txt`, `NanumSquareRound-OFL.txt`)을 이 폴더에
같이 커밋했고, `main.dart` 에서 `LicenseRegistry` 에 등록해 둡니다. Flutter 는
`showLicensePage()` 를 기본 제공하지만 에셋 폰트는 자동으로 잡히지 않기 때문입니다.
(설정 화면에 "오픈소스 라이선스" 항목이 생기면 `showLicensePage(context: context)`
한 줄이면 됩니다.)

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

지금 7개 파일 합계 약 9.4MB(Pretendard 1.5MB×4, 나눔 1.0MB×3)입니다.
웹은 첫 프레임 전에 등록된 폰트를 전부 내려받으므로 굵기를 늘리면 초기 로딩이 그만큼 느려집니다.
굵기를 더 늘리고 싶으면 **먼저 기존 굵기로 표현이 안 되는지** 확인하세요.
필요해지면 `fonttools` 로 한글 상용 2,780자만 남기는 서브셋을 검토합니다.
