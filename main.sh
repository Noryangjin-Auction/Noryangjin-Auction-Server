#!/bin/bash

# ==============================================================================
# Master Orchestrator v7.0 - PR Workflow Integration
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
SRC_PREFIX="src/main/java/com/noryangjin/auction/server"
TEST_SRC_PREFIX="src/test/java/com/noryangjin/auction/server"
BASE_BRANCH="develop"  # PR의 base 브랜치

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

    # 이미 해당 feature 브랜치에 있으면 그대로 사용
    if [ "$current_branch" = "$feature_branch" ]; then
        echo -e "${BLUE}ℹ️  이미 ${feature_branch} 브랜치에 있습니다${NC}"
        return 0
    fi

    # develop 브랜치 확인
    if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
        echo -e "${RED}❌ ${BASE_BRANCH} 브랜치가 없습니다${NC}"
        echo -e "${YELLOW}💡 git checkout -b ${BASE_BRANCH} 명령으로 생성하세요${NC}"
        exit 1
    fi

    # develop 브랜치로부터 feature 브랜치 생성
    echo -e "${CYAN}🌿 브랜치 생성: ${feature_branch} (from ${BASE_BRANCH})${NC}"

    # develop 최신 상태로 업데이트
    git checkout "$BASE_BRANCH" 2>/dev/null
    git pull origin "$BASE_BRANCH" 2>/dev/null || true

    # feature 브랜치 생성
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

parse_multifile() {
    local output_file=$1

    python3 - "$output_file" <<'PYPARSESCRIPT'
import sys
import os
import re

with open(sys.argv[1], 'r') as f:
    content = f.read()

if '===FILE_BOUNDARY===' in content:
    blocks = re.split(r'\n===FILE_BOUNDARY===\n', content)
else:
    blocks = re.split(r'\n---\n', content)

for block in blocks:
    block = block.strip()
    if not block or not block.startswith('path:'):
        continue

    lines = block.split('\n')
    filepath = lines[0].replace('path:', '').strip()
    filepath = filepath.replace('com/noryangjinauctioneer', 'com/noryangjin/auction/server')

    code_lines = []
    in_code = False

    for line in lines[1:]:
        if line.strip().startswith('```'):
            if not in_code:
                in_code = True
                continue
            else:
                break
        if in_code:
            code_lines.append(line)

    if code_lines:
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, 'w') as f:
            f.write('\n'.join(code_lines))
        print(f"✓ {filepath}", file=sys.stderr)
PYPARSESCRIPT
}

validate_and_clean_output() {
    local agent_name=$1
    local raw_output=$2

    if [ -z "$(echo "$raw_output" | tr -d '[:space:]')" ]; then
        echo -e "${RED}ERROR: ${agent_name} returned empty response${NC}" >&2
        return 1
    fi

    local cleaned=$(echo "$raw_output" | sed '/^```[a-z]*$/d; /^```$/d')

    if echo "$cleaned" | grep -q "com\.noryangjinauctioneer\|com\.noryangfin"; then
        echo -e "${YELLOW}WARNING: ${agent_name} used wrong package. Auto-fixing...${NC}" >&2
        cleaned=$(echo "$cleaned" | sed 's/com\.noryangjinauctioneer/com.noryangjin.auction.server/g; s/com\.noryangfin/com.noryangjin/g')
    fi

    echo "$cleaned"
}

check_task_already_done() {
    local impl_path=$1
    local test_path=$2

    if [ -f "$impl_path" ] && [ -f "$test_path" ]; then
        echo -e "${CYAN}🔍 기존 구현 확인 중...${NC}"

        if $VALIDATE_SCRIPT > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Task 이미 완료됨 - 스킵${NC}"
            return 0
        fi
    fi

    return 1
}

# --- 메인 루프 ---
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       TDD 자동화 워크플로우 v7.0 (PR 통합)               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

# 단일 Task만 처리 (while 루프 제거)
echo -e "\n${BLUE}📋 다음 Task를 찾는 중...${NC}"

if ! TASK_BLOCK=$(find_next_task); then
    echo -e "${GREEN}🎉 모든 Task 완료!${NC}"
    exit 0
fi

TASK_ID=$(echo "$TASK_BLOCK" | grep -o 'Task [0-9-]*' | head -1 | cut -d' ' -f2)
REQUIREMENT=$(echo "$TASK_BLOCK" | grep '요구사항:' | sed 's/.*요구사항:[[:space:]]*"\?\([^"]*\)"\?.*/\1/')
TEST_DESC=$(echo "$TASK_BLOCK" | grep '테스트:' | sed 's/.*테스트:[[:space:]]*//')
TARGET=$(echo "$TASK_BLOCK" | grep '구현 대상:' | sed 's/.*구현 대상:[[:space:]]*`\([^`]*\)`.*/\1/')

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

