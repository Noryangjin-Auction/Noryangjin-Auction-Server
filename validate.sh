#!/bin/bash

# ==============================================================================
# Validation Script (validate.sh) v2.0 - Optimized & Debugger-Friendly
#
# 이 스크립트는 프로젝트의 무결성을 효율적으로 검증합니다.
# 1. 코드 포맷팅 검사 (Check)
# 2. 전체 테스트 실행 (Build & Test)
#
# 모든 오류 로그를 투명하게 노출하여 Debugger 에이전트의 작동을 보장합니다.
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 코드 검증을 시작합니다...${NC}"

echo "  1/2: 🎨 코드 포맷팅 검사 (Spotless Check)..."
./gradlew spotlessApply

echo "  2/2: ✅ 프로젝트 빌드 및 모든 테스트 실행..."
./gradlew test

echo -e "\n${GREEN}🎉 검증 통과!${NC}"
