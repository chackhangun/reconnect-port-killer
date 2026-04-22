#!/bin/bash
#
# PortKiller.dmg 빌드 스크립트
#
# 사용법:
#   ./scripts/build-dmg.sh
#
# 결과:
#   build/PortKiller.dmg
#     - 상단: PortKiller.app → Applications 드래그 UX
#     - 하단: Install.command (자동 설치 + Gatekeeper 우회)
#
# 의존성:
#   brew install create-dmg
#
# 코드 서명:
#   "Sign to Run Locally" (ad-hoc). 받는 사람 Mac에서 Gatekeeper가 강한
#   경고를 띄울 수 있음. Install.command 사용 시 xattr -cr로 회피됨.
#   정식 배포는 Apple Developer Program 가입 후 codesign + notarize 필요.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

VOL_NAME="PortKiller"
DMG_PATH="$PROJECT_ROOT/build/PortKiller.dmg"
BG_PATH="$PROJECT_ROOT/build/dmg-background.png"
INSTALL_TEMPLATE="$PROJECT_ROOT/scripts/install-template.command"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg 미설치. 'brew install create-dmg' 실행 필요." >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/build"

# 1. Release 빌드
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

# 2. 배경 이미지 생성
echo "==> DMG 배경 이미지 생성"
swift "$PROJECT_ROOT/scripts/make-dmg-background.swift" "$BG_PATH"

# 3. staging 폴더 준비 (PortKiller.app + Install.command)
echo "==> staging 폴더 준비"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$RELEASE_APP" "$STAGE/"
cp "$INSTALL_TEMPLATE" "$STAGE/Install.command"
chmod +x "$STAGE/Install.command"

# 4. DMG 생성
echo "==> DMG 생성"
rm -f "$DMG_PATH"

create-dmg \
  --volname "$VOL_NAME" \
  --background "$BG_PATH" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 84 \
  --icon "PortKiller.app" 130 230 \
  --hide-extension "PortKiller.app" \
  --app-drop-link 470 230 \
  --icon "Install.command" 300 90 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$STAGE"

echo ""
echo "✓ 완료: $DMG_PATH"
echo "  크기: $(du -h "$DMG_PATH" | cut -f1)"
