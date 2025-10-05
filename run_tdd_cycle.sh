#!/bin/bash

# ==============================================================================
# TDD Cycle Master Script (run_tdd_cycle.sh) v3.1 - Fully Implemented
#
# REFACTOR, AUDIT 단계를 실제 에이전트 호출로 구현하고,
# 리팩토링 후 검증 단계를 추가하여 완전한 TDD 사이클을 완성합니다.
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INVOKE_AGENT_SCRIPT="./invoke_agent.sh"
VALIDATE_SCRIPT="./validate.sh"
CODING_GUIDE_PATH="./CLAUDE.md"
MAX_RETRIES=3

if [ "$#" -ne 3 ]; then
    echo -e "${RED}오류: 3개의 인수가 필요합니다.${NC}"
    echo "사용법: $0 \"작업 내용\" <테스트 파일 경로> <구현 파일 경로>"
    exit 1
fi

TASK_DESCRIPTION=$1
TEST_FILE_PATH=$2
IMPLEMENTATION_FILE_PATH=$3

echo -e "${YELLOW}📂 파일 경로를 준비합니다...${NC}"
mkdir -p "$(dirname "$TEST_FILE_PATH")"
mkdir -p "$(dirname "$IMPLEMENTATION_FILE_PATH")"
touch "$TEST_FILE_PATH"
touch "$IMPLEMENTATION_FILE_PATH"

log_step() {
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
}

cleanup() {
  echo -e "\n${YELLOW}🧹 임시 파일을 정리합니다...${NC}"
  rm -rf tmp_prompts tmp_outputs
}
trap cleanup EXIT

mkdir -p tmp_prompts tmp_outputs

log_step "🔥 TDD Cycle 시작: \"$TASK_DESCRIPTION\""

# --- 🔴 RED 단계 ---
log_step "🔴 1. TEST-WRITER: 실패하는 테스트 정의"
{
    echo "# 임무 (Task)"
    echo "현재 작업 파일은 '${TEST_FILE_PATH}' 입니다."
    echo "아래 요구사항을 만족하는 실패하는 테스트 메소드를 작성해주세요."
    echo "요구사항: $TASK_DESCRIPTION"
    echo -e "\n# 현재 파일 내용 (Context)"
    cat "$TEST_FILE_PATH"
} > tmp_prompts/test_writer_task.txt

$INVOKE_AGENT_SCRIPT test-writer tmp_prompts/test_writer_task.txt > "$TEST_FILE_PATH"

echo "RED 상태를 검증합니다 (테스트는 실패해야 합니다)..."
if $VALIDATE_SCRIPT > /dev/null 2>&1; then
    echo -e "${RED}❌ 오류: 테스트가 실패해야 하지만 성공했습니다.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ RED 상태 확인: 테스트가 예상대로 실패했습니다.${NC}"
fi


# --- 🟢 GREEN: Engineer & Debugger 단계 (자가 회복 루프) ---
log_step "🟢 2. ENGINEER/DEBUGGER: 테스트 통과 코드 구현 (최대 $MAX_RETRIES 회 시도)"

