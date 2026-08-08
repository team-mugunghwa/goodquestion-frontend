# 이미지 에셋

여기 파일은 `pubspec.yaml`의 `assets:`에 등록되어 있습니다.

**코드에서 경로 문자열을 직접 쓰지 마세요.** `lib/core/constants/app_assets.dart`의 상수를 씁니다.

```dart
Image.asset(AppAssets.logo)        // ✅
Image.asset('assets/images/logo.png')  // ❌ 오타를 런타임에야 발견함
```

로고는 `lib/core/widgets/app_logo.dart`의 `AppLogo` / `AppLogoMark` 위젯으로 감싸져 있습니다.

## 현재 파일

| 파일 | 크기 | 내용 |
|---|---|---|
| `logo.png` | 1024×366 | 로고 전체 (Q마크 + "Good Question" 워드마크), 배경 투명 |
| `logo_mark.png` | 512×512 | Q마크만, 중앙 정렬, 배경 투명 |

원본은 디자이너가 준 `굿퀘스천_로고.webp`(1024×366)이고, 위 두 파일은 거기서 뽑았습니다.

## 로고를 교체할 때

1. `logo.png`를 새 파일로 덮어쓰기
2. `logo_mark.png` — Q마크 영역만 잘라 512×512 투명 캔버스 중앙에 배치
3. `../icons/app_icon_foreground.png` — 같은 마크를 **더 작게**(높이 290/512) 배치.
   Android 어댑티브 아이콘은 런처가 모양을 정해서 가장자리가 잘리기 때문입니다.
4. 앱 아이콘 재생성:
   ```bash
   dart run flutter_launcher_icons
   ```

## 규칙

- 파일명은 `snake_case.png` (한글 파일명 금지 — 빌드 도구가 못 읽습니다)
- 브랜드 색은 이미지에 굽지 말고 `lib/core/theme/app_colors.dart`의 토큰 사용
- 큰 이미지는 넣기 전에 압축. `pubspec.yaml`에 등록된 에셋은 전부 앱 용량에 포함됩니다
