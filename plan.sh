#!/bin/bash

# ==============================================================================
# AI-Powered Planner (plan.sh) v3.0 - Self-Contained
#
# invoke_agent.sh를 호출하는 대신, 에이전트 호출 로직을 내장하여 안정성을 높였습니다.
# ==============================================================================

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 입력값 검증 ---
if [ "$#" -ne 2 ]; then
    echo -e "${RED}오류: 2개의 인수가 필요합니다.${NC}" >&2
    echo "사용법: $0 <API_KEY> \"구현할 기능에 대한 설명\"" >&2
    exit 1
fi

API_KEY=$1
USER_GOAL=$2
PLANNER_AGENT_NAME="planner"

# --- 임시 파일 관리 ---
cleanup() {
  echo -e "\n${YELLOW}🧹 임시 파일을 정리합니다...${NC}"
  rm -rf tmp_prompts
}
trap cleanup EXIT
mkdir -p tmp_prompts

# ==============================================================================
# AGENT INVOCATION LOGIC (내장된 로직)
# ==============================================================================

# 1. 프롬프트 파일 생성
PROMPT_FILE="$(pwd)/tmp_prompts/planner_task.txt"
PROJECT_STRUCTURE=$(git ls-files)
{
    echo "# Goal"
    echo "$USER_GOAL"
    echo ""
    echo "# Current Project Structure (tracked by Git)"
    echo "$PROJECT_STRUCTURE"
} > "$PROMPT_FILE"

# 2. 페르소나 파일 분석
AGENT_PERSONA_FILE=".claude/agents/${PLANNER_AGENT_NAME}.md"
if [ ! -f "$AGENT_PERSONA_FILE" ]; then
    echo -e "${RED}오류: 에이전트 페르소나 파일 '${AGENT_PERSONA_FILE}'을 찾을 수 없습니다.${NC}" >&2; exit 1; 
fi

MODEL_NAME=$(grep '^model:' "$AGENT_PERSONA_FILE" | cut -d' ' -f2 | tr -d '\r')
PROVIDER=$(grep '^provider:' "$AGENT_PERSONA_FILE" | cut -d' ' -f2 | tr -d '\r')

if [ -z "$MODEL_NAME" ] || [ -z "$PROVIDER" ]; then 
    echo -e "${RED}오류: '${AGENT_PERSONA_FILE}'에서 model 또는 provider 설정을 찾을 수 없습니다.${NC}" >&2; exit 1; 
fi

# 3. Provider 스크립트 호출
PROVIDER_SCRIPT="providers/${PROVIDER}.sh"
if [ ! -f "$PROVIDER_SCRIPT" ]; then
    echo -e "${RED}오류: 지원하지 않는 provider 입니다. '${PROVIDER_SCRIPT}' 핸들러를 찾을 수 없습니다.${NC}" >&2
    exit 1
fi

echo -e "🤔 ${YELLOW}${PLANNER_AGENT_NAME}${NC} 에이전트가 실행 계획을 수립합니다... (Provider: ${PROVIDER}, Model: ${MODEL_NAME})"
echo -e "   요구사항: \"${GREEN}$USER_GOAL${NC}\""

GENERATED_TEXT=$("$PROVIDER_SCRIPT" "$API_KEY" "$MODEL_NAME" "$AGENT_PERSONA_FILE" "$PROMPT_FILE")
EXECUTION_PLAN=$(echo "$GENERATED_TEXT" | sed -e 's/^```[a-zA-Z]*//' -e 's/```$//')

# ==============================================================================
# EXECUTION
# ==============================================================================

echo "✅ 실행 계획이 수립되었습니다."
echo "----------------------------------------"
echo -e "${GREEN}$EXECUTION_PLAN${NC}"
echo "----------------------------------------"



# 실행 계획에 API 키를 추가하여 최종 실행 명령 생성
FINAL_COMMAND=$(echo "$EXECUTION_PLAN" | sed "s|./run_tdd_cycle.sh|./run_tdd_cycle.sh \"$API_KEY\"|")

echo -e "\n🚀 계획을 실행합니다..."
eval "$FINAL_COMMAND"