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

# dart-define 값은 번들된 JS 에 그대로 남습니다. 공개해도 되는 값만 넣으세요.
# MOCK_SOCIAL_LOGIN 은 배포 빌드에서 절대 켜지 않습니다 (기본값 false).
flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}" \
  --dart-define=KAKAO_CLIENT_ID="${KAKAO_CLIENT_ID:-}" \
  --dart-define=OAUTH_REDIRECT_URI="${OAUTH_REDIRECT_URI:-}"
