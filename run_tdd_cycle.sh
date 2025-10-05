#!/bin/bash

# ==============================================================================
# TDD Cycle Master Script (run_tdd_cycle.sh) v5.0 - Task-Based Execution
#
# PLAN.md 기반으로 Task를 직접 실행합니다. Planner 에이전트를 제거하고
# PLAN.md를 실행 가능한 명세서로 사용합니다.
# ==============================================================================

# --- 기본 설정 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PLAN_FILE="./PLAN.md"
VALIDATE_SCRIPT="./validate.sh"
CODING_GUIDE_PATH="./CLAUDE.md"
MAX_RETRIES=3

# --- 입력값 검증 ---
if [ "$#" -ne 1 ]; then
    echo -e "${RED}오류: Task ID가 필요합니다.${NC}" >&2
    echo "사용법: $0 <Task ID>" >&2
    echo "예시: $0 2-2-5" >&2
    exit 1
fi

TASK_ID=$1

# --- PLAN.md에서 Task 정보 추출 ---
parse_task_from_plan() {
    local task_id=$1

    if [ ! -f "$PLAN_FILE" ]; then
        echo -e "${RED}오류: PLAN.md 파일을 찾을 수 없습니다.${NC}" >&2
        exit 1
    fi

    # Task 블록 추출 (Task ID부터 다음 Task 또는 빈 줄까지)
    local task_block=$(awk "/^- \[ \] \*\*Task ${task_id}:/,/^- \[ \]|^$/" "$PLAN_FILE" | head -n -1)

    if [ -z "$task_block" ]; then
        echo -e "${RED}오류: Task ${task_id}를 PLAN.md에서 찾을 수 없습니다.${NC}" >&2
        exit 1
    fi

    # 요구사항 추출
    local requirement=$(echo "$task_block" | grep -o '요구사항: "[^"]*"' | cut -d'"' -f2)

    # 테스트 설명 추출
    local test_desc=$(echo "$task_block" | grep -o '테스트: "[^"]*"' | cut -d'"' -f2)

    # 구현 대상 파일 추출
    local target_file=$(echo "$task_block" | grep -o '구현 대상: `[^`]*`' | cut -d'`' -f2)

    if [ -z "$requirement" ]; then
        echo -e "${RED}오류: Task ${task_id}의 요구사항을 찾을 수 없습니다.${NC}" >&2
        exit 1
    fi

    # 테스트가 "없음"인 경우 처리
    if [ "$test_desc" = "없음" ] || [ -z "$test_desc" ]; then
        echo -e "${YELLOW}ℹ️  Task ${task_id}는 테스트가 필요 없는 구조 정의 태스크입니다.${NC}"
        echo -e "${YELLOW}   구현 대상: ${target_file}${NC}"
        echo -e "${YELLOW}   요구사항: ${requirement}${NC}"
        echo -e "${YELLOW}   수동으로 파일을 생성하거나 건너뛰세요.${NC}"
        exit 0
    fi

    if [ -z "$target_file" ]; then
        echo -e "${RED}오류: Task ${task_id}의 구현 대상 파일을 찾을 수 없습니다.${NC}" >&2
        exit 1
    fi

    echo "$requirement|$test_desc|$target_file"
}

# --- 헬퍼 함수 ---
log_step() {
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
}

# --- 임시 파일 관리 ---
cleanup() {
  echo -e "\n${YELLOW}🧹 임시 파일을 정리합니다...${NC}"
  rm -rf tmp_prompts
}
trap cleanup EXIT
mkdir -p tmp_prompts

