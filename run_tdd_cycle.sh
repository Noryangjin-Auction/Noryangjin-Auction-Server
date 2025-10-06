#!/bin/bash

# ==============================================================================
# TDD Cycle Script v8.0 - Agent-Driven File Structure
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
MAX_RETRIES=10

# --- 입력 검증 (v8.0: 2개 인수) ---
if [ "$#" -ne 2 ]; then
    echo -e "${RED}오류: 2개 인수 필요${NC}" >&2
    echo "사용법: $0 \"요구사항\" \"Task ID\"" >&2
    exit 1
fi

TASK_DESCRIPTION=$1
TASK_ID=$2

# 파일 경로는 에이전트 출력에서 추출
TEST_FILE_PATH=""
IMPLEMENTATION_FILE_PATH=""

# --- 헬퍼 함수 ---
log_step() {
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
}

cleanup() {
    echo -e "\n${YELLOW}🧹 임시 파일 정리...${NC}"
    rm -rf tmp_prompts
    rm -rf tmp_domain_backup
}
trap cleanup EXIT
mkdir -p tmp_prompts

# Task 시작 마커 생성 (새 파일 추적용)
touch tmp_prompts/task_start_marker

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

    # 2. 코드 블록만 추출 (개선된 로직)
    local cleaned=$(echo "$raw_output" | awk '
        /^```(java|kotlin|xml)?[[:space:]]*$/ {
            in_code = 1
            next
        }
        /^```[[:space:]]*$/ && in_code {
            in_code = 0
            next
        }
        in_code {
            print
        }
    ')

    # 3. 추출 실패 시 원본 반환 (폴백)
    if [ -z "$(echo "$cleaned" | tr -d '[:space:]')" ]; then
        echo -e "${YELLOW}WARNING: ${agent_name} - 코드 블록을 찾을 수 없어 원본 사용${NC}" >&2
        cleaned="$raw_output"
    fi

    # 4. 잘못된 패키지명 자동 수정
    if echo "$cleaned" | grep -q "com\.noryangjinauctioneer\|com\.noryangfin"; then
        echo -e "${YELLOW}WARNING: ${agent_name} used wrong package. Auto-fixing...${NC}" >&2
        cleaned=$(echo "$cleaned" | sed 's/com\.noryangjinauctioneer/com.noryangjin.auction.server/g; s/com\.noryangfin/com.noryangjin/g')
    fi

    echo "$cleaned"
}

parse_multifile() {
    local output_content="$1"
    local output_file="tmp_prompts/multifile_temp.txt"

    echo "$output_content" > "$output_file"

    python3 - "$output_file" <<'PYPARSESCRIPT'
import sys
import os

input_file = sys.argv[1]

with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

# 파일 경계로 분할
if '===FILE_BOUNDARY===' in content:
    blocks = content.split('===FILE_BOUNDARY===')
elif '---' in content:
    blocks = content.split('---')
else:
    blocks = [content]

file_count = 0

for i, block in enumerate(blocks):
    block = block.strip()

    if not block or not block.startswith('path:'):
        continue

    lines = block.split('\n')

    # 파일 경로 추출
    filepath = lines[0].replace('path:', '').strip()
    filepath = filepath.strip('"').strip("'")
    filepath = filepath.replace('com/noryangjinauctioneer', 'com/noryangjin/auction/server')
    filepath = filepath.replace('com.noryangjinauctioneer', 'com/noryangjin/auction/server')

    # 코드 블록 추출
    code_lines = []
    has_code_fence = any(line.strip().startswith('```') for line in lines[1:])

    if has_code_fence:
        in_code_block = False
        for line in lines[1:]:
            if line.strip().startswith('```'):
                if not in_code_block:
                    in_code_block = True
                    continue
                else:
                    break
            if in_code_block:
                code_lines.append(line)
    else:
        code_lines = lines[1:]

    if code_lines:
        dir_path = os.path.dirname(filepath)
        if dir_path:
            os.makedirs(dir_path, exist_ok=True)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(code_lines))

        file_count += 1
        print(f"✓ {filepath}", file=sys.stderr)