green_success=false
last_error_log=""
for ((i=1; i<=MAX_RETRIES; i++)); do
    echo -e "\n${YELLOW}--- 시도 #$i ---${NC}"
    if [ $i -eq 1 ]; then
        # 첫 시도는 Engineer
        {
            echo "# 임무 (Task)"
            echo "현재 작업 파일은 '${IMPLEMENTATION_FILE_PATH}' 입니다."
            echo "아래 테스트를 통과시키는 최소한의 코드를 작성해주세요."
            echo -e "\n# 실패하는 테스트 코드 (Context)"
            cat "$TEST_FILE_PATH"
            echo -e "\n# 수정 대상 파일 내용 (Context)"
            cat "$IMPLEMENTATION_FILE_PATH"
        } > tmp_prompts/engineer_task.txt
        $INVOKE_AGENT_SCRIPT engineer tmp_prompts/engineer_task.txt > "$IMPLEMENTATION_FILE_PATH"
    else
        # 실패 시 Debugger 개입
        {
            echo "# 임무 (Task)"
            echo "아래 코드는 테스트를 통과하지 못했습니다. 오류 로그를 분석하여 코드를 수정해주세요."
            echo -e "\n# 목표: 통과시켜야 할 테스트 코드 (Goal)"
            cat "$TEST_FILE_PATH"
            echo -e "\n# 오류가 발생한 코드 (Problematic Code)"
            cat "$IMPLEMENTATION_FILE_PATH"
            echo -e "\n# 컴파일/테스트 오류 로그 (Error Log)"
            echo "$last_error_log"
        } > tmp_prompts/debugger_task.txt
        echo "Debugger 에이전트 🐞 를 호출하여 문제 해결을 시도합니다..."
        $INVOKE_AGENT_SCRIPT code-debugger tmp_prompts/debugger_task.txt > "$IMPLEMENTATION_FILE_PATH"
    fi

    echo "GREEN 상태를 검증합니다..."
    validation_output=$($VALIDATE_SCRIPT 2>&1)
    validation_exit_code=$?
    if [ $validation_exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ GREEN 상태 확인: 모든 테스트가 통과했습니다!${NC}"
        green_success=true
        break
    else
        echo -e "${RED}❌ 검증 실패. 오류가 발생했습니다.${NC}"
        last_error_log=$validation_output
        echo "--- 오류 로그 (마지막 10줄) ---"
        echo "$last_error_log" | tail -n 10
        echo "-----------------------------"
        if [ $i -lt $MAX_RETRIES ]; then echo -e "${YELLOW}잠시 후 재시도합니다...${NC}"; fi
    fi
done

if [ "$green_success" = false ]; then
    echo -e "${RED}❌ 최대 재시도 횟수(${MAX_RETRIES}회)를 초과했지만 문제를 해결하지 못했습니다. 작업을 중단합니다.${NC}"
    exit 1
fi

# --- 🔵 REFACTOR 단계 ---
log_step "🔵 3. CODE-CRAFTSMAN: 코드 리팩토링"
{
    echo "# 임무 (Task)"
    echo "현재 작업 파일은 '${IMPLEMENTATION_FILE_PATH}' 입니다."
    echo "아래 코드를 'Tidy First' 원칙과 프로젝트 가이드라인에 따라 리팩토링해주세요."
    echo "기능적 변경은 절대 없어야 하며, 모든 테스트는 여전히 통과해야 합니다."
    echo -e "\n# 리팩토링 대상 코드 (Context)"
    cat "$IMPLEMENTATION_FILE_PATH"
    echo -e "\n# 참고: 관련 테스트 코드 (Context)"
    cat "$TEST_FILE_PATH"
} > tmp_prompts/craftsman_task.txt

REFACTOR_RESULT=$($INVOKE_AGENT_SCRIPT refactorer tmp_prompts/craftsman_task.txt)
REFACTORED_CODE=$(echo "$REFACTOR_RESULT" | awk '/### ✨ Refactored Code/,/### 📝 Changes Made/' | sed '1d;$d')

if [ -z "$REFACTORED_CODE" ]; then
    echo -e "${YELLOW}🤔 리팩토링이 필요하지 않거나, 코드 추출에 실패했습니다. 원본 코드를 유지합니다.${NC}"
else
    echo "$REFACTORED_CODE" > "$IMPLEMENTATION_FILE_PATH"
    echo "리팩토링 결과를 적용했습니다. 변경 후 테스트를 다시 검증합니다..."
    if ! $VALIDATE_SCRIPT; then
        echo -e "${RED}❌ 오류: 리팩토링 후 테스트가 실패했습니다. 작업을 중단합니다.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ 리팩토링 후 검증 성공: 모든 테스트가 여전히 통과합니다.${NC}"
fi

# --- 🟡 AUDIT 단계 ---
log_step "🟡 4. AUDITOR: 가이드라인 준수 검토"
{
    echo "# 임무 (Task)"
    echo "아래 코드가 프로젝트의 코딩 가이드라인을 완벽하게 준수하는지 검토해주세요."
    echo -e "\n# 검토 대상 코드"
    cat "$IMPLEMENTATION_FILE_PATH"
    echo -e "\n# 코딩 가이드라인"
    cat "$CODING_GUIDE_PATH"
} > tmp_prompts/auditor_task.txt

AUDIT_RESULT=$($INVOKE_AGENT_SCRIPT auditor tmp_prompts/auditor_task.txt)
echo "$AUDIT_RESULT" # 감사 결과를 사용자에게 보여줌

if echo "$AUDIT_RESULT" | grep -q "AUDIT FAILED"; then
    echo -e "${RED}❌ AUDIT 실패: 코드가 가이드라인을 위반했습니다. 작업을 중단합니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AUDIT 통과: 코드가 모든 가이드라인을 준수합니다.${NC}"


# --- 📦 Git Staging ---
log_step "📦 최종 단계: Git Staging"
git add "$TEST_FILE_PATH" "$IMPLEMENTATION_FILE_PATH"
echo -e "${GREEN}✅ TDD Cycle 완료! 변경 사항이 Git에 Staged 되었습니다.${NC}"
echo "git diff --staged 로 변경사항을 확인하고 직접 커밋해주세요."