# --- 에이전트 호출 함수 (내장) ---
invoke_agent() {
    local agent_name=$1
    local prompt_file=$2

    local agent_persona_file=".claude/agents/${agent_name}.md"
    if [ ! -f "$agent_persona_file" ]; then
        echo -e "${RED}오류: 페르소나 파일 '${agent_persona_file}'을 찾을 수 없습니다.${NC}" >&2
        return 1
    fi

    local model_name=$(grep '^model:' "$agent_persona_file" | cut -d' ' -f2 | tr -d '\r')
    local provider=$(grep '^provider:' "$agent_persona_file" | cut -d' ' -f2 | tr -d '\r')

    if [ -z "$model_name" ] || [ -z "$provider" ]; then
        echo -e "${RED}오류: '${agent_persona_file}'에서 model 또는 provider 설정을 찾을 수 없습니다.${NC}" >&2
        return 1
    fi

    local provider_script="providers/${provider}.sh"
    if [ ! -f "$provider_script" ]; then
        echo -e "${RED}오류: 지원하지 않는 provider 입니다. '${provider_script}' 핸들러를 찾을 수 없습니다.${NC}" >&2
        return 1
    fi

    echo -e "🤖 ${agent_name} 에이전트 호출 (Provider: ${YELLOW}${provider}${NC}, Model: ${YELLOW}${model_name}${NC})..." >&2

    local generated_text=$("$provider_script" "$model_name" "$agent_persona_file" "$prompt_file")
    echo "$generated_text" | sed -e 's/^```[a-zA-Z]*//' -e 's/```$//'
}

# --- Task 정보 파싱 ---
echo -e "${BLUE}📋 PLAN.md에서 Task ${TASK_ID} 정보를 읽어옵니다...${NC}"
TASK_INFO=$(parse_task_from_plan "$TASK_ID")
IFS='|' read -r REQUIREMENT TEST_DESC TARGET_FILE <<< "$TASK_INFO"

echo -e "${GREEN}✓ Task 정보 파싱 완료${NC}"
echo -e "  📝 요구사항: ${REQUIREMENT}"
echo -e "  🧪 테스트: ${TEST_DESC}"
echo -e "  📂 대상 파일: ${TARGET_FILE}"

# --- 파일 경로 설정 ---
# 대상 파일이 도메인/엔티티인 경우 테스트 파일 경로 자동 생성
IMPLEMENTATION_FILE_PATH="src/main/java/${TARGET_FILE}"
TEST_FILE_PATH=$(echo "$IMPLEMENTATION_FILE_PATH" | sed 's|src/main/java/|src/test/java/|' | sed 's|\.java$|Test.java|')

# --- 작업 준비 ---
echo -e "\n${YELLOW}📂 파일 경로를 준비합니다...${NC}"
mkdir -p "$(dirname "$TEST_FILE_PATH")"
mkdir -p "$(dirname "$IMPLEMENTATION_FILE_PATH")"
touch "$TEST_FILE_PATH"
touch "$IMPLEMENTATION_FILE_PATH"

log_step "🔥 TDD Cycle 시작: Task ${TASK_ID} - ${REQUIREMENT}"

# --- 🔴 RED 단계 ---
log_step "🔴 1. TEST-WRITER: 실패하는 테스트 정의"
PROMPT_FILE="$(pwd)/tmp_prompts/test_writer_task.txt"
{
    echo "# 임무 (Task)"
    echo "Task ID: ${TASK_ID}"
    echo "현재 작업 파일은 '${TEST_FILE_PATH}' 입니다."
    echo ""
    echo "# 요구사항"
    echo "${REQUIREMENT}"
    echo ""
    echo "# 테스트 설명"
    echo "${TEST_DESC}"
    echo ""
    echo "# 구현 대상 파일"
    echo "${TARGET_FILE}"
    echo ""
    echo "위 요구사항을 검증하는 실패하는 테스트 코드를 작성해주세요."
    echo ""
    echo "# 현재 테스트 파일 내용 (Context)"
    cat "$TEST_FILE_PATH"
} > "$PROMPT_FILE"

TEST_CODE=$(invoke_agent test-writer "$PROMPT_FILE")

# 빈 응답 체크
if [ -z "$(echo "$TEST_CODE" | tr -d '[:space:]')" ]; then
    echo -e "${RED}❌ 오류: test-writer가 빈 응답을 반환했습니다.${NC}"
    exit 1
fi

echo "$TEST_CODE" > "$TEST_FILE_PATH"

echo "생성된 테스트 코드를 확인합니다..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cat "$TEST_FILE_PATH"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "RED 상태를 검증합니다 (테스트는 실패해야 합니다)..."
if $VALIDATE_SCRIPT > /dev/null 2>&1; then
    echo -e "${RED}❌ 오류: 테스트가 실패해야 하지만 성공했습니다.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ RED 상태 확인: 테스트가 예상대로 실패했습니다.${NC}"