if file_count == 0:
    sys.exit(1)

PYPARSESCRIPT

    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "[ERROR] parse_multifile failed" >&2
        return 1
    fi
}

extract_file_path() {
    local content=$1
    local pattern=$2

    if [[ "$pattern" == "!"* ]]; then
        echo "$content" | grep "^path:" | grep -v "${pattern:1}" | head -1 | sed 's/path:[[:space:]]*//' | tr -d '"'"'"
    else
        echo "$content" | grep "^path:" | grep "$pattern" | head -1 | sed 's/path:[[:space:]]*//' | tr -d '"'"'"
    fi
}

get_domain_from_task_id() {
    local task_id=$1
    local domain_num=$(echo "$task_id" | cut -d'-' -f1)

    case $domain_num in
        1) echo "user" ;;
        2) echo "product" ;;
        3) echo "auction" ;;
        *) echo "common" ;;
    esac
}

backup_domain() {
    local domain=$(get_domain_from_task_id "$TASK_ID")
    local domain_path="src/main/java/com/noryangjin/auction/server/$domain"

    echo -e "${YELLOW}📦 도메인 백업: $domain${NC}"

    if [ -d "$domain_path" ]; then
        mkdir -p tmp_domain_backup
        cp -r "$domain_path" "tmp_domain_backup/${domain}"
        rm -rf "$domain_path"
        echo -e "${BLUE}  → 백업 및 격리 완료${NC}"
    else
        echo -e "${BLUE}  → 백업할 도메인 없음${NC}"
    fi
}

restore_domain() {
    local domain=$(get_domain_from_task_id "$TASK_ID")

    if [ -d "tmp_domain_backup/${domain}" ]; then
        echo -e "${YELLOW}📦 도메인 복원: $domain${NC}"
        rm -rf "src/main/java/com/noryangjin/auction/server/$domain"
        cp -r "tmp_domain_backup/${domain}" "src/main/java/com/noryangjin/auction/server/$domain"
        echo -e "${BLUE}  → 복원 완료${NC}"
    fi
}

# --- 파일 준비 ---
log_step "🔥 TDD 시작: Task $TASK_ID"
echo -e "${BLUE}요구사항: $TASK_DESCRIPTION${NC}"

# --- 🔴 RED ---
log_step "🔴 1. TEST-WRITER"

# 1. 도메인 백업 (RED 격리)
backup_domain

# 2. 테스트 작성
PROMPT_FILE="tmp_prompts/test_writer.txt"
{
    echo "# Task"
    echo "$TASK_DESCRIPTION"
    echo ""
    echo "# Instructions"
    echo "Create a comprehensive test for this requirement."
    echo "Use domain-driven package structure (e.g., user/domain/, product/api/)."
    echo "Output in Multi-file format with path specification."
    echo ""
    echo "Example output format:"
    echo "===FILE_BOUNDARY==="
    echo "path: src/test/java/com/noryangjin/auction/server/user/domain/UserTest.java"
    echo '```java'
    echo "package com.noryangjin.auction.server.user.domain;"
    echo ""
    echo "@SpringBootTest"
    echo "class UserTest {"
    echo "    @Test"
    echo "    void testExample() {"
    echo "        // test code"
    echo "    }"
    echo "}"
    echo '```'
    echo ""
    echo "Make sure to:"
    echo "- Use correct package structure based on domain"
    echo "- Include all necessary imports"
    echo "- Write clear, specific test cases"
    echo "- DO NOT write implementation code, ONLY test code"
} > "$PROMPT_FILE"

TEST_CODE=$(invoke_agent test-writer "$PROMPT_FILE")
TEST_CODE=$(validate_and_clean_output "test-writer" "$TEST_CODE") || {
    echo -e "${RED}❌ test-writer 응답 검증 실패${NC}"
    restore_domain
    exit 1
}

echo "$TEST_CODE" > tmp_prompts/test_writer_output.txt

