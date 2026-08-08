# 이미지 에셋

여기에 넣은 파일은 `pubspec.yaml`의 `assets:`에 등록되어 있어 바로 쓸 수 있습니다.

```dart
Image.asset('assets/images/logo.png')
```

## 넣어야 할 파일

| 파일명 | 용도 | 권장 규격 |
|---|---|---|
| `logo.png` | 로고 전체 (Q마크 + 워드마크) | 가로 1024px, 배경 투명 |
| `logo_mark.png` | Q마크만 | 512×512, 배경 투명 |

> 앱 아이콘·스플래시는 이 폴더가 아니라 `android/app/src/main/res/`와
> `ios/Runner/Assets.xcassets/`에 들어갑니다.
> `flutter_launcher_icons` 패키지를 쓰면 `logo_mark.png` 하나로 양쪽을 한 번에 생성할 수 있습니다.

## 규칙

- 파일명은 `snake_case.png`
- 사진이 아닌 UI 요소는 가능하면 **SVG 대신 PNG @1x/@2x/@3x** 또는 아이콘 폰트 사용
- 브랜드 색은 이미지에 굽지 말고 `lib/core/theme/app_colors.dart`의 토큰을 쓰세요
