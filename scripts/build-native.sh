#!/usr/bin/env bash
# 现有消费者入口；正文和回归唯一归 build.mjs。
set -euo pipefail
script="${BASH_SOURCE[0]}"
while [[ -L "$script" ]]; do
  target="$(readlink "$script")"
  [[ "$target" == /* ]] || target="$(cd "$(dirname "$script")" && pwd -P)/$target"
  script="$target"
done
exec "${NODE:-node}" "$(cd "$(dirname "$script")" && pwd -P)/build.mjs" native "$@"
