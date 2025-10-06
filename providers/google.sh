#!/bin/bash
# Google Gemini API Handler v2.0

set -e

MODEL_NAME=$1
PERSONA_FILE=$2
TASK_FILE=$3

if [ -z "$GEMINI_API_KEY" ]; then
    echo "오류: GEMINI_API_KEY 환경 변수가 설정되지 않았습니다." >&2
    exit 1
fi

API_URL="https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${GEMINI_API_KEY}"
PERSONA_PROMPT=$(cat "$PERSONA_FILE")
TASK_PROMPT=$(cat "$TASK_FILE")

# System Instruction 활용
JSON_PAYLOAD=$(jq -n \
    --arg system "$PERSONA_PROMPT" \
    --arg user "$TASK_PROMPT" \
    '{
        "contents": [{
            "parts": [{"text": $user}]
        }],
        "systemInstruction": {
            "parts": [{"text": $system}]
        },
        "generationConfig": {
            "temperature": 1.0,
            "maxOutputTokens": 8192
        }
    }')

API_RESPONSE=$(curl -s -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" -X POST "$API_URL" --max-time 120)

if ! echo "$API_RESPONSE" | jq -e '.candidates[0].content.parts[0].text' > /dev/null 2>&1; then
    echo "오류: Gemini로부터 유효한 응답을 받지 못했습니다." >&2
    echo "API 응답: $API_RESPONSE" >&2
    exit 1
fi

echo "$API_RESPONSE" | jq -r '.candidates[0].content.parts[0].text'
