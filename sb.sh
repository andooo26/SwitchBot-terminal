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

  # onコマンド
  on)
    if [ -z "$subcommand" ]; then
        echo "Usage: $0 on <uniqueName>"
        exit 1
    fi
    DEVICE_NAME=$(jq -r --arg name "$subcommand" '.body.deviceList[] | select(.unique==$name) | .deviceName' "$DEVICES_FILE")
    DEVICE_ID=$(jq -r --arg name "$subcommand" '.body.deviceList[] | select(.unique==$name) | .deviceId' "$DEVICES_FILE")

    if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" == "null" ]; then
        echo "デバイスが見つかりません: $subcommand"
        exit 1
    fi
    curl -s -X POST "$URL/devices/$DEVICE_ID/commands" \
      -H "Authorization: $API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"command":"turnOn","parameter":"default","commandType":"command"}' >/dev/null

    echo "$DEVICE_NAME をONにしました"
    ;;

  # offコマンド
  off)
    if [ -z "$subcommand" ]; then
        echo "Usage: $0 off <uniqueName>"
        exit 1
    fi
    DEVICE_NAME=$(jq -r --arg name "$subcommand" '.body.deviceList[] | select(.unique==$name) | .deviceName' "$DEVICES_FILE")
    DEVICE_ID=$(jq -r --arg name "$subcommand" '.body.deviceList[] | select(.unique==$name) | .deviceId' "$DEVICES_FILE")

    if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" == "null" ]; then
        echo "デバイスが見つかりません: $subcommand"
        exit 1
    fi
    curl -s -X POST "$URL/devices/$DEVICE_ID/commands" \
      -H "Authorization: $API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"command":"turnOff","parameter":"default","commandType":"command"}' >/dev/null

    echo "$DEVICE_NAME をOFFにしました"
    ;;

  # listコマンド
  list)
    case "$subcommand" in
      devices)
        cat devices.json
        exit 0
        ;;
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
        NEW_JSON=$(curl -s -X GET "$URL/devices" -H "Authorization: $API_KEY")

        if [ -f "$DEVICES_FILE" ]; then
          EXISTING_JSON=$(cat "$DEVICES_FILE")
        else
          EXISTING_JSON='{"body":{"deviceList":[],"infraredRemoteList":[]}}'
        fi

        # jqでマージ,unique保持
        MERGED_JSON=$(jq -s '
          # $existing = .[0], $new = .[1]
          .[0] as $existing | .[1] as $new |
          {
            statusCode: $new.statusCode,
            message: $new.message,
            body: {
              deviceList: (
                ($existing.body.deviceList + $new.body.deviceList
                | map(. + ({unique: (.unique // "")}))
                | unique_by(.deviceId))
              ),
              infraredRemoteList: (
                ($existing.body.infraredRemoteList + $new.body.infraredRemoteList
                | map(. + ({unique: (.unique // "")}))
                | unique_by(.deviceId))
              )
            }
          }
        ' <(echo "$EXISTING_JSON") <(echo "$NEW_JSON"))

        # 保存
        echo "$MERGED_JSON" | jq '.' | tee "$DEVICES_FILE"
        ;;
      *)
        echo "正しい引数を指定してください"
        exit 1
        ;;
    esac
    ;;
esac
