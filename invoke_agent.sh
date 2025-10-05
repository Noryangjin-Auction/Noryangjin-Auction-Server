#!/bin/bash

# ==============================================================================
# Agent Invoker (invoke_agent.sh) v4.0 - Extensible Dispatcher
#
# 에이전트의 'provider' 설정에 따라 'providers/' 디렉토리의
# 해당 핸들러 스크립트를 동적으로 실행하는 관제탑(Dispatcher)입니다.
# ==============================================================================

# --- 설정 (Configuration) ---
set -e
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$#" -ne 2 ]; then
    echo -e "${RED}오류: 2개의 인수가 필요합니다.${NC}" >&2
    echo "사용법: $0 <에이전트_이름> <입력_프롬프트_파일>" >&2
    exit 1
fi

AGENT_NAME=$1
INPUT_PROMPT_FILE=$2
AGENT_PERSONA_FILE=".claude/agents/${AGENT_NAME}.md"

if [ ! -f "$AGENT_PERSONA_FILE" ]; then
    echo -e "${RED}오류: 에이전트 페르소나 파일 '${AGENT_PERSONA_FILE}'을 찾을 수 없습니다.${NC}" >&2; exit 1; fi
if [ ! -f "$INPUT_PROMPT_FILE" ]; then
    echo -e "${RED}오류: 입력 프롬프트 파일 '${INPUT_PROMPT_FILE}'을 찾을 수 없습니다.${NC}" >&2; exit 1; fi

# --- 페르소나 파싱 (Persona Parsing) ---
MODEL_NAME=$(grep '^model:' "$AGENT_PERSONA_FILE" | cut -d' ' -f2 | tr -d '\r')
PROVIDER=$(grep '^provider:' "$AGENT_PERSONA_FILE" | cut -d' ' -f2 | tr -d '\r')

if [ -z "$MODEL_NAME" ]; then echo -e "${RED}오류: '${AGENT_PERSONA_FILE}'에서 'model:' 설정을 찾을 수 없습니다.${NC}" >&2; exit 1; fi
if [ -z "$PROVIDER" ]; then echo -e "${RED}오류: '${AGENT_PERSONA_FILE}'에서 'provider:' 설정을 찾을 수 없습니다.${NC}" >&2; exit 1; fi

PROVIDER_SCRIPT="providers/${PROVIDER}.sh"

if [ ! -f "$PROVIDER_SCRIPT" ]; then
    echo -e "${RED}오류: 지원하지 않는 provider 입니다. '${PROVIDER_SCRIPT}' 핸들러를 찾을 수 없습니다.${NC}" >&2
    exit 1
fi

echo -e "🤖 ${AGENT_NAME} 에이전트 호출 (Provider: ${YELLOW}${PROVIDER}${NC}, Model: ${YELLOW}${MODEL_NAME}${NC})..." >&2

GENERATED_TEXT=$("$PROVIDER_SCRIPT" "$MODEL_NAME" "$AGENT_PERSONA_FILE" "$INPUT_PROMPT_FILE")

CLEANED_TEXT=$(echo "$GENERATED_TEXT" | sed -e 's/^```[a-zA-Z]*//' -e 's/```$//')
echo "$CLEANED_TEXT"
