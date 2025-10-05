#!/bin/bash

# ==============================================================================
# TDD Cycle Master Script (run_tdd_cycle.sh) v5.0 - Simple Executor
# 이 스크립트는 더 이상 PLAN.md를 파싱하지 않으며, 오직 전달받은 인자로 TDD 사이클만 실행합니다.
# ==============================================================================

set -e

# --- (기존 설정 및 함수들: log_step, cleanup, invoke_agent) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VALIDATE_SCRIPT="./validate.sh"
CODING_GUIDE_PATH="./CLAUDE.md"
MAX_RETRIES=3

if [ "$#" -ne 3 ]; then
    echo -e "${RED}오류: 3개의 인수가 필요합니다.${NC}" >&2
    echo "사용법: $0 \"작업 내용\" <테스트 파일 경로> <구현 파일 경로>" >&2
    exit 1
fi

TASK_DESCRIPTION=$1
TEST_FILE_PATH=$2
IMPLEMENTATION_FILE_PATH=$3

# ... (log_step, cleanup, invoke_agent 등 헬퍼 함수 위치) ...

# --- 작업 준비 ---
# ... (mkdir, touch 등)

log_step "🔥 TDD Cycle 시작: \"$TASK_DESCRIPTION\""

# --- 🔴 RED, 🟢 GREEN, 🔵 REFACTOR, 🟡 AUDIT 단계 ---
# (이전의 안정적인 v4.0 버전 로직과 동일하게 진행)

# ... (이하 생략, 이전 버전의 전체 로직을 여기에 붙여넣습니다)