# Feature 브랜치 생성
create_feature_branch "$TASK_ID"

# 테스트 없는 Task (구조 정의)
if [[ "$TEST_DESC" == "없음"* ]] || [ -z "$TEST_DESC" ]; then
    echo -e "${BLUE}ℹ️  구조 정의 Task${NC}"
    echo -e "   📂 대상: ${TARGET}"

    IMPL_PATH="${SRC_PREFIX}/${TARGET}"

    if [ -f "$IMPL_PATH" ]; then
        echo -e "${CYAN}🔍 기존 파일 확인 중...${NC}"
        if ./gradlew compileJava > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 이미 구현됨 - 스킵${NC}"
            mark_task_complete "$TASK_ID"

            if ! git diff --quiet; then
                git add . && git commit -m "chore(task-${TASK_ID}): 기존 구현 확인" > /dev/null 2>&1
            fi

            show_pr_instructions "$TASK_ID" "$REQUIREMENT"
            exit 0
        fi
    fi

    mkdir -p "$(dirname "$IMPL_PATH")"
    mkdir -p tmp_prompts

    PROMPT_FILE="tmp_prompts/direct_creation.txt"
    {
        echo "# Task"
        echo "Create file: ${IMPL_PATH}"
        echo ""
        echo "# Requirement"
        echo "$REQUIREMENT"
    } > "$PROMPT_FILE"

    AGENT_FILE=".claude/agents/engineer.md"
    MODEL=$(grep '^model:' "$AGENT_FILE" | cut -d' ' -f2 | tr -d '\r')
    PROVIDER=$(grep '^provider:' "$AGENT_FILE" | cut -d' ' -f2 | tr -d '\r')
    PROVIDER_SCRIPT="providers/${PROVIDER}.sh"

    echo -e "🤖 engineer 호출..."
    GENERATED_CODE=$("$PROVIDER_SCRIPT" "$MODEL" "$AGENT_FILE" "$PROMPT_FILE")

    GENERATED_CODE=$(validate_and_clean_output "engineer" "$GENERATED_CODE") || exit 1

    if echo "$GENERATED_CODE" | grep -qE "(===FILE_BOUNDARY===|^---$)" && echo "$GENERATED_CODE" | grep -q "^path:"; then
        echo -e "${BLUE}📦 Multi-file${NC}"
        echo "$GENERATED_CODE" > tmp_prompts/multifile_temp.txt
        parse_multifile tmp_prompts/multifile_temp.txt
    else
        echo -e "${BLUE}📄 Single-file${NC}"
        echo "$GENERATED_CODE" > "$IMPL_PATH"
        echo -e "${GREEN}✓ ${IMPL_PATH}${NC}"
    fi

    if ! ./gradlew compileJava > /dev/null 2>&1; then
        echo -e "${RED}❌ 컴파일 실패${NC}"
        ./gradlew compileJava
        exit 1
    fi
    echo -e "${GREEN}✅ 컴파일 성공${NC}"

    mark_task_complete "$TASK_ID"

    if ! git add . || ! git commit -m "feat(task-${TASK_ID}): ${REQUIREMENT}" > /dev/null 2>&1; then
        echo -e "${RED}❌ Git 커밋 실패${NC}"
        rollback_task_completion "$TASK_ID"
        exit 1
    fi

    show_pr_instructions "$TASK_ID" "$REQUIREMENT"
    exit 0
fi

# TDD 실행
IMPL_PATH="${SRC_PREFIX}/${TARGET}"
TEST_PATH="${TEST_SRC_PREFIX}/$(echo "$TARGET" | sed 's/\.java$/Test.java/')"
echo -e "   🧪 테스트: ${TEST_DESC}"
echo ""

if check_task_already_done "$IMPL_PATH" "$TEST_PATH"; then
    mark_task_complete "$TASK_ID"

    if ! git diff --quiet; then
        git add . && git commit -m "chore(task-${TASK_ID}): 기존 구현 확인" > /dev/null 2>&1
    fi

    show_pr_instructions "$TASK_ID" "$REQUIREMENT"
    exit 0
fi

if "$TDD_SCRIPT" "$REQUIREMENT" "$TEST_PATH" "$IMPL_PATH"; then
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
