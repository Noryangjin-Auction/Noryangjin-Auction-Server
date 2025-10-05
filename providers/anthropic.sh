#!/bin/bash
# Anthropic Claude API Handler

set -e

# --- 입력값 받기 ---
MODEL_NAME=$1
PERSONA_FILE=$2
TASK_FILE=$3

# --- API 키 검증 ---
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "오류: ANTHROPIC_API_KEY 환경 변수가 설정되지 않았습니다." >&2
    exit 1
fi

# --- 프롬프트 및 Payload 생성 ---
API_URL="https://api.anthropic.com/v1/messages"
PERSONA_PROMPT=$(cat "$PERSONA_FILE")
TASK_PROMPT=$(cat "$TASK_FILE")

JSON_PAYLOAD=$(jq -n \
              --arg system_prompt "$PERSONA_PROMPT" \
              --arg user_prompt "$TASK_PROMPT" \
              --arg model "$MODEL_NAME" \
              '{model: $model, max_tokens: 4096, system: $system_prompt, messages: [{role: "user", content: $user_prompt}]}')

# --- API 호출 및 결과 파싱 ---
API_RESPONSE=$(curl -s "$API_URL" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    --data "$JSON_PAYLOAD" --max-time 120)

if ! echo "$API_RESPONSE" | jq -e '.content[0].text' > /dev/null; then
    echo "오류: Claude로부터 유효한 응답을 받지 못했습니다." >&2
    echo "API 응답: $API_RESPONSE" >&2
    exit 1
fi

echo "$API_RESPONSE" | jq -r '.content[0].text'