# 3. Multi-file 파싱 및 경로 추출 (Claude/Gemini 호환)
if echo "$TEST_CODE" | grep -qE "(===FILE_BOUNDARY===|^---$)" && echo "$TEST_CODE" | grep -q "^path:"; then
    # Claude 방식
    echo -e "${BLUE}📦 Multi-file 테스트 생성 (Claude)${NC}"
    parse_multifile "$TEST_CODE"

    TEST_FILE_PATH=$(extract_file_path "$TEST_CODE" "Test.java")

    if [ -z "$TEST_FILE_PATH" ]; then
        echo -e "${RED}❌ 테스트 파일 경로를 찾을 수 없음${NC}"
        restore_domain
        exit 1
    fi

    echo -e "${GREEN}📍 테스트 파일: ${TEST_FILE_PATH}${NC}"
else
    # Gemini 방식
    echo -e "${YELLOW}📄 Single-file 테스트 생성 (Gemini) - 경로 추론${NC}"

    domain=$(get_domain_from_task_id "$TASK_ID")
    class_name=$(echo "$TEST_CODE" | grep -oP '(?<=class\s)\w+(?=\s*\{)' | head -1)

    if [ -z "$class_name" ]; then
        class_name="${domain^}Test"
        echo -e "${YELLOW}⚠️  클래스명 추출 실패, 기본값 사용: ${class_name}${NC}"
    fi

    TEST_FILE_PATH="src/test/java/com/noryangjin/auction/server/${domain}/domain/${class_name}.java"

    echo -e "${BLUE}📍 추론된 테스트 파일: ${TEST_FILE_PATH}${NC}"

    mkdir -p "$(dirname "$TEST_FILE_PATH")"
    echo "$TEST_CODE" > "$TEST_FILE_PATH"
fi

if [ -f "$TEST_FILE_PATH" ]; then
    echo -e "${GREEN}✓ 파일 생성 확인: ${TEST_FILE_PATH}${NC}"
else
    echo -e "${RED}❌ 파일이 생성되지 않음!${NC}"
    restore_domain
    exit 1
fi

# 4. RED 검증
echo -e "${CYAN}RED 검증...${NC}"
if $VALIDATE_SCRIPT > /dev/null 2>&1; then
    echo -e "${RED}❌ 테스트가 실패해야 하는데 성공함${NC}"
    restore_domain
    exit 1
fi
echo -e "${GREEN}✅ RED 확인 (테스트 실패)${NC}"

# 5. 도메인 복원
restore_domain

# --- 🟢 GREEN ---
log_step "🟢 2. ENGINEER/DEBUGGER (최대 ${MAX_RETRIES}회)"
green_success=false
last_error=""

