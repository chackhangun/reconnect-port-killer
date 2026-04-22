#!/bin/bash
#
# PortKiller 자동 설치 스크립트.
# DMG 안에서 더블클릭하면 Terminal에서 실행됨.
#
# 하는 일:
#   1. 기존 실행 중인 PortKiller 종료
#   2. /Applications/ 에 복사 (덮어쓰기)
#   3. quarantine 속성 제거 (Gatekeeper 경고 회피)
#   4. 실행

set -e

DMG_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PortKiller.app"
SOURCE="$DMG_DIR/$APP_NAME"
DEST="/Applications/$APP_NAME"

echo ""
echo "  ┌────────────────────────────────┐"
echo "  │   PortKiller 자동 설치          │"
echo "  └────────────────────────────────┘"
echo ""

if [[ ! -d "$SOURCE" ]]; then
  echo "  ✗ ${APP_NAME}을 찾을 수 없습니다."
  echo "    현재 위치: $DMG_DIR"
  echo ""
  echo "  이 스크립트는 PortKiller.dmg 마운트 후 그 안에서 실행되어야 합니다."
  echo ""
  echo "  아무 키나 누르면 닫힙니다..."
  read -n 1
  exit 1
fi

# 1) 기존 인스턴스 종료
if pgrep -x "PortKiller" >/dev/null 2>&1; then
  echo "  [1/4] 실행 중인 PortKiller 종료..."
  pkill -x "PortKiller" 2>/dev/null || true
  sleep 1
else
  echo "  [1/4] 실행 중인 인스턴스 없음 (skip)"
fi

# 2) /Applications/ 로 복사
echo "  [2/4] /Applications/${APP_NAME} 로 복사..."
if [[ -d "$DEST" ]]; then
  rm -rf "$DEST"
fi
cp -R "$SOURCE" "$DEST"

# 3) Quarantine 속성 제거 — 핵심
#    DMG로 받은 .app은 Gatekeeper가 quarantine을 붙여서 ad-hoc 서명된
#    앱을 "악성 코드 포함"으로 차단함. xattr -cr 로 모든 확장 속성 제거.
echo "  [3/4] 보안 격리 속성 제거 (xattr -cr)..."
xattr -cr "$DEST"

# 4) 실행
echo "  [4/4] PortKiller 실행..."
open "$DEST"

echo ""
echo "  ✓ 설치 완료"
echo "    메뉴바 우측 상단에서 PortKiller 아이콘을 확인하세요."
echo ""
echo "  이 창은 닫아도 됩니다."
echo ""
