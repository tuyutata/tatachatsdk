#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
protocol_dir="$root/lib/src/protocol"
work_dir="${TATACHATSDK_PROTOCOL_WORK_DIR:-${TMPDIR:-/tmp}/tatachatsdk/protocol-tools}"

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
