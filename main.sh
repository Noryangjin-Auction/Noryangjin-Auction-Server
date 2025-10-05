#!/bin/bash

# ==============================================================================
# Master Orchestrator (main.sh) v4.2 - No-Test Task Handler
# ==============================================================================

set -e

# ... (기존 설정 변수들) ...
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

# ... (find_next_task, mark_task_complete 함수는 기존과 동일) ...

# --- 메인 루프 ---
# ... (기존 메인 루프 시작 부분) ...

while true;
    # ... (기존 Task 정보 파싱 로직) ...

    # "테스트 없음" Task를 위한 특별 처리
    if [[ "$TEST_DESC" == "없음"* ]]; then
        echo -e "${BLUE}ℹ️  구조 정의 Task (테스트 불필요) - AI가 직접 생성합니다.${NC}"
        IMPL_PATH="${SRC_PREFIX}/${TARGET}"
        mkdir -p "$(dirname "$IMPL_PATH")"

        # engineer에게 파일 생성을 직접 요청
        PROMPT_FILE="tmp_prompts/direct_creation_task.txt"
        {
            echo "# 임무 (Task)"
            echo "'${IMPL_PATH}' 파일을 생성해야 합니다."
            echo "요구사항은 다음과 같습니다: ${REQUIREMENT}"
            echo "다른 의존성 없이, 이 파일의 내용만 생성해주세요."
        } > "$PROMPT_FILE"

        # run_tdd_cycle.sh를 건너뛰고 engineer를 직접 호출
        # 이 부분은 run_tdd_cycle.sh의 invoke_agent 함수를 참고하여 재구성
        AGENT_NAME="engineer"
        AGENT_PERSONA_FILE=".claude/agents/${AGENT_NAME}.md"
        MODEL_NAME=$(grep '^model:' "$AGENT_PERSONA_FILE" | cut -d' ' -f2 | tr -d '\r')
        PROVIDER=$(grep '^provider:' "$AGENT_PERSONA_FILE" | cut -d' ' -f2 | tr -d '\r')
        PROVIDER_SCRIPT="providers/${PROVIDER}.sh"
        
        echo -e "🤖 ${AGENT_NAME} 에이전트 호출 (Provider: ${PROVIDER}, Model: ${MODEL_NAME})..." >&2
        GENERATED_CODE=$("$PROVIDER_SCRIPT" "$MODEL_NAME" "$AGENT_PERSONA_FILE" "$PROMPT_FILE")
        
        echo "$GENERATED_CODE" > "$IMPL_PATH"
        echo -e "${GREEN}✓ 파일 생성 완료: ${IMPL_PATH}${NC}"

        mark_task_complete "$TASK_ID"
        git add "$IMPL_PATH" && git commit -m "feat(task-${TASK_ID}): ${REQUIREMENT}"
        
        echo -e "\n${YELLOW}⏭️  3초 후 다음 Task를 시작합니다...${NC}"
        sleep 3
        continue # 다음 루프로
    fi

    # TDD가 필요한 일반 Task 처리
    # ... (기존 TDD 사이클 실행 로직) ...

done

# ... (기존 스크립트 종료 부분) ...