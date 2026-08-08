# 개발 환경 세팅

처음 클론했다면 이 문서만 따라 하면 앱이 실행됩니다. 막히면 [트러블슈팅](#트러블슈팅)을 먼저 보세요.

---

## 0. 버전 고정 (중요)

팀 전원이 **같은 버전**을 씁니다. 버전이 다르면 `pubspec.lock` 충돌과 "내 PC에선 되는데" 문제가 생깁니다.

| 항목 | 버전 |
|---|---|
| Flutter | **3.44.9 (stable)** |
| Dart | 3.12.2 (Flutter에 포함) |
| JDK | **21** (Android 빌드용) |
| Android compileSdk | 36 |
| iOS 최소 버전 | 13.0 |

버전 확인:

```bash
flutter --version
```

`3.44.9`가 아니면 아래로 맞춥니다.

```bash
flutter version 3.44.9     # 또는
flutter downgrade 3.44.9
```

---

## 1. Flutter SDK 설치

### Windows

1. https://docs.flutter.dev/get-started/install/windows 에서 **3.44.9 stable** zip 다운로드
2. **`C:\dev\flutter`** 에 압축 해제
3. 환경변수 PATH에 `C:\dev\flutter\bin` 추가
4. 새 터미널을 열고 `flutter --version` 확인

> ## ⚠️ 경로에 한글이 있으면 안 됩니다 (실제로 겪은 문제)
>
> **Windows 계정명이 한글이면 SDK도 프로젝트도 `C:\Users\<한글이름>\` 아래에 두지 마세요.**
> `C:\dev\` 같은 영문 경로를 쓰세요. 공백도 피하는 게 안전합니다.
>
> 흔히 "Gradle 빌드가 깨진다"고 알려져 있지만, **실제로는 그보다 훨씬 앞단에서 터집니다.**
> `flutter pub get` 까지는 멀쩡히 성공해서 처음엔 문제없어 보이는 게 함정입니다.
>
> ```
> $ flutter analyze
> Unhandled exception:
> FormatException: Unexpected end of input (at character 348)
> ...C/goodquestion-frontend/"}],"capabilities":{"window":{"workDoneProgress":tr
>                                                                               ^
> ```
>
> **원인**: `flutter analyze` 는 Dart 분석 서버와 LSP(JSON-RPC)로 통신하는데,
> 메시지 길이를 **바이트 수로 계산해 보내고 문자 수로 읽습니다.**
> 한글 3글자는 UTF-8로 9바이트라 6바이트가 어긋나고, JSON이 중간에 잘려 파싱이 터집니다.
> 위 로그에서 `C:/Users/최예슬/` 이 `...C/` 로 뭉개진 게 그 흔적입니다.
>
> **해결**: 프로젝트를 영문 경로로 옮기고 다시 클론하세요. 옮긴 뒤에는
> `flutter analyze` 가 남긴 dart 프로세스가 옛 폴더를 잡고 있을 수 있으니,
> 지워지지 않으면 작업 관리자에서 `dart.exe` 를 종료한 뒤 삭제하세요.

### macOS

```bash
# Apple Silicon은 Rosetta 필요
sudo softwareupdate --install-rosetta --agree-to-license

cd ~/dev
# 3.44.9 stable zip 다운로드 후 압축 해제
echo 'export PATH="$HOME/dev/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter --version
```

---

## 2. JDK 21 설치 (Android 빌드용)

Android 빌드를 하려면 필요합니다. iOS/웹만 볼 거면 건너뛰어도 됩니다.

- **Windows**: [Microsoft OpenJDK 21](https://learn.microsoft.com/java/openjdk/download) 설치 후 `JAVA_HOME`을 설치 경로로 설정
- **macOS**: `brew install --cask temurin@21`

확인:

```bash
java -version    # 21.x 가 나와야 함
echo $JAVA_HOME  # Windows: echo $env:JAVA_HOME
```

> ⚠️ `JAVA_HOME`이 **존재하지 않는 경로**를 가리키면 Gradle이 알 수 없는 에러를 냅니다. 설치 후 반드시 경로가 실제로 있는지 확인하세요.

---

## 3. 플랫폼 툴체인

배포 타겟은 **Android + iOS**이고, **태블릿/iPad가 1순위**입니다.

> 💡 **급하지 않으면 나중에 해도 됩니다.** 코드 작성 · `flutter analyze` · `flutter test`는
> 툴체인 없이 전부 되고, 실제 Android/iOS 빌드는 [CI가 대신 검증](../.github/workflows/ci.yml)합니다.
> 화면은 위의 [Chrome 미리보기](#android-sdk가-없어도-화면-보기-chrome)로 볼 수 있습니다.
> **실기기·에뮬레이터로 최종 확인이 필요해지는 시점**에 아래를 설치하세요.

### Android (Windows/macOS 공통)

1. [Android Studio](https://developer.android.com/studio) 설치
2. Android Studio → **More Actions → SDK Manager**
   - **SDK Platforms**: Android 15 (API 36)
   - **SDK Tools**: Android SDK Command-line Tools, Android SDK Build-Tools, Android Emulator
3. 라이선스 동의 (이거 안 하면 빌드 실패):
   ```bash
   flutter doctor --android-licenses
   ```
4. 에뮬레이터는 **태블릿 프로필**(Pixel Tablet 등)로 하나 만들어 두세요. 폰 프로필만 쓰면 태블릿 레이아웃 깨진 걸 못 봅니다.

> 💾 Android Studio + SDK는 디스크를 **10GB 이상** 씁니다. 여유 공간 확인 후 설치하세요.

### iOS (macOS 전용)

```bash
# Xcode는 App Store에서 설치
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

시뮬레이터는 **iPad** 기기로 하나 띄워두세요.

---

## 4. 프로젝트 실행

```bash
# ⚠️ 한글이 없는 경로에서 클론하세요 (Windows 계정명이 한글이면 필수)
cd C:\dev

git clone https://github.com/team-mugunghwa/goodquestion-frontend.git
cd goodquestion-frontend

flutter pub get          # 패키지 설치
flutter devices          # 연결된 기기 확인
flutter run              # 실행
```

### Android SDK가 없어도 화면 보기 (Chrome)

Android Studio(10GB+)를 아직 안 깔았거나 Mac이 없어도, **브라우저로 레이아웃을 확인**할 수 있습니다.

```bash
flutter run -d chrome
```

**태블릿 우선 프로젝트라 이 방법이 반응형 작업에 특히 편합니다.** 브라우저 창을 좌우로 늘렸다 줄이면
`compact`(<600) → `medium`(600~839) → `expanded`(≥840, 2단 레이아웃) 전환이 즉시 보입니다.

> ⚠️ **web은 배포 대상이 아니라 미리보기 수단입니다.** 최종 확인은 반드시 태블릿 실기기나
> 에뮬레이터에서 하세요. 폰트 렌더링·터치 타겟 크기·SafeArea가 실제 기기와 다릅니다.
>
> ⚠️ **`dart:io`를 import하면 web 빌드가 깨집니다.** 플랫폼 분기가 필요하면
> `dart:io`의 `Platform` 대신 `package:flutter/foundation.dart`의 `defaultTargetPlatform`을 쓰세요.
> 예시는 `lib/core/config/app_config.dart` 참고.

### 코드 생성 (json_serializable)

`@JsonSerializable`이 붙은 DTO를 만들거나 고쳤다면 **반드시** 실행해야 합니다.

```bash
# 1회 생성
dart run build_runner build

# 파일 변경 감시하며 자동 생성 (개발 중 권장)
dart run build_runner watch
```

> 인터넷 예제에 흔히 나오는 `--delete-conflicting-outputs` 플래그는
> build_runner 2.9부터 **제거**되었습니다. 붙이면 경고가 뜨고 무시됩니다.

> `*.g.dart` 파일은 **커밋합니다.** (`.gitignore`에 넣지 않음)
> 이유는 [DECISIONS.md](DECISIONS.md#005-생성된-코드-gdart-를-커밋함) 참고.

### API 주소 바꾸기

**아무 설정 없이 그냥 실행됩니다.** 기본값이 로컬 백엔드(`localhost:8080`)를 가리키고,
Android 에뮬레이터에서는 자동으로 `10.0.2.2`로 바뀝니다.

다른 서버를 보려면 실행할 때 넘기세요.

```bash
flutter run --dart-define=API_BASE_URL=https://dev.example.com/api/v1
```

값이 여러 개면 파일로 관리합니다. **`env.json`은 커밋하지 않습니다.**

```bash
flutter run --dart-define-from-file=env.json
```

> `.env` + `flutter_dotenv` 방식을 쓰지 않는 이유: 파일이 없으면 앱이 런타임에 죽는데,
> 새 팀원이 가장 자주 밟는 지뢰입니다. `--dart-define`은 기본값이 있어 클론 직후 바로 실행됩니다.

---

## 5. IDE 설정

### VS Code (권장)

확장 설치: `Dart-Code.flutter`, `Dart-Code.dart-code`

`.vscode/settings.json` (개인 설정, 커밋 안 함):

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": { "source.fixAll": "explicit" },
  "dart.lineLength": 100
}
```

### Android Studio / IntelliJ

Plugins → **Flutter** 설치 (Dart 플러그인은 같이 설치됨)
Settings → Tools → Actions on Save → **Format code** / **Optimize imports** 체크

---

## 6. push 전 체크 (필수)

`main`에 직접 push할 수 있는 만큼, **로컬 검증은 각자 책임입니다.**
아래를 통과시키지 않고 push하면 다음 사람이 깨진 `main`을 받습니다.

```bash
dart format --set-exit-if-changed .   # 포맷
flutter analyze                        # 정적 분석 (경고도 실패 처리)
flutter test                           # 테스트
```

세 개를 한 번에:

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

### push 후에도 확인

push하면 CI가 자동으로 돕니다. **Actions 탭에서 초록불을 확인하세요.**
브랜치 보호가 없어서 빨간 X여도 아무도 막아주지 않습니다. → [CONVENTIONS.md](CONVENTIONS.md#3-main에-올리기)

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| `flutter` 명령을 찾을 수 없음 | PATH에 `flutter/bin` 추가 후 **터미널 새로 열기** |
| `flutter analyze`가 `FormatException: Unexpected end of input`으로 죽음 | **경로에 한글이 있습니다.** 영문 경로로 옮기세요 → [위 경고](#️-경로에-한글이-있으면-안-됩니다-실제로-겪은-문제) |
| Windows에서 빌드가 이상하게 실패 | Flutter SDK나 프로젝트 경로에 **한글/공백**이 있는지 확인 |
| 프로젝트 폴더가 "사용 중"이라 안 지워짐 | `flutter analyze`가 남긴 `dart.exe` 프로세스. 작업 관리자에서 종료 후 삭제 |
| `Android license status unknown` | `flutter doctor --android-licenses` 실행 후 전부 `y` |
| Gradle이 JDK를 못 찾음 | `JAVA_HOME` 경로가 **실제로 존재하는지** 확인 |
| `*.g.dart` 파일이 없다고 에러 | `dart run build_runner build` |
| 에뮬레이터에서 서버 연결 안 됨 | Android 에뮬레이터의 호스트 PC는 `localhost`가 아니라 `10.0.2.2` |
| web에서 `dart:io` 관련 빌드 에러 | web에는 `dart:io`가 없습니다. `defaultTargetPlatform`으로 대체 |
| `flutter run -d chrome`에 기기가 안 보임 | Chrome이 설치돼 있는지 확인. `flutter devices`로 목록 확인 |
| build_runner 결과가 이상함 | `dart run build_runner clean` 후 다시 build |
| pub get 후에도 패키지 못 찾음 | `flutter clean && flutter pub get` |
| iOS 빌드 시 Pod 에러 | `cd ios && pod install --repo-update` |
| 팀원과 `pubspec.lock` 충돌 | 임의로 고치지 말고 `flutter pub get`으로 재생성 후 커밋 |

그래도 안 되면 아래를 통째로 복사해서 팀 채널에 올려주세요.

```bash
flutter doctor -v
```
