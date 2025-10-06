#!/bin/bash

# ==============================================================================
# Master Orchestrator v8.0 - Agent Autonomous Mode
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
VALIDATE_SCRIPT="./validate.sh"
BASE_BRANCH="develop"

# --- Helper Functions ---
find_next_task() {
    local task_block=$(awk '
        /^- \[ \] \*\*Task/ {
            found=1;
            block=$0;
            next
        }
        found && /^  - / {
            block=block"\n"$0
        }
        found && /^- \[/ {
            exit
        }
        found && /^$/ {
            exit
        }
        END {
            if (found) print block
        }
    ' "$PLAN_FILE")

    if [ -z "$task_block" ]; then
        return 1
    fi
    echo "$task_block"
}

mark_task_complete() {
    local task_id=$1
    local escaped_id=$(echo "$task_id" | sed 's/\./\\./g; s/-/\\-/g')

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^- \[ \] \*\*Task ${escaped_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    else
        sed -i "s/^- \[ \] \*\*Task ${escaped_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    fi

    if grep -q "^- \[x\] \*\*Task ${task_id}:" "$PLAN_FILE"; then
        echo -e "${GREEN}✅ Task ${task_id} 완료 표시${NC}"
    else
        echo -e "${RED}⚠️  체크박스 업데이트 실패${NC}"
        echo "디버깅: Task ID = ${task_id}"
        grep "Task ${task_id}:" "$PLAN_FILE" || echo "Task를 찾을 수 없음"
    fi
}

rollback_task_completion() {
    local task_id=$1
    local escaped_id=$(echo "$task_id" | sed 's/\./\\./g; s/-/\\-/g')

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^- \[x\] \*\*Task ${escaped_id}:/- [ ] **Task ${task_id}:/" "$PLAN_FILE"
    else
        sed -i "s/^- \[x\] \*\*Task ${escaped_id}:/- [ ] **Task ${task_id}:/" "$PLAN_FILE"
    fi
}

create_feature_branch() {
    local task_id=$1
    local feature_branch="feat/${task_id}"
    local current_branch=$(git branch --show-current)

    if [ "$current_branch" = "$feature_branch" ]; then
        echo -e "${BLUE}ℹ️  이미 ${feature_branch} 브랜치에 있습니다${NC}"
        return 0
    fi

    if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
        echo -e "${RED}❌ ${BASE_BRANCH} 브랜치가 없습니다${NC}"
        echo -e "${YELLOW}💡 git checkout -b ${BASE_BRANCH} 명령으로 생성하세요${NC}"
        exit 1
    fi

    echo -e "${CYAN}🌿 브랜치 생성: ${feature_branch} (from ${BASE_BRANCH})${NC}"

    git checkout "$BASE_BRANCH" 2>/dev/null
    git pull origin "$BASE_BRANCH" 2>/dev/null || true

    git checkout -b "$feature_branch" 2>/dev/null || git checkout "$feature_branch" 2>/dev/null
}

show_pr_instructions() {
    local task_id=$1
    local requirement=$2
    local feature_branch="feat/${task_id}"

    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Task ${task_id} 구현 완료!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    echo -e "${CYAN}📋 다음 단계:${NC}"
    echo -e ""
    echo -e "  ${YELLOW}1.${NC} PR 생성 및 코드 리뷰"
    echo -e "     ${BLUE}브랜치:${NC} ${feature_branch} → ${BASE_BRANCH}"
    echo -e "     ${BLUE}제목:${NC} feat: Task ${task_id} - ${requirement:0:50}..."
    echo -e ""
    echo -e "  ${YELLOW}2.${NC} GitHub에서 PR 생성 (또는 CLI 사용):"
    echo -e "     ${GREEN}gh pr create --base ${BASE_BRANCH} --head ${feature_branch} \\${NC}"
    echo -e "     ${GREEN}  --title \"feat: Task ${task_id} - ${requirement:0:40}...\" \\${NC}"
    echo -e "     ${GREEN}  --body \"Closes #issue-number\"${NC}"
    echo -e ""
    echo -e "  ${YELLOW}3.${NC} 리뷰 승인 후 ${BASE_BRANCH}에 머지"
    echo -e ""
    echo -e "  ${YELLOW}4.${NC} 다음 Task 실행:"
    echo -e "     ${GREEN}git checkout ${BASE_BRANCH}${NC}"
    echo -e "     ${GREEN}git pull origin ${BASE_BRANCH}${NC}"
    echo -e "     ${GREEN}./main.sh${NC}"
    echo -e ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}현재 브랜치: ${feature_branch}${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
}

# --- 메인 루프 ---
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       TDD 자동화 워크플로우 v8.0 (에이전트 자율)         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}📋 다음 Task를 찾는 중...${NC}"

if ! TASK_BLOCK=$(find_next_task); then
    echo -e "${GREEN}🎉 모든 Task 완료!${NC}"
    exit 0
fi

TASK_ID=$(echo "$TASK_BLOCK" | grep -o 'Task [0-9-]*' | head -1 | cut -d' ' -f2)
REQUIREMENT=$(echo "$TASK_BLOCK" | grep '요구사항:' | sed 's/.*요구사항:[[:space:]]*"\?\([^"]*\)"\?.*/\1/')
TEST_DESC=$(echo "$TASK_BLOCK" | grep '테스트:' | sed 's/.*테스트:[[:space:]]*//')

if [ -z "$TASK_ID" ] || [ -z "$REQUIREMENT" ]; then
    echo -e "${RED}❌ Task 정보 파싱 실패 - PLAN.md 형식 확인 필요${NC}"
    echo ""
    echo "Task Block:"
    echo "----------------------------------------"
    echo "$TASK_BLOCK"
    echo "----------------------------------------"
    echo ""
    echo "파싱 결과:"
    echo "  TASK_ID: '${TASK_ID}'"
    echo "  REQUIREMENT: '${REQUIREMENT}'"
    echo ""
    exit 1
fi

echo -e "${YELLOW}🎯 Task ${TASK_ID}: ${REQUIREMENT}${NC}"
echo -e "   🧪 테스트: ${TEST_DESC}"

# Feature 브랜치 생성
create_feature_branch "$TASK_ID"

# TDD 사이클 실행 (에이전트 자율 모드 - 경로 없이 Task ID만 전달)
echo -e "\n${CYAN}🤖 에이전트 자율 결정 모드 시작${NC}"
echo -e "${BLUE}ℹ️  에이전트가 파일 구조와 경로를 결정합니다${NC}"
echo ""

if "$TDD_SCRIPT" "$REQUIREMENT" "$TASK_ID"; then
    echo -e "\n${GREEN}✅ Task ${TASK_ID} 성공!${NC}"

    mark_task_complete "$TASK_ID"

    if ! git add . || ! git commit -m "feat(task-${TASK_ID}): ${REQUIREMENT}" > /dev/null 2>&1; then
        echo -e "${RED}❌ Git 커밋 실패${NC}"
        rollback_task_completion "$TASK_ID"
        exit 1
    fi

    show_pr_instructions "$TASK_ID" "$REQUIREMENT"
    exit 0
else
    echo -e "\n${RED}❌ Task ${TASK_ID} 실패${NC}"
    exit 1
fi
