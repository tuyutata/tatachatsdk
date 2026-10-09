#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
protocol_dir="$root/lib/protocol"
# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。
PRODUCT_TEMP_SCRIPT="${BASH_SOURCE[0]}"
while [[ -L "$PRODUCT_TEMP_SCRIPT" ]]; do
  PRODUCT_TEMP_LINK="$(readlink "$PRODUCT_TEMP_SCRIPT")"
  [[ "$PRODUCT_TEMP_LINK" == /* ]] || PRODUCT_TEMP_LINK="$(cd "$(dirname "$PRODUCT_TEMP_SCRIPT")" && pwd -P)/$PRODUCT_TEMP_LINK"
  PRODUCT_TEMP_SCRIPT="$PRODUCT_TEMP_LINK"
done
PRODUCT_TEMP_SOURCE="$(cd "$(dirname "$PRODUCT_TEMP_SCRIPT")/.." && pwd -P)"
PRODUCT_TARGET_TEMP_ROOT="$("${PRODUCT_NODE_BIN:-${NODE:-node}}" "$PRODUCT_TEMP_SOURCE/scripts/build.mjs" temporary-root "${PLATFORM:-${platform:-}}" 'sdk')" || exit 1
if [[ -z "${PRODUCT_WORK_DIR:-}" && "${TMPDIR:-}" != "$PRODUCT_TEMP_SOURCE/target/"* ]]; then
  export TMPDIR="$PRODUCT_TARGET_TEMP_ROOT/"
fi
work_dir="${TATACHATSDK_PROTOCOL_WORK_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tatachatsdk/protocol-tools}"

[[ "$#" -eq 0 ]] || { printf '%s\n' 'TataChatSDK协议生成不接受参数' >&2; exit 1; }
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) protoc_platform=macos ;;
  Linux/aarch64) protoc_platform=linux-arm ;;
  Linux/x86_64) protoc_platform=linux-amd ;;
  *) printf '%s\n' 'TataChatSDK协议生成宿主不受支持' >&2; exit 1 ;;
esac

# 两项生成工具均由SDK自己的锁定声明准备到源码外目录；禁止读取系统PATH中的偶然版本。
protoc_executable="$(node "$root/scripts/dependencies.mjs" prepare protoc "$protoc_platform" \
  "$work_dir/protoc/$protoc_platform")"
plugin_executable="$(node "$root/scripts/dependencies.mjs" prepare protoc_plugin sdk \
  "$work_dir/protoc-plugin")"
[[ "$protoc_executable" = /* && -f "$protoc_executable" && -x "$protoc_executable" ]] \
  || { printf '%s\n' 'TataChatSDK protoc路径无效' >&2; exit 1; }
[[ "$plugin_executable" = /* && -f "$plugin_executable" && -x "$plugin_executable" ]] \
  || { printf '%s\n' 'TataChatSDK protoc_plugin路径无效' >&2; exit 1; }
[[ "$("$protoc_executable" --version)" == 'libprotoc 35.0' ]] \
  || { printf '%s\n' 'TataChatSDK protoc版本无效' >&2; exit 1; }

"$protoc_executable" \
  --proto_path="$protocol_dir" \
  --dart_out="$protocol_dir" \
  --plugin="protoc-gen-dart=$plugin_executable" \
  "$protocol_dir/basic_content.proto" \
  "$protocol_dir/media_content.proto" \
  "$protocol_dir/message.proto" \
  "$protocol_dir/attachment.proto" \
  "$protocol_dir/chat_frame.proto"