fi

# --- 변경사항 적용 함수 ---
apply_changes() {
    local response_content="$1"

    # 멀티-파일 형식인지 확인 (---path: 로 시작하는지)
    if [[ "$response_content" == "---"* && "$response_content" == *"path:"* ]]; then
        echo "멀티-파일 응답을 감지했습니다. 변경사항을 적용합니다..."
        # awk를 사용하여 파싱 및 파일 생성
        echo "$response_content" | awk '
            /^---/ {
                if (NR > 1) {
                    # 이전 파일 내용 쓰기
                    if (filepath != "") {
                        # 코드 블록 마커 제거
                        gsub(/^```[a-zA-Z]*/, "", content)
                        gsub(/```$/, "", content)
                        print content > filepath
                    }
                }
                # 새 파일 경로 추출
                if ($2 ~ /^path:/) {
                    filepath = substr($2, 6)
                }
                content = ""
                next
            }
            { content = content $0 "\n" }
            END {
                # 마지막 파일 내용 쓰기
                if (filepath != "") {
                    gsub(/^```[a-zA-Z]*/, "", content)
                    gsub(/```$/, "", content)
                    print content > filepath
                }
            }'
    else
        # 단일-파일 형식 (기존 방식)
        echo "단일-파일 응답을 감지했습니다. 대상 파일에 적용합니다..."
        echo "$response_content" > "$IMPLEMENTATION_FILE_PATH"
    fi
}

