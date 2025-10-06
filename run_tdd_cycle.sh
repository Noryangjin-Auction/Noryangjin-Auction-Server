#!/bin/bash

# ==============================================================================
# TDD Cycle Script v6.0 - State Isolation & Smart Skip
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
    rm -f "${IMPLEMENTATION_FILE_PATH}.tdd_backup"
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

validate_and_clean_output() {
    local agent_name=$1
    local raw_output=$2

    # 1. 빈 응답 체크
    if [ -z "$(echo "$raw_output" | tr -d '[:space:]')" ]; then
        echo -e "${RED}ERROR: ${agent_name} returned empty response${NC}" >&2
        return 1
    fi

    # 2. 마크다운 펜스 제거
    local cleaned=$(echo "$raw_output" | sed '/^```[a-z]*$/d; /^```$/d')

    # 3. 잘못된 패키지명 자동 수정
    if echo "$cleaned" | grep -q "com\.noryangjinauctioneer\|com\.noryangfin"; then
        echo -e "${YELLOW}WARNING: ${agent_name} used wrong package. Auto-fixing...${NC}" >&2
        cleaned=$(echo "$cleaned" | sed 's/com\.noryangjinauctioneer/com.noryangjin.auction.server/g; s/com\.noryangfin/com.noryangjin/g')
    fi

    echo "$cleaned"
}

