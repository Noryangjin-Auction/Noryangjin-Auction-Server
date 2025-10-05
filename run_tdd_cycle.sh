#!/bin/bash

# ==============================================================================
# TDD Cycle Master Script (run_tdd_cycle.sh) v4.0 - Self-Contained
#
# invoke_agent.sh 의존성을 제거하고, 에이전트 호출 로직을 내장하여 안정성을 확보했습니다.
# ==============================================================================

# --- 기본 설정 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VALIDATE_SCRIPT="./validate.sh"
CODING_GUIDE_PATH="./CLAUDE.md"
MAX_RETRIES=3

# --- 입력값 검증 ---
if [ "$#" -ne 3 ]; then
    echo -e "${RED}오류: 3개의 인수가 필요합니다.${NC}" >&2
    echo "사용법: $0 \"작업 내용\" <테스트 파일 경로> <구현 파일 경로>" >&2
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
        echo -e "${RED}오류: 페르소나 파일 '${agent_persona_file}'을 찾을 수 없습니다.${NC}" >&2; return 1; 
    fi

    local model_name=$(grep '^model:' "$agent_persona_file" | cut -d' ' -f2 | tr -d '\r')
    local provider=$(grep '^provider:' "$agent_persona_file" | cut -d' ' -f2 | tr -d '\r')

    if [ -z "$model_name" ] || [ -z "$provider" ]; then 
        echo -e "${RED}오류: '${agent_persona_file}'에서 model 또는 provider 설정을 찾을 수 없습니다.${NC}" >&2; return 1; 
    fi

    local provider_script="providers/${provider}.sh"
    if [ ! -f "$provider_script" ]; then
        echo -e "${RED}오류: 지원하지 않는 provider 입니다. '${provider_script}' 핸들러를 찾을 수 없습니다.${NC}" >&2; return 1;
    fi

    echo -e "🤖 ${agent_name} 에이전트 호출 (Provider: ${YELLOW}${provider}${NC}, Model: ${YELLOW}${model_name}${NC})..." >&2
    
    local generated_text=$("$provider_script" "$model_name" "$agent_persona_file" "$prompt_file")
    echo "$generated_text" | sed -e 's/^```[a-zA-Z]*//' -e 's/```$//'
}

# --- 작업 준비 ---
echo -e "${YELLOW}📂 파일 경로를 준비합니다...${NC}"
mkdir -p "$(dirname "$TEST_FILE_PATH")"
mkdir -p "$(dirname "$IMPLEMENTATION_FILE_PATH")"
touch "$TEST_FILE_PATH"
touch "$IMPLEMENTATION_FILE_PATH"

log_step "🔥 TDD Cycle 시작: \"$TASK_DESCRIPTION\""

# --- 🔴 RED 단계 ---
log_step "🔴 1. TEST-WRITER: 실패하는 테스트 정의"
PROMPT_FILE="$(pwd)/tmp_prompts/test_writer_task.txt"
{
    echo "# 임무 (Task)"
    echo "현재 작업 파일은 '${TEST_FILE_PATH}' 입니다."
    echo "아래 요구사항을 만족하는 실패하는 테스트 코드를 작성해주세요."
    echo "요구사항: $TASK_DESCRIPTION"
    echo -e "\n# 현재 파일 내용 (Context)"
    cat "$TEST_FILE_PATH"
} > "$PROMPT_FILE"

invoke_agent test-writer "$PROMPT_FILE" > "$TEST_FILE_PATH"

echo "RED 상태를 검증합니다 (테스트는 실패해야 합니다)..."
if $VALIDATE_SCRIPT > /dev/null 2>&1; then
    echo -e "${RED}❌ 오류: 테스트가 실패해야 하지만 성공했습니다.${NC}"; exit 1;
else
    echo -e "${GREEN}✅ RED 상태 확인: 테스트가 예상대로 실패했습니다.${NC}"
fi

