#!/bin/bash

# ==============================================================================
# Master Orchestrator (main.sh) v2.1 - Simplified Parser
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
SRC_PREFIX="src/main/java/com/noryangjin/auction/server"
TEST_SRC_PREFIX="src/test/java/com/noryangjin/auction/server"

# --- 다음 미완료 Task 정보 파싱 (단순화된 버전) ---
find_next_task_info() {
    if [ ! -f "$PLAN_FILE" ]; then
        echo -e "${RED}오류: PLAN.md 파일을 찾을 수 없습니다.${NC}" >&2; exit 1;
    fi

    # 첫 번째 미완료 Task 라인(- [ ])의 줄 번호 찾기
    local line_num=$(grep -n "^- \[ \] \*\*Task" "$PLAN_FILE" | head -n 1 | cut -d: -f1)

    if [ -z "$line_num" ]; then
        echo -e "${GREEN}🎉 축하합니다! PLAN.md의 모든 Task가 완료되었습니다!${NC}"
        exit 0
    fi

    # 해당 Task 블록 추출 (다음 Task 시작 전까지)
    local next_task_start_line=$(grep -n "^- \[ \] \*\*Task" "$PLAN_FILE" | tail -n +2 | head -n 1 | cut -d: -f1)
    local task_block
    if [ -z "$next_task_start_line" ]; then
        task_block=$(tail -n +$line_num "$PLAN_FILE")
    else
        local lines_to_read=$((next_task_start_line - line_num))
        task_block=$(tail -n +$line_num "$PLAN_FILE" | head -n $lines_to_read)
    fi

    # 정보 추출
    local task_id=$(echo "$task_block" | grep "^- \[ \] \*\*Task" | sed -n 's/.*Task \([0-9-]*\):.*/\1/p')
    local requirement=$(echo "$task_block" | grep "- 요구사항:" | sed 's/.*- 요구사항: //' | tr -d '"' | xargs)
    local target=$(echo "$task_block" | grep "- 구현 대상:" | sed 's/.*- 구현 대상: //' | tr -d '`' | xargs)

    if [ -z "$task_id" ] || [ -z "$requirement" ] || [ -z "$target" ]; then
        echo -e "${RED}오류: Task 정보 파싱 실패 (ID: $task_id, Req: $requirement, Target: $target)${NC}" >&2
        exit 1
    fi

    echo "$task_id|$requirement|$target"
}

# --- Task 완료 표시 ---
mark_task_complete() {
    local task_id=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^- \[ \] \*\*Task ${task_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    else
        sed -i "s/^- \[ \] \*\*Task ${task_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    fi
    echo -e "${GREEN}✅ Task ${task_id}가 완료 표시되었습니다.${NC}"
}

# --- 메인 루프 ---
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       TDD 자동화 워크플로우 시작 (v2.1)                   ║${NC}
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

while true; do
    echo -e "\n${BLUE}📋 다음 Task를 찾는 중...${NC}"
    TASK_INFO=$(find_next_task_info)

    if [ -z "$TASK_INFO" ]; then break; fi

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

echo -e "\n${GREEN}🎉 모든 Task 완료! 프로젝트 개발 종료!${NC}"