# --- 🟢 GREEN: Engineer & Debugger 단계 (자가 회복 루프) ---
log_step "🟢 2. ENGINEER/DEBUGGER: 테스트 통과 코드 구현 (최대 $MAX_RETRIES 회 시도)"
green_success=false
for ((i=1; i<=MAX_RETRIES; i++)); do
    echo -e "\n${YELLOW}--- 시도 #$i ---${NC}"
    local agent_to_call="engineer"
    local prompt_file="$(pwd)/tmp_prompts/engineer_task.txt"

    if [ $i -eq 1 ]; then
        {
            echo "# 임무 (Task)"
            echo "현재 작업 파일은 '${IMPLEMENTATION_FILE_PATH}' 입니다."
            echo "아래 테스트를 통과시키는 최소한의 코드를 작성해주세요."
            echo -e "\n# 실패하는 테스트 코드 (Context)"
            cat "$TEST_FILE_PATH"
            echo -e "\n# 수정 대상 파일 내용 (Context)"
            cat "$IMPLEMENTATION_FILE_PATH"
        } > "$prompt_file"
    else
        agent_to_call="code-debugger"
        prompt_file="$(pwd)/tmp_prompts/debugger_task.txt"
        {
            echo "# 임무 (Task)"
            echo "아래 코드는 테스트를 통과하지 못했습니다. 오류 로그를 분석하여 코드를 수정해주세요."
            echo "(필요하다면, 오류 해결을 위해 새로운 파일을 생성할 수도 있습니다.)"
            echo -e "\n# 목표: 통과시켜야 할 테스트 코드 (Goal)"
            cat "$TEST_FILE_PATH"
            echo -e "\n# 오류가 발생한 코드 (Problematic Code)"
            cat "$IMPLEMENTATION_FILE_PATH"
            echo -e "\n# 컴파일/테스트 오류 로그 (Error Log)"
            echo "$last_error_log"
        } > "$prompt_file"
    fi

    AGENT_RESPONSE=$(invoke_agent "$agent_to_call" "$prompt_file")
    apply_changes "$AGENT_RESPONSE"

    echo "GREEN 상태를 검증합니다..."
    validation_output=$($VALIDATE_SCRIPT 2>&1)
    validation_exit_code=$?
    if [ $validation_exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ GREEN 상태 확인: 모든 테스트가 통과했습니다!${NC}"; green_success=true; break;
    else
        echo -e "${RED}❌ 검증 실패. 오류가 발생했습니다.${NC}"; last_error_log=$validation_output;
        if [ $i -lt $MAX_RETRIES ]; then echo -e "${YELLOW}잠시 후 재시도합니다...${NC}"; fi
    fi
done

if [ "$green_success" = false ]; then
    echo -e "${RED}❌ 최대 재시도 횟수(${MAX_RETRIES}회)를 초과했지만 문제를 해결하지 못했습니다. 작업을 중단합니다.${NC}"; exit 1;
fi

# --- 🔵 REFACTOR 단계 ---
log_step "🔵 3. REFACTORER: 코드 리팩토링"
PROMPT_FILE="$(pwd)/tmp_prompts/refactorer_task.txt"
{
    echo "# 임무 (Task)"
    echo "Task ID: ${TASK_ID}"
    echo "현재 작업 파일은 '${IMPLEMENTATION_FILE_PATH}' 입니다."
    echo ""
    echo "아래 코드를 'Tidy First' 원칙과 프로젝트 가이드라인에 따라 리팩토링해주세요."
    echo ""
    echo "# 리팩토링 대상 코드 (Context)"
    cat "$IMPLEMENTATION_FILE_PATH"
} > "$PROMPT_FILE"

REFACTOR_RESULT=$(invoke_agent refactorer "$PROMPT_FILE")

# "리팩토링 필요 없음" 체크
if echo "$REFACTOR_RESULT" | grep -q "리팩토링 필요 없음"; then
    echo -e "${GREEN}✅ 리팩토링 필요 없음: 코드가 이미 최적 상태입니다.${NC}"
else
    # 리팩토링된 코드 추출
    REFACTORED_CODE=$(echo "$REFACTOR_RESULT" | awk '/### ✨ Refactored Code/,/### 📝 Changes Made/' | sed '1d;$d')

    if [ -z "$(echo "$REFACTORED_CODE" | tr -d '[:space:]')" ]; then
        echo -e "${YELLOW}🤔 리팩토링 코드 추출 실패. 원본 코드를 유지합니다.${NC}"
    else
        echo "$REFACTORED_CODE" > "$IMPLEMENTATION_FILE_PATH"
        echo "리팩토링 결과를 적용했습니다. 변경 후 테스트를 다시 검증합니다..."
        if ! $VALIDATE_SCRIPT; then
            echo -e "${RED}❌ 오류: 리팩토링 후 테스트가 실패했습니다. 작업을 중단합니다.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ 리팩토링 후 검증 성공.${NC}"
    fi
fi

# --- 🟡 AUDIT 단계 ---
log_step "🟡 4. AUDITOR: 가이드라인 준수 검토"
PROMPT_FILE="$(pwd)/tmp_prompts/auditor_task.txt"
{
    echo "# 임무 (Task)"
    echo "Task ID: ${TASK_ID}"
    echo "아래 코드가 프로젝트의 코딩 가이드라인을 완벽하게 준수하는지 검토해주세요."
    echo ""
    echo "# 검토 대상 코드"
    cat "$IMPLEMENTATION_FILE_PATH"
    echo ""
    echo "# 코딩 가이드라인"
    cat "$CODING_GUIDE_PATH"
} > "$PROMPT_FILE"

AUDIT_RESULT=$(invoke_agent auditor "$PROMPT_FILE")
echo "$AUDIT_RESULT"

if echo "$AUDIT_RESULT" | grep -q "AUDIT FAILED"; then
    echo -e "${RED}❌ AUDIT 실패: 코드가 가이드라인을 위반했습니다.${NC}"
    echo -e "${YELLOW}💡 위 리포트를 참고하여 수동으로 수정하거나, Task를 재실행하세요.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AUDIT 통과: 코드가 모든 가이드라인을 준수합니다.${NC}"

# --- 📦 Git Staging ---
log_step "📦 최종 단계: Git Staging"
git add "$TEST_FILE_PATH" "$IMPLEMENTATION_FILE_PATH"
echo -e "${GREEN}✅ TDD Cycle 완료! 변경 사항이 Git에 Staged 되었습니다.${NC}"
echo ""
echo -e "${CYAN}📊 완료된 Task 요약:${NC}"
echo -e "  Task ID: ${TASK_ID}"
echo -e "  요구사항: ${REQUIREMENT}"
echo -e "  테스트: ${TEST_DESC}"
echo -e "  파일: ${TARGET_FILE}"
echo ""
echo "git diff --staged 로 변경사항을 확인하고 직접 커밋해주세요."