# --- 🟢 GREEN: Engineer & Debugger 단계 (자가 회복 루프) ---
log_step "🟢 2. ENGINEER: 테스트 통과 코드 구현 (디버그 모드)"
PROMPT_FILE="$(pwd)/tmp_prompts/engineer_task.txt"
{
    echo "# 임무 (Task)"
    echo "현재 작업 파일은 '${IMPLEMENTATION_FILE_PATH}' 입니다."
    echo "아래 테스트를 통과시키는 최소한의 코드를 작성해주세요."
    echo -e "\n# 실패하는 테스트 코드 (Context)"
    cat "$TEST_FILE_PATH"
    echo -e "\n# 수정 대상 파일 내용 (Context)"
    cat "$IMPLEMENTATION_FILE_PATH"
} > "$PROMPT_FILE"

invoke_agent engineer "$PROMPT_FILE" > "$IMPLEMENTATION_FILE_PATH"

echo "GREEN 상태를 검증합니다..."
if ! $VALIDATE_SCRIPT; then
    echo -e "${RED}❌ GREEN 단계 검증 실패! 전체 오류 로그를 확인하세요. 작업을 중단합니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ GREEN 상태 확인: 모든 테스트가 통과했습니다!${NC}"

# --- 🔵 REFACTOR 단계 ---
log_step "🔵 3. REFACTORER: 코드 리팩토링"
PROMPT_FILE="$(pwd)/tmp_prompts/refactorer_task.txt"
{
    echo "# 임무 (Task)"
    echo "현재 작업 파일은 '${IMPLEMENTATION_FILE_PATH}' 입니다."
    echo "아래 코드를 'Tidy First' 원칙과 프로젝트 가이드라인에 따라 리팩토링해주세요."
    echo -e "\n# 리팩토링 대상 코드 (Context)"
    cat "$IMPLEMENTATION_FILE_PATH"
} > "$PROMPT_FILE"

REFACTOR_RESULT=$(invoke_agent refactorer "$PROMPT_FILE")
REFACTORED_CODE=$(echo "$REFACTOR_RESULT" | awk '/### ✨ Refactored Code/,/### 📝 Changes Made/' | sed '1d;$d')

if [ -z "$REFACTORED_CODE" ]; then
    echo -e "${YELLOW}🤔 리팩토링이 필요하지 않거나, 코드 추출에 실패했습니다. 원본 코드를 유지합니다.${NC}"
else
    echo "$REFACTORED_CODE" > "$IMPLEMENTATION_FILE_PATH"
    echo "리팩토링 결과를 적용했습니다. 변경 후 테스트를 다시 검증합니다..."
    if ! $VALIDATE_SCRIPT; then echo -e "${RED}❌ 오류: 리팩토링 후 테스트가 실패했습니다. 작업을 중단합니다.${NC}"; exit 1; fi
    echo -e "${GREEN}✅ 리팩토링 후 검증 성공.${NC}"
fi

# --- 🟡 AUDIT 단계 ---
log_step "🟡 4. AUDITOR: 가이드라인 준수 검토"
PROMPT_FILE="$(pwd)/tmp_prompts/auditor_task.txt"
{
    echo "# 임무 (Task)"
    echo "아래 코드가 프로젝트의 코딩 가이드라인을 완벽하게 준수하는지 검토해주세요."
    echo -e "\n# 검토 대상 코드"
    cat "$IMPLEMENTATION_FILE_PATH"
    echo -e "\n# 코딩 가이드라인"
    cat "$CODING_GUIDE_PATH"
} > "$PROMPT_FILE"

AUDIT_RESULT=$(invoke_agent auditor "$PROMPT_FILE")
echo "$AUDIT_RESULT"

if echo "$AUDIT_RESULT" | grep -q "AUDIT FAILED"; then
    echo -e "${RED}❌ AUDIT 실패: 코드가 가이드라인을 위반했습니다. 작업을 중단합니다.${NC}"; exit 1;
fi
echo -e "${GREEN}✅ AUDIT 통과: 코드가 모든 가이드라인을 준수합니다.${NC}"

# --- 📦 Git Staging ---
log_step "📦 최종 단계: Git Staging"
git add "$TEST_FILE_PATH" "$IMPLEMENTATION_FILE_PATH"
echo -e "${GREEN}✅ TDD Cycle 완료! 변경 사항이 Git에 Staged 되었습니다.${NC}"
echo "git diff --staged 로 변경사항을 확인하고 직접 커밋해주세요."