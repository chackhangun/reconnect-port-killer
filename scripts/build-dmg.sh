#!/bin/bash
#
# PortKiller.dmg 빌드 스크립트
#
# 사용법:
#   ./scripts/build-dmg.sh
#
# 결과:
#   build/PortKiller.dmg
#     - 윈도우 600x400, 사이드바/툴바 숨김
#     - PortKiller.app 좌측, Applications 심볼릭 링크 우측
#     - 둘 사이에 큰 화살표 + "Drag PortKiller to Applications" 배경
#
# 의존성:
#   brew install create-dmg
#
# 주의:
#   코드 서명은 "Sign to Run Locally"라 다른 Mac에서 받으면 Gatekeeper가
#   차단함. 받는 사람이 우클릭 → 열기 또는 시스템 설정에서 "그래도 열기" 필요.
#   정식 배포는 Apple Developer Program 가입 후 codesign + notarize 필요.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

VOL_NAME="PortKiller"
DMG_PATH="$PROJECT_ROOT/build/PortKiller.dmg"
BG_PATH="$PROJECT_ROOT/build/dmg-background.png"

# 1. 의존성 확인
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg 미설치. 'brew install create-dmg' 실행 필요." >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/build"

# 2. Release 빌드
echo "==> Release 빌드"
xcodebuild \
  -project PortKiller.xcodeproj \
  -scheme PortKiller \
  -configuration Release \
  -destination 'platform=macOS' \
  build \
  | grep -E "error:|warning:|BUILD" | tail -10

RELEASE_APP=$(find ~/Library/Developer/Xcode/DerivedData \
  -name "PortKiller.app" \
  -path "*/Release/*" \
  -not -path "*/Index.noindex/*" \
  2>/dev/null | head -1)

if [[ -z "$RELEASE_APP" ]]; then
  echo "ERROR: Release 빌드 산출물을 찾을 수 없음" >&2
  exit 1
fi
echo "  $RELEASE_APP"

# 3. 배경 PNG 생성
echo "==> DMG 배경 이미지 생성"
swift "$PROJECT_ROOT/scripts/make-dmg-background.swift" "$BG_PATH"

# 4. DMG 생성 (create-dmg)
echo "==> DMG 생성"
rm -f "$DMG_PATH"

create-dmg \
  --volname "$VOL_NAME" \
  --background "$BG_PATH" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 96 \
  --icon "PortKiller.app" 150 200 \
  --hide-extension "PortKiller.app" \
  --app-drop-link 450 200 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$RELEASE_APP"

echo ""
echo "✓ 완료: $DMG_PATH"
echo "  크기: $(du -h "$DMG_PATH" | cut -f1)"
