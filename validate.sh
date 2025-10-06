#!/bin/bash

# ==============================================================================
# Validation Script (validate.sh) v3.0 - Enhanced Error Visibility
#
# 이 스크립트는 프로젝트의 무결성을 효율적으로 검증합니다.
# 1. 코드 포맷팅 적용 (Spotless Apply)
# 2. 전체 테스트 실행 (Build & Test)
#
# 모든 오류 로그를 투명하게 노출하여 Debugger 에이전트의 작동을 보장합니다.
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔄 코드 검증을 시작합니다...${NC}"

# 1단계: 코드 포맷팅
echo "  1/2: 🎨 코드 포맷팅 적용 (Spotless Apply)..."
if ! ./gradlew spotlessApply 2>&1; then
    echo -e "${RED}❌ 코드 포맷팅 실패${NC}"
    exit 1
fi

# 2단계: 빌드 및 테스트
echo "  2/2: ✅ 프로젝트 빌드 및 모든 테스트 실행..."
if ! ./gradlew test 2>&1; then
    echo -e "${RED}❌ 테스트 실패${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 검증 통과!${NC}"
exit 0
