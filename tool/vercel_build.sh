#!/usr/bin/env bash
#
# Vercel 빌드 스크립트.
#
# Vercel 은 Flutter 런타임이 없어서 SDK 를 직접 받아 씁니다.
# 결과물인 build/web 을 정적 사이트로 서빙합니다. -> vercel.json
#
# 로컬에서 배포 빌드를 재현해 보려면:
#   API_BASE_URL=https://goodquestion-backend-production.up.railway.app/api \
#     bash tool/vercel_build.sh
set -euo pipefail

# .github/workflows/ci.yml 의 FLUTTER_VERSION 과 같은 값을 유지하세요.
# 버전이 갈리면 CI 는 통과하는데 배포만 깨지는 상황이 생깁니다.
FLUTTER_VERSION="3.44.9"
FLUTTER_HOME="$HOME/flutter"

if [ ! -d "$FLUTTER_HOME" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

# Vercel 빌드 컨테이너는 clone 한 저장소의 소유자가 달라서
# git 이 "dubious ownership" 으로 거부합니다. flutter 명령이 내부에서
# git 을 쓰기 때문에 이걸 안 해두면 SDK 인식 자체가 실패합니다.
git config --global --add safe.directory "$FLUTTER_HOME"

flutter --version
flutter pub get

# 배포된 프론트는 Railway 백엔드를 봅니다. 로컬 실행은 이 스크립트를 타지
# 않으므로 영향이 없습니다 (AppConfig 폴백이 로컬 백엔드를 가리킴).
#
# 백엔드 주소가 바뀌면 env/prod.json 과 이 값을 같이 고치세요.
# Vercel 대시보드에 API_BASE_URL 을 등록하면 그 값이 우선합니다.
API_BASE_URL="${API_BASE_URL:-https://goodquestion-backend-production.up.railway.app/api}"

# 여기서 http 가 넘어오면 HTTPS 페이지라 브라우저가 mixed content 로 막습니다.
# 배포 후에 콘솔을 열어보고서야 알게 되느니 빌드를 세웁니다.
case "$API_BASE_URL" in
  https://*) ;;
  *) echo "API_BASE_URL 은 https 여야 합니다: $API_BASE_URL" >&2; exit 1 ;;
esac

# 소셜 로그인 키는 Vercel 대시보드의 환경변수로 들어옵니다. 값이 비어 있어도
# 빌드는 성공하지만 그 공급자로는 로그인할 수 없는 앱이 나갑니다.
#
# 조용히 나가면 안 되는 이유가 있습니다. KAKAO_CLIENT_ID 같은 값은
# String.fromEnvironment 로 읽는 컴파일 시점 상수라, 비면 앱 코드의
# `if (clientId.isEmpty) throw ...` 가 항상 참이 되고 컴파일러가 그 뒤의
# 인가 URL 코드를 죽은 코드로 지워 버립니다. 배포 후 브라우저에서 값을
# 넣어 고칠 방법이 없고, 다시 빌드하는 수밖에 없습니다. 실제로 카카오
# 로그인이 "키가 설정되지 않았습니다"만 띄우고 네트워크도 안 타는 상태로
# 배포된 적이 있습니다.
missing_social_keys=()
[ -n "${KAKAO_CLIENT_ID:-}" ] || missing_social_keys+=("KAKAO_CLIENT_ID (카카오)")
[ -n "${GOOGLE_CLIENT_ID:-}" ] || missing_social_keys+=("GOOGLE_CLIENT_ID (구글)")

if [ ${#missing_social_keys[@]} -gt 0 ]; then
  {
    echo
    echo "================================================================"
    echo " 경고: 소셜 로그인이 비활성화된 빌드입니다"
    echo "================================================================"
    for key in "${missing_social_keys[@]}"; do
      echo "  - $key 없음"
    done
    echo
    echo " 해당 공급자 버튼을 누르면 '소셜 로그인 키가 설정되지 않았습니다'만"
    echo " 뜨고 인증 창도 열리지 않습니다."
    echo
    echo " 고치는 법: Vercel Settings > Environment Variables 에 값을 넣고"
    echo " 반드시 재배포하세요. 환경변수만 바꾸면 다시 빌드되지 않습니다."
    echo "================================================================"
    echo
  } >&2
  # 키가 갖춰진 뒤에는 REQUIRE_SOCIAL_KEYS=1 을 걸어 두면 같은 실수가
  # 빌드 단계에서 막힙니다. 기본값은 경고입니다 - 소셜 로그인 없이도
  # 이메일 로그인은 동작하므로, 무관한 수정의 배포까지 막지는 않습니다.
  if [ "${REQUIRE_SOCIAL_KEYS:-0}" = "1" ]; then
    echo "REQUIRE_SOCIAL_KEYS=1 이므로 빌드를 중단합니다." >&2
    exit 1
  fi
fi

# dart-define 값은 번들된 JS 에 그대로 남습니다. 공개해도 되는 값만 넣으세요.
# MOCK_SOCIAL_LOGIN 은 배포 빌드에서 절대 켜지 않습니다 (기본값 false).
flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}" \
  --dart-define=KAKAO_CLIENT_ID="${KAKAO_CLIENT_ID:-}" \
  --dart-define=OAUTH_REDIRECT_URI="${OAUTH_REDIRECT_URI:-}"

# 키를 넣었는데도 정말 반영됐는지는 결과물로 확인합니다. dart-define 이 실제로
# 적용됐다면 죽은 코드 제거가 일어나지 않아 인가 URL 이 번들에 남습니다.
# 오늘 이 흔적의 유무로 "키 없이 빌드된 번들"을 판별했습니다.
bundle="build/web/main.dart.js"
if [ -f "$bundle" ]; then
  echo "빌드 결과 확인:"
  for pair in "KAKAO_CLIENT_ID:kauth.kakao.com:카카오" "GOOGLE_CLIENT_ID:accounts.google.com:구글"; do
    var="${pair%%:*}"; rest="${pair#*:}"; host="${rest%%:*}"; label="${rest#*:}"
    if grep -q "$host" "$bundle"; then
      echo "  $label 로그인: 인가 URL 이 번들에 있음"
    elif [ -n "$(eval echo "\${$var:-}")" ]; then
      echo "  $label 로그인: $var 를 줬는데 인가 URL 이 번들에 없습니다 - 확인이 필요합니다" >&2
    else
      echo "  $label 로그인: 비활성 ($var 없음)"
    fi
  done
fi