parse_multifile() {
    local output_content=$1
    local output_file="tmp_prompts/multifile_temp.txt"
    echo "$output_content" > "$output_file"

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

check_if_already_implemented() {
    echo -e "${CYAN}🔍 기존 구현 상태 확인...${NC}"

    # 테스트가 이미 존재하고 통과하는지 확인
    if [ -f "$TEST_FILE_PATH" ] && [ -s "$TEST_FILE_PATH" ]; then
        if $VALIDATE_SCRIPT > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 이미 구현되어 있음 - 스킵${NC}"
            return 0
        fi
    fi

    return 1
}

isolate_implementation() {
    echo -e "${YELLOW}📦 구현 코드 임시 격리 (RED 단계)${NC}"

    # 백업 생성
    if [ -f "$IMPLEMENTATION_FILE_PATH" ]; then
        cp "$IMPLEMENTATION_FILE_PATH" "${IMPLEMENTATION_FILE_PATH}.tdd_backup"
    fi

    # 패키지와 클래스명 추출
    local package_path=$(dirname "$IMPLEMENTATION_FILE_PATH" | sed 's|src/main/java/||')
    local package_name=$(echo "$package_path" | tr '/' '.')
    local class_name=$(basename "$IMPLEMENTATION_FILE_PATH" .java)

    # 빈 클래스로 초기화
    mkdir -p "$(dirname "$IMPLEMENTATION_FILE_PATH")"
    cat > "$IMPLEMENTATION_FILE_PATH" << EOF
package ${package_name};

public class ${class_name} {
    // RED 단계: 테스트가 실패하도록 빈 구현
}
EOF

    echo -e "${BLUE}  → 빈 클래스로 초기화: ${class_name}${NC}"
}

restore_implementation() {
    if [ -f "${IMPLEMENTATION_FILE_PATH}.tdd_backup" ]; then
        echo -e "${YELLOW}📦 구현 코드 복원${NC}"
        mv "${IMPLEMENTATION_FILE_PATH}.tdd_backup" "$IMPLEMENTATION_FILE_PATH"
    fi
}

# --- 파일 준비 ---
mkdir -p "$(dirname "$TEST_FILE_PATH")"
mkdir -p "$(dirname "$IMPLEMENTATION_FILE_PATH")"

log_step "🔥 TDD 시작: $TASK_DESCRIPTION"

# --- 사전 체크: 이미 구현되었는가? ---
if check_if_already_implemented; then
    echo -e "${GREEN}🎉 Task 이미 완료됨${NC}"
    exit 0
fi

# --- 🔴 RED ---
log_step "🔴 1. TEST-WRITER"

# 1. 구현 코드 격리
isolate_implementation

# 2. 테스트 작성
PROMPT_FILE="tmp_prompts/test_writer.txt"
{
    echo "# Task"
    echo "$TASK_DESCRIPTION"
    echo ""
    echo "# 현재 테스트 파일"
    if [ -f "$TEST_FILE_PATH" ]; then
        cat "$TEST_FILE_PATH"
    else
        echo "// 새 테스트 파일"
    fi
} > "$PROMPT_FILE"

TEST_CODE=$(invoke_agent test-writer "$PROMPT_FILE")
TEST_CODE=$(validate_and_clean_output "test-writer" "$TEST_CODE") || exit 1

echo "$TEST_CODE" > "$TEST_FILE_PATH"

# 3. RED 검증
echo "RED 검증..."
if $VALIDATE_SCRIPT > /dev/null 2>&1; then
    echo -e "${RED}❌ 테스트가 실패해야 하는데 성공함${NC}"
    restore_implementation
    exit 1
fi
echo -e "${GREEN}✅ RED 확인 (테스트 실패)${NC}"

# 4. 구현 코드 복원
restore_implementation

# --- 🟢 GREEN ---
log_step "🟢 2. ENGINEER/DEBUGGER (최대 ${MAX_RETRIES}회)"
green_success=false
last_error=""

for ((i=1; i<=MAX_RETRIES; i++)); do
    echo -e "\n${YELLOW}--- 시도 #$i ---${NC}"

    if [ $i -eq 1 ]; then
        # 첫 시도: Engineer
        PROMPT_FILE="tmp_prompts/engineer.txt"
        {
            echo "# Task"
            echo "$TASK_DESCRIPTION"
            echo ""
            echo "# 테스트"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# 구현 파일"
            if [ -f "$IMPLEMENTATION_FILE_PATH" ]; then
                cat "$IMPLEMENTATION_FILE_PATH"
            else
                echo "// 새 파일"
            fi
        } > "$PROMPT_FILE"

        IMPL_CODE=$(invoke_agent engineer "$PROMPT_FILE")
    else
        # 재시도: Debugger 분석 → Engineer 재구현
        echo -e "${CYAN}🔍 Debugger 분석...${NC}"

        DEBUGGER_PROMPT="tmp_prompts/debugger.txt"
        {
            echo "# Goal"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# Problematic Code"
            cat "$IMPLEMENTATION_FILE_PATH"
            echo ""
            echo "# Error Log"
            echo "$last_error"
        } > "$DEBUGGER_PROMPT"

        DEBUG_REPORT=$(invoke_agent code-debugger "$DEBUGGER_PROMPT")

        if [ -z "$(echo "$DEBUG_REPORT" | tr -d '[:space:]')" ]; then
            last_error="Debugger 빈 응답"
            continue
        fi

        echo -e "${CYAN}📋 Debugger 리포트:${NC}"
        echo "$DEBUG_REPORT" | head -n 30

        # Engineer에게 피드백 전달
        ENGINEER_RETRY="tmp_prompts/engineer_retry.txt"
        {
            echo "# Task"
            echo "$TASK_DESCRIPTION"
            echo ""
            echo "# 테스트"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# 이전 시도 (실패)"
            cat "$IMPLEMENTATION_FILE_PATH"
            echo ""
            echo "# Debugger 진단"
            echo "$DEBUG_REPORT"
            echo ""
            echo "위 진단을 바탕으로 올바른 코드를 작성하세요."
        } > "$ENGINEER_RETRY"

        IMPL_CODE=$(invoke_agent engineer "$ENGINEER_RETRY")
    fi

    IMPL_CODE=$(validate_and_clean_output "engineer" "$IMPL_CODE") || {
        last_error="Engineer 응답 검증 실패"
        continue
    }

    # Multi-file 지원
    if echo "$IMPL_CODE" | grep -qE "(===FILE_BOUNDARY===|^---$)" && echo "$IMPL_CODE" | grep -q "^path:"; then
        echo -e "${BLUE}📦 Multi-file${NC}"
        parse_multifile "$IMPL_CODE"
    else
        echo -e "${BLUE}📄 Single-file${NC}"
        echo "$IMPL_CODE" > "$IMPLEMENTATION_FILE_PATH"
    fi

    echo "GREEN 검증..."
    if ! validation_output=$($VALIDATE_SCRIPT 2>&1); then
        echo -e "${RED}❌ 실패${NC}"
        last_error=$validation_output
        echo "$last_error" > full_error.log
        echo "$last_error" | head -n 30
    else
        echo -e "${GREEN}✅ GREEN 통과!${NC}"
        green_success=true
        break
    fi
done

if [ "$green_success" = false ]; then
    echo -e "${RED}❌ ${MAX_RETRIES}회 실패${NC}"
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
        REFACTORED=$(validate_and_clean_output "refactorer" "$REFACTORED") || {
            echo -e "${YELLOW}⚠️  리팩토링 출력 검증 실패 - 원본 유지${NC}"
        }

        if [ -n "$REFACTORED" ]; then
            echo "$REFACTORED" > "$IMPLEMENTATION_FILE_PATH"

            if ! validation_output=$($VALIDATE_SCRIPT 2>&1); then
                echo -e "${RED}❌ 리팩토링 후 테스트 실패${NC}"
                echo "$validation_output"
                exit 1
            fi
            echo -e "${GREEN}✅ 리팩토링 완료${NC}"
        fi
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
