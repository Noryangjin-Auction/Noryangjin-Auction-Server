#!/bin/bash
# Google Gemini API Handler

set -e

# --- 입력값 받기 ---
MODEL_NAME=$1
PERSONA_FILE=$2
TASK_FILE=$3

# --- API 키 검증 ---
if [ -z "$GEMINI_API_KEY" ]; then
    echo "오류: GEMINI_API_KEY 환경 변수가 설정되지 않았습니다." >&2
    exit 1
fi

# --- 프롬프트 및 Payload 생성 ---
API_URL="https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${GEMINI_API_KEY}"
PERSONA_PROMPT=$(cat "$PERSONA_FILE")
TASK_PROMPT=$(cat "$TASK_FILE")
FULL_PROMPT="${PERSONA_PROMPT}\n\n${TASK_PROMPT}"

JSON_PAYLOAD=$(jq -n --arg prompt "$FULL_PROMPT" '{contents: [{parts: [{text: $prompt}]}]}')

# --- API 호출 및 결과 파싱 ---
API_RESPONSE=$(curl -s -H "Content-Type: application/json" -d "$JSON_PAYLOAD" -X POST "$API_URL" --max-time 120)

if ! echo "$API_RESPONSE" | jq -e '.candidates[0].content.parts[0].text' > /dev/null; then
    echo "오류: Gemini로부터 유효한 응답을 받지 못했습니다." >&2
    echo "API 응답: $API_RESPONSE" >&2
    exit 1
fi

echo "$API_RESPONSE" | jq -r '.candidates[0].content.parts[0].text'