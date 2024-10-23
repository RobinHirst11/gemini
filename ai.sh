#!/bin/bash

MEMORY_FILE="$HOME/.ai_chat_history.json"
API_KEY="go to https://aistudio.google.com"
MAX_HISTORY=10

if [ ! -f "$MEMORY_FILE" ]; then
    echo "[]" > "$MEMORY_FILE"
fi

if [ $# -eq 0 ]; then
    echo 'Usage: ./ai.sh "your message here"'
    echo 'Commands:'
    echo '  --clear    Clear conversation history'
    echo '  --history  Show conversation history'
    exit 1
fi

case "$1" in
    --clear)
        echo "[]" > "$MEMORY_FILE"
        echo "Conversation history cleared."
        exit 0
        ;;
    --history)
        echo "Recent conversation history:"
        jq -r '.[] | "\n[" + .timestamp + "]\nUser: " + .user + "\nAI: " + .response' "$MEMORY_FILE"
        exit 0
        ;;
esac

context=$(jq -c '[.[] | {role: "user", parts: [{text: .user}]}, {role: "assistant", parts: [{text: .response}]}]' "$MEMORY_FILE")


if [ "$context" = "[]" ]; then
    context=""
else
    context="${context:1:-1},"
fi

timestamp=$(date "+%Y-%m-%d %H:%M:%S")

response=$(curl -s \
    -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-002:generateContent?key=${API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{
        \"contents\": [
            ${context}
            {
                \"role\": \"user\",
                \"parts\": [{
                    \"text\": \"$*\"
                }]
            }
        ],
        \"generationConfig\": {
            \"temperature\": 1,
            \"topK\": 40,
            \"topP\": 0.95,
            \"maxOutputTokens\": 8192,
            \"responseMimeType\": \"text/plain\"
        }
    }")

ai_response=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null || echo "Error processing API response")

temp_file=$(mktemp)
(
    jq --arg timestamp "$timestamp" \
       --arg user "$*" \
       --arg response "$ai_response" \
       '. + [{timestamp: $timestamp, user: $user, response: $response}] | if length > '$MAX_HISTORY' then .[1:] else . end' \
       "$MEMORY_FILE" > "$temp_file" && mv "$temp_file" "$MEMORY_FILE"
) 2>/dev/null

printf "%s\n" "$ai_response"
