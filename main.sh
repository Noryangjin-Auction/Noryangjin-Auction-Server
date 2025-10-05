#!/bin/bash

# ==============================================================================
# Master Orchestrator (main.sh) v3.1 - Final Fix
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PLAN_FILE="./PLAN.md"
TDD_SCRIPT="./run_tdd_cycle.sh"
PARSER_SCRIPT="./parse_plan.py"
SRC_PREFIX="src/main/java/com/noryangjin/auction/server"
TEST_SRC_PREFIX="src/test/java/com/noryangjin/auction/server"

# --- Task 완료 표시 ---
mark_task_complete() {
    local task_id=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^- \[ \] \**Task ${task_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    else
        sed -i "s/^- \[ \] \**Task ${task_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    fi
    echo -e "${GREEN}✅ Task ${task_id}가 완료 표시되었습니다.${NC}"
}

# --- 메인 루프 ---
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       TDD 자동화 워크플로우 시작 (v3.1)                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

while true; do
    echo -e "\n${BLUE}📋 다음 Task를 찾는 중...${NC}"
    TASK_INFO=$(python3 "$PARSER_SCRIPT" "$PLAN_FILE")

    if [ -z "$TASK_INFO" ]; then
        echo -e "${GREEN}🎉 축하합니다! PLAN.md의 모든 Task가 완료되었습니다!${NC}"
        break
    fi

    TASK_ID=$(echo "$TASK_INFO" | cut -d'|' -f1 | xargs)
    TASK_REQUIREMENT=$(echo "$TASK_INFO" | cut -d'|' -f2 | xargs)
    IMPLEMENTATION_TARGET=$(echo "$TASK_INFO" | cut -d'|' -f3 | xargs)

    TEST_TARGET=$(echo "$IMPLEMENTATION_TARGET" | sed 's/\.java/Test.java/')
    IMPLEMENTATION_PATH="${SRC_PREFIX}/${IMPLEMENTATION_TARGET}"
    TEST_PATH="${TEST_SRC_PREFIX}/${TEST_TARGET}"

    echo -e "${YELLOW}🎯 다음 Task: ${TASK_ID} - ${TASK_REQUIREMENT}${NC}"
    echo -e "   - 구현 대상: ${IMPLEMENTATION_PATH}"
    echo -e "   - 테스트 대상: ${TEST_PATH}"
    echo ""

    if $TDD_SCRIPT "$TASK_REQUIREMENT" "$TEST_PATH" "$IMPLEMENTATION_PATH"; then
        echo -e "\n${GREEN}✅ Task ${TASK_ID} 완료!${NC}"
        mark_task_complete "$TASK_ID"
        git add . && git commit -m "feat(task-${TASK_ID}): ${TASK_REQUIREMENT}" --no-verify
        echo -e "${CYAN}✓ Task ${TASK_ID} 완료 및 커밋됨${NC}"
        echo -e "\n${YELLOW}⏭️  3초 후 다음 Task를 시작합니다...${NC}"
        sleep 3
    else
        echo -e "\n${RED}❌ Task ${TASK_ID} 실패${NC}"
        echo -e "${YELLOW}수정 후 다시 ./main.sh를 실행하세요.${NC}"
        exit 1
    fi
done
