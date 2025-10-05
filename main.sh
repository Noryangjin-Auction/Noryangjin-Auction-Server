#!/bin/bash

# ==============================================================================
# Master Orchestrator (main.sh) v4.3 - Final Syntax Fix
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
    # (이전과 동일한, 안정적인 파싱 로직)
    local task_block=$(awk '/- \[ \] \*\*Task/ {found=1; block=$0; next} found && /^  - / {block=block"\n"$0} found && /^- \[/ {exit} found && /^$/ {exit} END {if (found) print block}' "$PLAN_FILE")
    if [ -z "$task_block" ]; then return 1; fi
    echo "$task_block"
}

mark_task_complete() {
    local task_id=$1
    local escaped_id=$(echo "$task_id" | sed 's/[-.]/\\&/g')
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^- \[ \] \*\*Task ${escaped_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    else
        sed -i "s/^- \[ \] \*\*Task ${escaped_id}:/- [x] **Task ${task_id}:/" "$PLAN_FILE"
    fi
    echo -e "${GREEN}✅ Task ${task_id} 완료 표시${NC}"
}

# --- 메인 루프 ---
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       TDD 자동화 워크플로우 v4.3                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

while true; do
    echo -e "\n${BLUE}📋 다음 Task를 찾는 중...${NC}"
    if ! TASK_BLOCK=$(find_next_task); then
        echo -e "${GREEN}🎉 모든 Task 완료!${NC}"
        break
    fi

    TASK_ID=$(echo "$TASK_BLOCK" | grep -o 'Task [0-9-]*' | head -1 | cut -d' ' -f2)
    REQUIREMENT=$(echo "$TASK_BLOCK" | grep '요구사항:' | sed 's/.*요구사항: *//' | sed -e 's/^"//' -e 's/"$//')
    TEST_DESC=$(echo "$TASK_BLOCK" | grep '테스트:' | sed 's/.*테스트: *//')
    TARGET=$(echo "$TASK_BLOCK" | grep '구현 대상:' | sed 's/.*구현 대상: *`\([^`]*\)`:.*/\1/')

    echo -e "${YELLOW}🎯 Task ${TASK_ID}: ${REQUIREMENT}${NC}"
    echo -e "   📂 대상: ${TARGET}"

    if [[ "$TEST_DESC" == "없음"* ]]; then
        echo -e "${BLUE}ℹ️  구조 정의 Task (테스트 불필요) - AI가 직접 생성합니다.${NC}"
        IMPL_PATH="${SRC_PREFIX}/${TARGET}"
        mkdir -p "$(dirname "$IMPL_PATH")"
        mkdir -p tmp_prompts

        # engineer에게 파일 생성을 직접 요청
        PROMPT_FILE="tmp_prompts/direct_creation.txt"
        {
            echo "# Task"
            echo "Create file: '${IMPL_PATH}'"
            echo "Requirement: ${REQUIREMENT}"
        } > "$PROMPT_FILE"

        AGENT_NAME="engineer"
        AGENT_FILE=".claude/agents/${AGENT_NAME}.md"
        MODEL=$(grep '^model:' "$AGENT_FILE" | cut -d' ' -f2 | tr -d '\r')
        PROVIDER=$(grep '^provider:' "$AGENT_FILE" | cut -d' ' -f2 | tr -d '\r')
        PROVIDER_SCRIPT="providers/${PROVIDER}.sh"

        echo -e "🤖 ${AGENT_NAME} 호출..." >&2
        GENERATED_CODE=$("$PROVIDER_SCRIPT" "$MODEL" "$AGENT_FILE" "$PROMPT_FILE")

        if [ -z "$(echo "$GENERATED_CODE" | tr -d '[:space:]')" ]; then
            echo -e "${RED}❌ Engineer가 빈 응답을 반환함${NC}"
            exit 1
        fi

        # Multi-file 지원 (===FILE_BOUNDARY=== 또는 --- 지원)
        if echo "$GENERATED_CODE" | grep -q "===FILE_BOUNDARY===" || (echo "$GENERATED_CODE" | grep -q "^---" && echo "$GENERATED_CODE" | grep -q "^path:"); then
            echo -e "${BLUE}📦 Multi-file 응답 감지${NC}"
            # Python 파싱 스크립트 inline 실행
            MULTIFILE_TEMP="tmp_prompts/multifile_temp.txt"
            echo "$GENERATED_CODE" > "$MULTIFILE_TEMP"

            python3 - "$MULTIFILE_TEMP" <<'PYPARSESCRIPT'
import sys
import os
import re

with open(sys.argv[1], 'r') as f:
    content = f.read()

# ===FILE_BOUNDARY=== 또는 --- 로 구분된 블록 분할 (하위호환성)
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

    # ```java 또는 ``` 로 감싸진 코드 추출
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
        else
            echo -e "${BLUE}📄 Single-file 응답${NC}"
            echo "$GENERATED_CODE" | sed '1d;$d' > "$IMPL_PATH"
            echo -e "${GREEN}✓ 파일 생성 완료: ${IMPL_PATH}${NC}"
        fi

        # 최소한 컴파일 검증
        echo -e "${YELLOW}🔍 컴파일 검증 중...${NC}"
        if ! ./gradlew compileJava 2>&1; then
            echo -e "${RED}❌ 컴파일 실패 - Task를 완료할 수 없습니다${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ 컴파일 성공${NC}"

        # Task 완료 표시 및 커밋
        mark_task_complete "$TASK_ID"

        if ! git add . || ! git commit -m "feat(task-${TASK_ID}): ${REQUIREMENT}"; then
            echo -e "${RED}❌ Git 커밋 실패 - 체크박스 롤백${NC}"
            # 체크박스 원복
            local escaped_id=$(echo "$TASK_ID" | sed 's/[-.]/\\&/g')
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^- \[x\] \*\*Task ${escaped_id}:/- [ ] **Task ${task_id}:/" "$PLAN_FILE"
            else
                sed -i "s/^- \[x\] \*\*Task ${escaped_id}:/- [ ] **Task ${task_id}:/" "$PLAN_FILE"
            fi
            exit 1
        fi

        echo -e "\n${YELLOW}⏭️  3초 후 다음 Task를 시작합니다...${NC}"
        sleep 3
        continue
    fi

    # TDD가 필요한 일반 Task
    IMPL_PATH="${SRC_PREFIX}/${TARGET}"
    TEST_PATH="${TEST_SRC_PREFIX}/$(echo "$TARGET" | sed 's/\.java$/Test.java/')"
    echo -e "   🧪 테스트: ${TEST_DESC}"
    echo ""

    if "$TDD_SCRIPT" "$REQUIREMENT" "$TEST_PATH" "$IMPL_PATH"; then
        echo -e "\n${GREEN}✅ Task ${TASK_ID} 성공!${NC}"
        mark_task_complete "$TASK_ID"

        if ! git add . || ! git commit -m "feat(task-${TASK_ID}): ${REQUIREMENT}"; then
            echo -e "${RED}❌ Git 커밋 실패 - 체크박스 롤백${NC}"
            # 체크박스 원복
            local escaped_id=$(echo "$TASK_ID" | sed 's/[-.]/\\&/g')
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^- \[x\] \*\*Task ${escaped_id}:/- [ ] **Task ${task_id}:/" "$PLAN_FILE"
            else
                sed -i "s/^- \[x\] \*\*Task ${escaped_id}:/- [ ] **Task ${task_id}:/" "$PLAN_FILE"
            fi
            exit 1
        fi

        echo -e "${CYAN}✓ Task ${TASK_ID} 완료 및 커밋됨${NC}"
        echo -e "\n${YELLOW}⏭️  3초 후 다음 Task...${NC}"
        sleep 3
    else
        echo -e "\n${RED}❌ Task ${TASK_ID} 실패${NC}"
        exit 1
    fi
done
