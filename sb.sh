#!/bin/bash

URL="https://api.switch-bot.com/v1.0"
ENV_FILE=".env"
DEVICES_FILE="devices.json"

# .envよりAPI_KEY
if [ -f "$ENV_FILE" ]; then
  export $(cat "$ENV_FILE" | xargs)
else
  exit 1
fi

# 引数なし
if [ $# -eq 0 ]; then
  echo "引数を指定してください"
  exit 1
fi

command=$1
subcommand=$2

# 引数で分岐
case "$command" in
  # listコマンド
  list)
    case "$subcommand" in

      *)
        echo "正しい引数を指定してください"
        exit 1
        ;;
    esac
    ;;

  # setコマンド
  set)
    case "$subcommand" in
      key)
        read -p "Enter your API_KEY: " NEW_KEY
        echo "API_KEY=$NEW_KEY" > "$ENV_FILE"
        echo "API_KEY を $ENV_FILE に保存しました"
        exit 0
        ;;
      devices)
        curl -s -X GET "$URL/devices" \
        -H "Authorization: $API_KEY" | jq '.body.deviceList |= map(. + {unique: ""}) | .body.infraredRemoteList |= map(. + {unique: ""})' | tee "$DEVICES_FILE"
        ;;
      *)
        echo "正しい引数を指定してください"
        exit 1
        ;;
    esac
    ;;
esac
