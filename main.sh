#!/bin/bash

# ==============================================================================
# Master Orchestrator v4.0 - Pure Bash, No Python
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

# --- PLAN.md에서 다음 Task 파싱 (순수 Bash) ---
find_next_task() {
    if [ ! -f "$PLAN_FILE" ]; then
        echo -e "${RED}오류: PLAN.md를 찾을 수 없습니다.${NC}" >&2
        exit 1
    fi

    # 첫 번째 미완료 Task 블록 추출
    local task_block=$(awk '
        /^- \[ \] \*\*Task/ {
            found=1;
            block=$0;
            next
        }
        found && /^  - / {
            block=block"\n"$0
        }
        found && /^- \[/ {
            exit
        }
        found && /^$/ {
            exit
        }
        END {
            if (found) print block
        }
    ' "$PLAN_FILE")

    if [ -z "$task_block" ]; then
        return 1  # 더 이상 Task 없음
    fi

    # Task ID 추출
    local task_id=$(echo "$task_block" | grep -o 'Task [0-9-]*' | head -1 | cut -d' ' -f2)

    # 요구사항 추출
    local requirement=$(echo "$task_block" | grep '요구사항:' | sed 's/.*요구사항: *"\(.*\)".*/\1/')

    # 테스트 설명 추출
    local test_desc=$(echo "$task_block" | grep '테스트:' | sed 's/.*테스트: *"\(.*\)".*/\1/')

    # 구현 대상 추출
    local target=$(echo "$task_block" | grep '구현 대상:' | sed 's/.*구현 대상: *`\(.*\)`.*/\1/')

    # 검증
    if [ -z "$task_id" ] || [ -z "$requirement" ] || [ -z "$target" ]; then
        echo -e "${RED}오류: Task 정보 파싱 실패${NC}" >&2
        echo "task_id: $task_id" >&2
        echo "requirement: $requirement" >&2
        echo "target: $target" >&2
        exit 1
    fi

    # 테스트가 "없음"인지 확인
    if [ "$test_desc" = "없음" ] || [ -z "$test_desc" ]; then
        echo "$task_id|$requirement|없음|$target"
    else
        echo "$task_id|$requirement|$test_desc|$target"
    fi
}

# --- Task 완료 표시 ---
mark_task_complete() {
    local task_id=$1

    # 특수문자 이스케이프
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
echo -e "${CYAN}║       TDD 자동화 워크플로우 v4.0 (Pure Bash)              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

while true; do
    echo -e "\n${BLUE}📋 다음 Task를 찾는 중...${NC}"

    TASK_INFO=$(find_next_task)

    if [ $? -ne 0 ]; then
        echo -e "${GREEN}🎉 모든 Task 완료!${NC}"
        break
    fi

    # 파싱
    IFS='|' read -r TASK_ID REQUIREMENT TEST_DESC TARGET <<< "$TASK_INFO"

    echo -e "${YELLOW}🎯 Task ${TASK_ID}: ${REQUIREMENT}${NC}"
    echo -e "   📂 대상: ${TARGET}"

    # 테스트 없는 Task 처리
    if [ "$TEST_DESC" = "없음" ]; then
        echo -e "${BLUE}ℹ️  구조 정의 Task (테스트 불필요)${NC}"

        IMPL_PATH="${SRC_PREFIX}/${TARGET}"
        mkdir -p "$(dirname "$IMPL_PATH")"

        # 파일이 이미 존재하면 건너뛰기
        if [ -f "$IMPL_PATH" ]; then
            echo -e "${GREEN}✓ 파일이 이미 존재함. Task 완료 처리${NC}"
        else
            echo -e "${YELLOW}수동으로 파일을 생성하세요: ${IMPL_PATH}${NC}"
            read -p "생성 완료 후 Enter (또는 s로 건너뛰기): " skip

            if [ "$skip" = "s" ]; then
                echo -e "${YELLOW}⏭️  Task 건너뜀${NC}"
                continue
            fi
        fi

        mark_task_complete "$TASK_ID"
        git add "$IMPL_PATH" 2>/dev/null || true
        git commit -m "feat: Task ${TASK_ID} - ${REQUIREMENT}" --no-verify 2>/dev/null || echo "커밋 없음"
        continue
    fi

    # TDD 실행
    IMPL_PATH="${SRC_PREFIX}/${TARGET}"
    TEST_PATH="${TEST_SRC_PREFIX}/$(echo "$TARGET" | sed 's/\.java$/Test.java/')"

    echo -e "   🧪 테스트: ${TEST_DESC}"
    echo ""

    if "$TDD_SCRIPT" "$TASK_ID"; then
        echo -e "\n${GREEN}✅ Task ${TASK_ID} 성공!${NC}"
        mark_task_complete "$TASK_ID"

        git add "$TEST_PATH" "$IMPL_PATH"
        git commit -m "feat: Task ${TASK_ID} - ${REQUIREMENT}" --no-verify

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ Task ${TASK_ID} 완료 및 커밋${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        echo -e "\n${YELLOW}⏭️  3초 후 다음 Task 시작...${NC}"
        sleep 3
    else
        echo -e "\n${RED}❌ Task ${TASK_ID} 실패${NC}"
        echo -e "${YELLOW}💡 조치:${NC}"
        echo -e "   1. 생성된 코드 확인: ${IMPL_PATH}"
        echo -e "   2. 테스트 확인: ${TEST_PATH}"
        echo -e "   3. 수정 후 ./main.sh 재실행"
        exit 1
    fi
done

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 전체 워크플로우 완료!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
