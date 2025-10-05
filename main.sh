#!/bin/bash

# ==============================================================================
# Master Orchestrator v5.3 - Production Ready with Enhanced Error Handling
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

# --- 메인 루프 ---
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       TDD 자동화 워크플로우 v5.3                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

while true; do
    echo -e "\n${BLUE}📋 다음 Task를 찾는 중...${NC}"

    if ! TASK_BLOCK=$(find_next_task); then
        echo -e "${GREEN}🎉 모든 Task 완료!${NC}"
        break
    fi

    TASK_ID=$(echo "$TASK_BLOCK" | grep -o 'Task [0-9-]*' | head -1 | cut -d' ' -f2)
    REQUIREMENT=$(echo "$TASK_BLOCK" | grep '요구사항:' | sed 's/.*요구사항:[[:space:]]*"\?\([^"]*\)"\?.*/\1/')
    TEST_DESC=$(echo "$TASK_BLOCK" | grep '테스트:' | sed 's/.*테스트:[[:space:]]*//')
    TARGET=$(echo "$TASK_BLOCK" | grep '구현 대상:' | sed 's/.*구현 대상:[[:space:]]*`\([^`]*\)`.*/\1/')

    # 파싱 검증 (상세 로그)
    if [ -z "$TASK_ID" ] || [ -z "$REQUIREMENT" ] || [ -z "$TARGET" ]; then
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
        echo "  TARGET: '${TARGET}'"
        echo ""
        echo "PLAN.md 형식을 확인하고 수정 후 재실행하세요."
        exit 1
    fi

    echo -e "${YELLOW}🎯 Task ${TASK_ID}: ${REQUIREMENT}${NC}"
    echo -e "   📂 대상: ${TARGET}"

    # 테스트 없는 Task
    if [[ "$TEST_DESC" == "없음"* ]] || [ -z "$TEST_DESC" ]; then
        echo -e "${BLUE}ℹ️  구조 정의 Task${NC}"

        IMPL_PATH="${SRC_PREFIX}/${TARGET}"
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

        if [ -z "$(echo "$GENERATED_CODE" | tr -d '[:space:]')" ]; then
            echo -e "${RED}❌ 빈 응답${NC}"
            exit 1
        fi

        if echo "$GENERATED_CODE" | grep -qE "(===FILE_BOUNDARY===|^---$)" && echo "$GENERATED_CODE" | grep -q "^path:"; then
            echo -e "${BLUE}📦 Multi-file${NC}"
            echo "$GENERATED_CODE" > tmp_prompts/multifile_temp.txt
            parse_multifile tmp_prompts/multifile_temp.txt
        else
            echo -e "${BLUE}📄 Single-file${NC}"
            echo "$GENERATED_CODE" | sed '/^```/d' > "$IMPL_PATH"
            echo -e "${GREEN}✓ ${IMPL_PATH}${NC}"
        fi

        echo -e "${CYAN}🔧 패키지 이름 자동 수정...${NC}"
        find src/main/java -type f -name "*.java" -exec sed -i '' 's/com\.noryangjinauctioneer/com.noryangjin.auction.server/g' {} +

        # 컴파일 검증
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

        echo -e "\n${YELLOW}⏭️  3초 후 다음 Task...${NC}"
        sleep 3
        continue
    fi

    # TDD 실행
    IMPL_PATH="${SRC_PREFIX}/${TARGET}"
    TEST_PATH="${TEST_SRC_PREFIX}/$(echo "$TARGET" | sed 's/\.java$/Test.java/')"
    echo -e "   🧪 테스트: ${TEST_DESC}"
    echo ""

    if "$TDD_SCRIPT" "$REQUIREMENT" "$TEST_PATH" "$IMPL_PATH"; then
        echo -e "\n${GREEN}✅ Task ${TASK_ID} 성공!${NC}"

        mark_task_complete "$TASK_ID"

        if ! git add . || ! git commit -m "feat(task-${TASK_ID}): ${REQUIREMENT}" > /dev/null 2>&1; then
            echo -e "${RED}❌ Git 커밋 실패${NC}"
            rollback_task_completion "$TASK_ID"
            exit 1
        fi

        echo -e "${CYAN}✓ Task ${TASK_ID} 완료${NC}"
        echo -e "\n${YELLOW}⏭️  3초 후 다음 Task...${NC}"
        sleep 3
    else
        echo -e "\n${RED}❌ Task ${TASK_ID} 실패${NC}"
        exit 1
    fi
done

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 전체 워크플로우 완료!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
