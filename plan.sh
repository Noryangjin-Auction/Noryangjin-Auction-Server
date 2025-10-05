#!/bin/bash

# ==============================================================================
# AI-Powered Planner (plan.sh) v2.1
#
# 이 스크립트는 사용자의 고수준 요구사항을 planner 에이전트에게 전달하여
# 구체적인 실행 계획(셸 명령어)을 수립하고 실행합니다.
#
# 사용법:
# ./plan.sh "구현할 기능에 대한 설명"
# ==============================================================================

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$#" -ne 1 ]; then
    echo -e "${RED}오류: 1개의 인수가 필요합니다.${NC}" >&2
    echo "사용법: $0 \"구현할 기능에 대한 설명\"" >&2
    exit 1
fi

USER_GOAL=$1
INVOKE_AGENT_SCRIPT="./invoke_agent.sh"
PLANNER_AGENT_NAME="planner"

cleanup() {
  echo -e "\n${YELLOW}🧹 임시 파일을 정리합니다...${NC}"
  rm -rf tmp_prompts
}
trap cleanup EXIT

mkdir -p tmp_prompts

echo -e "🤔 ${YELLOW}${PLANNER_AGENT_NAME}${NC} 에이전트가 사용자의 요구사항을 분석하고 실행 계획을 수립합니다..."
echo -e "   요구사항: \"${GREEN}$USER_GOAL${NC}\""

PROJECT_STRUCTURE=$(git ls-files)

{
    echo "# Goal"
    echo "$USER_GOAL"
    echo ""
    echo "# Current Project Structure (tracked by Git)"
    echo "$PROJECT_STRUCTURE"
} > tmp_prompts/planner_task.txt

EXECUTION_PLAN=$($INVOKE_AGENT_SCRIPT $PLANNER_AGENT_NAME tmp_prompts/planner_task.txt)

echo "✅ 실행 계획이 수립되었습니다."
echo "----------------------------------------"
echo -e "${GREEN}$EXECUTION_PLAN${NC}"
echo "----------------------------------------"

read -p "이 계획을 실행하시겠습니까? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "작업을 취소했습니다."
    exit 0
fi

echo -e "\n🚀 계획을 실행합니다..."
eval "$EXECUTION_PLAN"
