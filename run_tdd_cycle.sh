#!/bin/bash

# ==============================================================================
# TDD Cycle Script v4.0 - Simple Executor
# main.sh로부터 3개 인자를 받아 TDD 사이클만 실행
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VALIDATE_SCRIPT="./validate.sh"
CODING_GUIDE_PATH="./CLAUDE.md"
MAX_RETRIES=3

# --- 입력 검증 ---
if [ "$#" -ne 3 ]; then
    echo -e "${RED}오류: 3개 인수 필요${NC}" >&2
    echo "사용법: $0 \"요구사항\" <테스트경로> <구현경로>" >&2
    exit 1
fi

TASK_DESCRIPTION=$1
TEST_FILE_PATH=$2
IMPLEMENTATION_FILE_PATH=$3

# --- 헬퍼 함수 ---
log_step() {
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
}

cleanup() {
    echo -e "\n${YELLOW}🧹 임시 파일 정리...${NC}"
    rm -rf tmp_prompts
}
trap cleanup EXIT
mkdir -p tmp_prompts

invoke_agent() {
    local agent_name=$1
    local prompt_file=$2
    local agent_file=".claude/agents/${agent_name}.md"

    if [ ! -f "$agent_file" ]; then
        echo -e "${RED}오류: ${agent_file} 없음${NC}" >&2
        return 1
    fi

    local model=$(grep '^model:' "$agent_file" | cut -d' ' -f2 | tr -d '\r')
    local provider=$(grep '^provider:' "$agent_file" | cut -d' ' -f2 | tr -d '\r')
    local provider_script="providers/${provider}.sh"

    if [ ! -f "$provider_script" ]; then
        echo -e "${RED}오류: ${provider_script} 없음${NC}" >&2
        return 1
    fi

    echo -e "🤖 ${agent_name} 호출 (${provider}, ${model})..." >&2
    "$provider_script" "$model" "$agent_file" "$prompt_file"
}

# --- 파일 준비 ---
mkdir -p "$(dirname "$TEST_FILE_PATH")"
mkdir -p "$(dirname "$IMPLEMENTATION_FILE_PATH")"
touch "$TEST_FILE_PATH"
touch "$IMPLEMENTATION_FILE_PATH"

log_step "🔥 TDD 시작: $TASK_DESCRIPTION"

# --- 🔴 RED ---
log_step "🔴 1. TEST-WRITER"
PROMPT_FILE="tmp_prompts/test_writer.txt"
{
    echo "# Task"
    echo "$TASK_DESCRIPTION"
    echo ""
    echo "# 현재 테스트 파일"
    cat "$TEST_FILE_PATH"
} > "$PROMPT_FILE"

TEST_CODE=$(invoke_agent test-writer "$PROMPT_FILE")

if [ -z "$(echo "$TEST_CODE" | tr -d '[:space:]')" ]; then
    echo -e "${RED}❌ 빈 응답${NC}"
    exit 1
fi

echo "$TEST_CODE" > "$TEST_FILE_PATH"

echo "RED 검증..."
if $VALIDATE_SCRIPT > /dev/null 2>&1; then
    echo -e "${RED}❌ 테스트가 실패해야 하는데 성공함${NC}"
    exit 1
fi
echo -e "${GREEN}✅ RED 확인${NC}"

# --- 🟢 GREEN ---
log_step "🟢 2. ENGINEER/DEBUGGER (최대 ${MAX_RETRIES}회)"
green_success=false

for ((i=1; i<=MAX_RETRIES; i++)); do
    echo -e "\n${YELLOW}--- 시도 #$i ---${NC}"

    if [ $i -eq 1 ]; then
        PROMPT_FILE="tmp_prompts/engineer.txt"
        {
            echo "# Task"
            echo "$TASK_DESCRIPTION"
            echo ""
            echo "# 테스트"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# 구현 파일"
            cat "$IMPLEMENTATION_FILE_PATH"
        } > "$PROMPT_FILE"
        IMPL_CODE=$(invoke_agent engineer "$PROMPT_FILE")
    else
        PROMPT_FILE="tmp_prompts/debugger.txt"
        {
            echo "# Goal"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# Problematic Code"
            cat "$IMPLEMENTATION_FILE_PATH"
            echo ""
            echo "# Error Log"
            echo "$last_error"
        } > "$PROMPT_FILE"
        IMPL_CODE=$(invoke_agent code-debugger "$PROMPT_FILE")
    fi

    if [ -z "$(echo "$IMPL_CODE" | tr -d '[:space:]')" ]; then
        last_error="빈 응답"
        continue
    fi

    echo "$IMPL_CODE" > "$IMPLEMENTATION_FILE_PATH"

    echo "GREEN 검증..."
    validation_output=$($VALIDATE_SCRIPT 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ GREEN 통과!${NC}"
        green_success=true
        break
    else
        echo -e "${RED}❌ 실패${NC}"
        last_error=$validation_output
        echo "$last_error" | head -n 20
    fi
done

if [ "$green_success" = false ]; then
    echo -e "${RED}❌ ${MAX_RETRIES}회 시도 실패${NC}"
    exit 1
fi

# --- 🔵 REFACTOR ---
log_step "🔵 3. REFACTORER"
PROMPT_FILE="tmp_prompts/refactorer.txt"
{
    echo "# 리팩토링 대상"
    cat "$IMPLEMENTATION_FILE_PATH"
} > "$PROMPT_FILE"

REFACTOR_RESULT=$(invoke_agent refactorer "$PROMPT_FILE")

if echo "$REFACTOR_RESULT" | grep -q "리팩토링 필요 없음"; then
    echo -e "${GREEN}✅ 리팩토링 불필요${NC}"
else
    REFACTORED=$(echo "$REFACTOR_RESULT" | awk '/### ✨ Refactored Code/,/### 📝 Changes Made/' | sed '1d;$d')

    if [ -n "$(echo "$REFACTORED" | tr -d '[:space:]')" ]; then
        echo "$REFACTORED" > "$IMPLEMENTATION_FILE_PATH"

        if ! $VALIDATE_SCRIPT; then
            echo -e "${RED}❌ 리팩토링 후 테스트 실패${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ 리팩토링 완료${NC}"
    fi
fi

# --- 🟡 AUDIT ---
log_step "🟡 4. AUDITOR"
PROMPT_FILE="tmp_prompts/auditor.txt"
{
    echo "# 검토 대상"
    cat "$IMPLEMENTATION_FILE_PATH"
    echo ""
    echo "# 가이드라인"
    cat "$CODING_GUIDE_PATH"
} > "$PROMPT_FILE"

AUDIT_RESULT=$(invoke_agent auditor "$PROMPT_FILE")
echo "$AUDIT_RESULT"

if echo "$AUDIT_RESULT" | grep -q "AUDIT FAILED"; then
    echo -e "${RED}❌ AUDIT 실패${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AUDIT 통과${NC}"

echo -e "${GREEN}✅ TDD 사이클 완료!${NC}"