for ((i=1; i<=MAX_RETRIES; i++)); do
    echo -e "\n${YELLOW}--- 시도 #$i ---${NC}"

    if [ $i -eq 1 ]; then
        PROMPT_FILE="tmp_prompts/engineer.txt"
        {
            echo "# Task"
            echo "$TASK_DESCRIPTION"
            echo ""
            echo "# Test"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# Instructions"
            echo "Implement the minimum code to pass the test."
            echo "Create all necessary files (entities, DTOs, controllers, repositories)."
            echo "Use domain-driven package structure."
            echo "Output in Multi-file format."
            echo ""
            echo "Example output format:"
            echo "===FILE_BOUNDARY==="
            echo "path: src/main/java/com/noryangjin/auction/server/user/domain/User.java"
            echo '```java'
            echo "package com.noryangjin.auction.server.user.domain;"
            echo "// implementation code"
            echo '```'
            echo ""
            echo "===FILE_BOUNDARY==="
            echo "path: src/main/java/com/noryangjin/auction/server/user/api/UserController.java"
            echo '```java'
            echo "// controller code"
            echo '```'
        } > "$PROMPT_FILE"

        IMPL_CODE=$(invoke_agent engineer "$PROMPT_FILE")
    else
        echo -e "${CYAN}🔍 Debugger 분석...${NC}"

        DEBUGGER_PROMPT="tmp_prompts/debugger.txt"
        {
            echo "# Goal"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# Problematic Code"
            if [ -n "$IMPLEMENTATION_FILE_PATH" ] && [ -f "$IMPLEMENTATION_FILE_PATH" ]; then
                cat "$IMPLEMENTATION_FILE_PATH"
            else
                echo "// 구현 파일을 찾을 수 없음"
            fi
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

        ENGINEER_RETRY="tmp_prompts/engineer_retry.txt"
        {
            echo "# Task"
            echo "$TASK_DESCRIPTION"
            echo ""
            echo "# 테스트"
            cat "$TEST_FILE_PATH"
            echo ""
            echo "# 이전 시도 (실패)"
            if [ -n "$IMPLEMENTATION_FILE_PATH" ] && [ -f "$IMPLEMENTATION_FILE_PATH" ]; then
                cat "$IMPLEMENTATION_FILE_PATH"
            fi
            echo ""
            echo "# Debugger 진단"
            echo "$DEBUG_REPORT"
            echo ""
            echo "위 진단을 바탕으로 올바른 코드를 Multi-file 형식으로 작성하세요."
        } > "$ENGINEER_RETRY"

        IMPL_CODE=$(invoke_agent engineer "$ENGINEER_RETRY")
    fi

    IMPL_CODE=$(validate_and_clean_output "engineer" "$IMPL_CODE") || {
        last_error="Engineer 응답 검증 실패"
        continue
    }

    # Multi-file 파싱 및 경로 추출
    if echo "$IMPL_CODE" | grep -qE "(===FILE_BOUNDARY===|^---$)" && echo "$IMPL_CODE" | grep -q "^path:"; then
        # Claude 방식
        echo -e "${BLUE}📦 Multi-file 구현 (Claude)${NC}"
        parse_multifile "$IMPL_CODE"

        IMPLEMENTATION_FILE_PATH=$(extract_file_path "$IMPL_CODE" "!Test.java")

        if [ -z "$IMPLEMENTATION_FILE_PATH" ]; then
            echo -e "${YELLOW}⚠️  메인 구현 파일 경로를 찾을 수 없음${NC}"
            IMPLEMENTATION_FILE_PATH=$(echo "$IMPL_CODE" | grep "^path:" | grep -v "Test.java" | head -1 | sed 's/path:[[:space:]]*//' | tr -d '"'"'")
        fi

        if [ -n "$IMPLEMENTATION_FILE_PATH" ]; then
            echo -e "${GREEN}📍 구현 파일: ${IMPLEMENTATION_FILE_PATH}${NC}"
        fi
    else
        # Gemini 방식
        echo -e "${YELLOW}📄 Single-file 구현 (Gemini) - 경로 추론${NC}"

        domain=$(get_domain_from_task_id "$TASK_ID")
        local class_name=$(echo "$IMPL_CODE" | awk 'match($0, /public\s+(class|interface|enum)\s+(\w+)/, a) {print a[2]}' | head -1)

        if [ -z "$class_name" ]; then
            class_name=$(echo "$domain" | sed 's/./\u&/')
            echo -e "${YELLOW}⚠️  클래스명 추출 실패, 기본값 사용: ${class_name}${NC}"
        fi

        IMPLEMENTATION_FILE_PATH="src/main/java/com/noryangjin/auction/server/${domain}/domain/${class_name}.java"

        echo -e "${BLUE}📍 추론된 구현 파일: ${IMPLEMENTATION_FILE_PATH}${NC}"

        mkdir -p "$(dirname "$IMPLEMENTATION_FILE_PATH")"
        echo "$IMPL_CODE" > "$IMPLEMENTATION_FILE_PATH"
    fi

    echo -e "${CYAN}GREEN 검증...${NC}"
    if ! validation_output=$($VALIDATE_SCRIPT 2>&1); then
        echo -e "${RED}❌ 실패${NC}"
        last_error=$validation_output
        echo "$last_error" > tmp_prompts/full_error.log
        echo "$last_error" | head -n 30
    else
        echo -e "${GREEN}✅ GREEN 통과!${NC}"
        green_success=true
        break
    fi
done

if [ "$green_success" = false ]; then
    echo -e "${RED}❌ ${MAX_RETRIES}회 시도 후 실패${NC}"
    exit 1
fi

# --- 🔵 REFACTOR ---
log_step "🔵 3. REFACTORER"

CREATED_FILES=$(find src/main/java/com/noryangjin/auction/server -name "*.java" -newer tmp_prompts/task_start_marker 2>/dev/null)

if [ -z "$CREATED_FILES" ]; then
    echo -e "${YELLOW}⚠️  새로 생성된 파일이 없음${NC}"
    CREATED_FILES="$IMPLEMENTATION_FILE_PATH"
fi

PROMPT_FILE="tmp_prompts/refactorer.txt"
{
    echo "# 리팩토링 대상 파일들"
    echo ""
    echo "$CREATED_FILES" | while read file; do
        if [ -f "$file" ]; then
            echo "## $file"
            cat "$file"
            echo ""
        fi
    done
} > "$PROMPT_FILE"

REFACTOR_RESULT=$(invoke_agent refactorer "$PROMPT_FILE")

if echo "$REFACTOR_RESULT" | grep -qi "리팩토링 필요 없음\|no refactoring needed"; then
    echo -e "${GREEN}✅ 리팩토링 불필요${NC}"
else
    if echo "$REFACTOR_RESULT" | grep -qE "(===FILE_BOUNDARY===|^---$)" && echo "$REFACTOR_RESULT" | grep -q "^path:"; then
        echo -e "${BLUE}📦 Multi-file 리팩토링${NC}"

        REFACTORED=$(validate_and_clean_output "refactorer" "$REFACTOR_RESULT") || {
            echo -e "${YELLOW}⚠️  리팩토링 출력 검증 실패 - 원본 유지${NC}"
        }

        if [ -n "$REFACTORED" ]; then
            parse_multifile "$REFACTORED"

            echo -e "${CYAN}리팩토링 후 검증...${NC}"
            if ! validation_output=$($VALIDATE_SCRIPT 2>&1); then
                echo -e "${RED}❌ 리팩토링 후 테스트 실패${NC}"
                echo "$validation_output"
                exit 1
            fi
            echo -e "${GREEN}✅ 리팩토링 완료${NC}"
        fi
    else
        REFACTORED=$(echo "$REFACTOR_RESULT" | awk '/### ✨ Refactored Code/,/### 📝 Changes Made/' | sed '1d;$d')

        if [ -n "$(echo "$REFACTORED" | tr -d '[:space:]')" ]; then
            REFACTORED=$(validate_and_clean_output "refactorer" "$REFACTORED") || {
                echo -e "${YELLOW}⚠️  리팩토링 출력 검증 실패 - 원본 유지${NC}"
            }

            if [ -n "$REFACTORED" ] && [ -f "$IMPLEMENTATION_FILE_PATH" ]; then
                echo "$REFACTORED" > "$IMPLEMENTATION_FILE_PATH"

                echo -e "${CYAN}리팩토링 후 검증...${NC}"
                if ! validation_output=$($VALIDATE_SCRIPT 2>&1); then
                    echo -e "${RED}❌ 리팩토링 후 테스트 실패${NC}"
                    echo "$validation_output"
                    exit 1
                fi
                echo -e "${GREEN}✅ 리팩토링 완료${NC}"
            fi
        fi
    fi
fi

# --- 🟡 AUDIT ---
log_step "🟡 4. AUDITOR"

PROMPT_FILE="tmp_prompts/auditor.txt"
{
    echo "# 검토 대상 파일들"
    echo ""
    echo "$CREATED_FILES" | while read file; do
        if [ -f "$file" ]; then
            echo "## $file"
            cat "$file"
            echo ""
        fi
    done
    echo ""
    echo "# 코딩 가이드라인"
    cat "$CODING_GUIDE_PATH"
} > "$PROMPT_FILE"

AUDIT_RESULT=$(invoke_agent auditor "$PROMPT_FILE")
echo "$AUDIT_RESULT"

if echo "$AUDIT_RESULT" | grep -qi "AUDIT FAILED\|감사 실패"; then
    echo -e "${RED}❌ AUDIT 실패${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AUDIT 통과${NC}"

echo -e "\n${GREEN}🎉 TDD 사이클 완료! (Task: $TASK_ID)${NC}"
