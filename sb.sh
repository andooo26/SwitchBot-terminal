#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
URL="https://api.switch-bot.com/v1.0"
ENV_FILE="$SCRIPT_DIR/.env"
DEVICES_FILE="$SCRIPT_DIR/devices.json"

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

if [[ "$1" == "list" ]]; then
  case "$2" in
    devices)
      cat "$DEVICES_FILE"
      exit 0
      ;;
    *)
      echo "listの引数を指定してください"
      exit 1
      ;;
  esac
fi

# setコマンド
if [[ "$1" == "set" ]]; then
  case "$2" in
    key)
      read -p "Enter your API_KEY: " NEW_KEY
      echo "API_KEY=$NEW_KEY" > "$ENV_FILE"
      echo "APIKEY を $ENV_FILE に保存しました"
      exit 0
      ;;
    devices)
      NEW_JSON=$(curl -s -X GET "$URL/devices" -H "Authorization: $API_KEY")

      if [ -f "$DEVICES_FILE" ]; then
        EXISTING_JSON=$(cat "$DEVICES_FILE")
      else
        EXISTING_JSON='{"body":{"deviceList":[],"infraredRemoteList":[]}}'
      fi

      MERGED_JSON=$(jq -s '
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

      echo "$MERGED_JSON" | jq '.' | tee "$DEVICES_FILE"
      ;;
    *)
      echo "何をsetするか指定してください"
      exit 1
      ;;
  esac
fi

# ON/OFF操作
DEVICE_NAME=$(jq -r --arg name "$1" '.body.deviceList[] | select(.unique==$name) | .deviceName' "$DEVICES_FILE")
DEVICE_ID=$(jq -r --arg name "$1" '.body.deviceList[] | select(.unique==$name) | .deviceId' "$DEVICES_FILE")

if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" == "null" ]; then
  echo "デバイスが見つからない,あるいは変更がありませんでした"
  exit 1
fi

case "$2" in
  on)
    curl -s -X POST "$URL/devices/$DEVICE_ID/commands" \
      -H "Authorization: $API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"command":"turnOn","parameter":"default","commandType":"command"}' >/dev/null
    echo "$DEVICE_NAME をONにしました"
    ;;
  off)
    curl -s -X POST "$URL/devices/$DEVICE_ID/commands" \
      -H "Authorization: $API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"command":"turnOff","parameter":"default","commandType":"command"}' >/dev/null
    echo "$DEVICE_NAME をOFFにしました"
    ;;
  *)
    echo "ON/OFFを指定してください"
    exit 1
    ;;
esac
