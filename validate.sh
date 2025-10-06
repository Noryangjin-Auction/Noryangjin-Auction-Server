#!/bin/bash

# ==============================================================================
# Validation Script (validate.sh) v3.0 - Aggressive Cache Invalidation
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔄 코드 검증을 시작합니다 (강력한 캐시 초기화 포함)...${NC}"

# 1. Daemon 중지
echo "  1/4: 🛑 Gradle Daemon 중지..."
./gradlew --stop || true # 데몬이 없어도 실패하지 않음

# 2. 모든 캐시 삭제
echo "  2/4: 🗑️ 모든 Gradle 캐시 삭제..."
rm -rf .gradle/
rm -rf build/
# rm -rf ~/.gradle/caches/ # 사용자 홈 디렉토리의 캐시는 일단 주석 처리 (영향이 너무 큼)

# 3. 완전히 새로운 빌드
echo "  3/4: 🎨 코드 포맷팅 검사 (Spotless Check)..."
./gradlew spotlessCheck

echo "  4/4: ✅ 프로젝트 빌드 및 모든 테스트 실행..."
./gradlew test --no-build-cache --rerun-tasks

echo -e "\n${GREEN}🎉 검증 통과!${NC}"
