#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-host}"
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  LINK_TARGET="$(readlink "$SCRIPT_PATH")"
  [[ "$LINK_TARGET" == /* ]] || LINK_TARGET="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)/$LINK_TARGET"
  SCRIPT_PATH="$LINK_TARGET"
done
ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)"
MANIFEST="$ROOT/native/Cargo.toml"
TATACHATSDK_WORK_DIR="${TATACHATSDK_WORK_DIR:-${TMPDIR:-/tmp}/tatachatsdk/work}"
TATACHATSDK_NATIVE_OUTPUT_DIR="${TATACHATSDK_NATIVE_OUTPUT_DIR:-${TMPDIR:-/tmp}/tatachatsdk/output}"
TATACHATSDK_NATIVE_ANDROID_DIR="${TATACHATSDK_NATIVE_ANDROID_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/android}"
TATACHATSDK_NATIVE_IOS_DIR="${TATACHATSDK_NATIVE_IOS_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/ios}"
TATACHATSDK_NATIVE_MACOS_DIR="${TATACHATSDK_NATIVE_MACOS_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/macos}"
TARGET_DIR="${CARGO_TARGET_DIR:-$TATACHATSDK_WORK_DIR/cargo}"
export CARGO_TARGET_DIR="$TARGET_DIR"
export TATACHATSDK_WORK_DIR TATACHATSDK_NATIVE_OUTPUT_DIR
export TATACHATSDK_NATIVE_ANDROID_DIR TATACHATSDK_NATIVE_IOS_DIR TATACHATSDK_NATIVE_MACOS_DIR

case "$MODE" in
  host|macos|android|ios)
    python3 - "$ROOT" "$TATACHATSDK_WORK_DIR" "$TATACHATSDK_NATIVE_OUTPUT_DIR" \
      "$TATACHATSDK_NATIVE_ANDROID_DIR" "$TATACHATSDK_NATIVE_IOS_DIR" \
      "$TATACHATSDK_NATIVE_MACOS_DIR" "$TARGET_DIR" <<'CHECK_OUTPUTS'
from pathlib import Path
import sys
source = Path(sys.argv[1]).resolve()
for value in sys.argv[2:]:
    raw, target = Path(value), Path(value).resolve()
    if not raw.is_absolute() or target == source or source in target.parents:
        raise SystemExit(f'TataChatSDK可写目录必须是源码外绝对路径：{value}')
CHECK_OUTPUTS
    mkdir -p "$TATACHATSDK_WORK_DIR" "$TATACHATSDK_NATIVE_OUTPUT_DIR"
    ;;
esac

# 中文注释：Rust 1.97.1 的优化型宿主 proc-macro 会产生不可加载的错位 Mach-O；
# 仅把 Release 构建依赖固定为非优化、非裁剪，产品目标仍保持 optimized Release。
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_OPT_LEVEL=0
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=0
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP=none

ensure_target() {
  local target="$1"
  local compiler="${RUSTC:-rustc}" sysroot libdir library
  # 只核对实际编译器已具备的目标库；工具准备由开发环境或CI负责。
  sysroot="$("$compiler" --print sysroot)" || return 1
  libdir="$("$compiler" --print target-libdir --target "$target")" || return 1
  # 仅统一官方Windows路径分隔符，不选择其他工具或目标。
  sysroot="${sysroot//\\//}"; libdir="${libdir//\\//}"
  if [[ "$libdir" == "$sysroot/lib/rustlib/$target/lib" && -d "$libdir" && ! -L "$libdir" ]]; then
    for library in "$libdir"/libstd-*.rlib; do [[ -s "$library" && ! -L "$library" ]] && return 0; done
  fi
  echo "Rust目标标准库缺失，请先在产品开发环境准备：$target" >&2
  return 1
}

assert_symbols() {
  local library="$1"
  local nm_bin="${2:-nm}"
  local symbols
  local nm_args=(-g)
  # Gradle strips the regular ELF symbol table from the final APK but retains
  # the dynamic exports required by Dart FFI. Read that runtime-visible table
  # for ELF only; Mach-O keeps its existing global-symbol verification.
  if file -b "$library" | grep -q 'ELF'; then
    nm_args=(-D --defined-only)
  fi
  symbols="$("$nm_bin" "${nm_args[@]}" "$library" 2>/dev/null | awk '{print $NF}' || true)"
  local required_symbols=(
    tatachat_sdk_mls_create_key_package_json
    tatachat_sdk_mls_group_create_json
    tatachat_sdk_mls_group_add_members_json
    tatachat_sdk_mls_group_remove_members_json
    tatachat_sdk_mls_group_create_message_json
    tatachat_sdk_mls_group_process_json
    tatachat_sdk_mls_group_state_json
    tatachat_sdk_free_string
  )
  local symbol
  for symbol in "${required_symbols[@]}"; do
    if [[ "$(grep -Ec "^_?${symbol}$" <<<"$symbols" || true)" != 1 ]]; then
      printf 'TataChatSDK required symbol %s must occur once in %s\n' \
        "$symbol" "$library" >&2
      exit 1
    fi
  done

  # 中文注释：原始 HPKE 与独立设备身份接口已被统一 OpenMLS 群协议取代，禁止重新导出。
  if grep -Eq '^_?tatachat_sdk_(device_identity|mls_encrypt|mls_decrypt)_json$' <<<"$symbols"; then
    printf 'TataChatSDK legacy direct-encryption symbols found in %s\n' "$library" >&2
    exit 1
  fi
}

build_host() {
  cargo build --manifest-path "$MANIFEST" --locked
  case "$(uname -s)" in
    Darwin) library="$TARGET_DIR/debug/libtatachat_sdk.dylib" ;;
    Linux) library="$TARGET_DIR/debug/libtatachat_sdk.so" ;;
    *) printf 'Unsupported TataChatSDK host\n' >&2; exit 1 ;;
  esac
  assert_symbols "$library"
}

build_android() {
  ensure_target aarch64-linux-android

  local ndk_home="${ANDROID_NDK_HOME:-}"
  if [[ -z "$ndk_home" ]]; then
    local sdk_home="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    ndk_home="$(ls -d "$sdk_home/ndk/"* 2>/dev/null | sort -V | tail -1 || true)"
  fi
  [[ -d "$ndk_home" ]] || { printf 'Android NDK not found\n' >&2; exit 1; }

  local toolchain
  case "$(uname -s)" in
    Darwin)
      toolchain="$ndk_home/toolchains/llvm/prebuilt/darwin-x86_64"
      [[ -d "$toolchain" ]] ||
        toolchain="$ndk_home/toolchains/llvm/prebuilt/darwin-aarch64"
      ;;
    Linux) toolchain="$ndk_home/toolchains/llvm/prebuilt/linux-x86_64" ;;
    *) printf 'Unsupported Android build host\n' >&2; exit 1 ;;
  esac
  [[ -d "$toolchain" ]] || {
    printf 'Android NDK toolchain not found\n' >&2
    exit 1
  }

  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$toolchain/bin/aarch64-linux-android24-clang"
  export CC_aarch64_linux_android="$toolchain/bin/aarch64-linux-android24-clang"
  export AR_aarch64_linux_android="$toolchain/bin/llvm-ar"
  cargo build --manifest-path "$MANIFEST" --release --target aarch64-linux-android --locked

  local destination="$TATACHATSDK_NATIVE_ANDROID_DIR/arm64-v8a"
  mkdir -p "$destination"
  cp "$TARGET_DIR/aarch64-linux-android/release/libtatachat_sdk.so" "$destination/"
  assert_symbols "$destination/libtatachat_sdk.so" "$toolchain/bin/llvm-nm"
}

build_ios() {
  ensure_target aarch64-apple-ios
  export IPHONEOS_DEPLOYMENT_TARGET=16.0
  # Write the final framework install name during the Rust link. Rust 1.97's
  # Mach-O strip path can leave LC_SYMTAB.stroff only 4-byte aligned, which
  # current Xcode rejects; keep Rust output unstripped and let Xcode process the
  # final signed app instead.
  local ios_rustflags="${CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS:-}"
  ios_rustflags="${ios_rustflags:+$ios_rustflags }-C strip=none -C link-arg=-Wl,-install_name,@rpath/TataChatSDK.framework/TataChatSDK"
  CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS="$ios_rustflags" \
    cargo build --manifest-path "$MANIFEST" --release --target aarch64-apple-ios --locked

  local library="$TARGET_DIR/aarch64-apple-ios/release/libtatachat_sdk.dylib"
  local framework_root="$TARGET_DIR/ios-framework"
  local framework="$framework_root/TataChatSDK.framework"
  local xcframework="$TATACHATSDK_NATIVE_IOS_DIR/TataChatSDK.xcframework"
  local nm_bin
  nm_bin="$(xcrun --find llvm-nm)"
  assert_symbols "$library" "$nm_bin"
  local string_offset
  string_offset="$(otool -l "$library" | awk '/cmd LC_SYMTAB/{active=1;next} active&&/cmd /{active=0} active&&/stroff/{print $2}')"
  [[ -n "$string_offset" && $((string_offset % 8)) -eq 0 ]] || {
    printf 'TataChatSDK iOS LINKEDIT string pool is not 8-byte aligned\n' >&2
    exit 1
  }

  # 中文注释：TataChatSDK 以自己的动态 Framework 进入宿主，Smoldot 不再承载或
  # 保活任何聊天符号。Framework 的 install name 固定为标准 @rpath，由 Xcode
  # 嵌入并签名，Dart FFI 只解析这一份已经装载的动态库。
  if [[ -e "$framework_root" ]]; then
    find "$framework_root" -depth -delete
  fi
  mkdir -p "$framework/Headers" "$framework/Modules"
  cp "$library" "$framework/TataChatSDK"
  chmod 755 "$framework/TataChatSDK"
  cp "$ROOT/tatachat_sdk.h" "$framework/Headers/tatachat_sdk.h"
  cat > "$framework/Modules/module.modulemap" <<'MODULEMAP'
framework module TataChatSDK {
  umbrella header "tatachat_sdk.h"
  export *
}
MODULEMAP
  cat > "$framework/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>TataChatSDK</string>
  <key>CFBundleIdentifier</key><string>org.cocoapods.TataChatSDK</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>TataChatSDK</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>16.0</string>
</dict>
</plist>
PLIST
  assert_symbols "$framework/TataChatSDK" "$nm_bin"

  mkdir -p "$TATACHATSDK_NATIVE_IOS_DIR"
  if [[ -e "$xcframework" ]]; then
    find "$xcframework" -depth -delete
  fi
  xcodebuild -create-xcframework -framework "$framework" -output "$xcframework"

  local packaged
  packaged="$(find "$xcframework" -type f -path '*/TataChatSDK.framework/TataChatSDK' -print -quit)"
  [[ -n "$packaged" ]] || {
    printf 'TataChatSDK XCFramework missing dynamic binary\n' >&2
    exit 1
  }
  [[ "$(lipo -archs "$packaged")" == arm64 ]] || {
    printf 'TataChatSDK iOS framework must contain only arm64\n' >&2
    exit 1
  }
  assert_symbols "$packaged" "$nm_bin"
  otool -D "$packaged" | tail -n +2 | grep -qx '@rpath/TataChatSDK.framework/TataChatSDK' || {
    printf 'TataChatSDK iOS framework install name is invalid\n' >&2
    exit 1
  }
}

build_macos() {
  ensure_target aarch64-apple-darwin
  export MACOSX_DEPLOYMENT_TARGET=13.0

  # 中文注释：目标专属参数不得污染宿主 proc-macro；host 模式仍只服务本机调试测试。
  local macos_rustflags="${CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS:-}"
  macos_rustflags="${macos_rustflags:+$macos_rustflags }-C strip=none -C link-arg=-Wl,-install_name,@rpath/libtatachat_sdk.dylib"
  CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS="$macos_rustflags" \
    cargo build --manifest-path "$MANIFEST" --release --target aarch64-apple-darwin --locked

  local library="$TARGET_DIR/aarch64-apple-darwin/release/libtatachat_sdk.dylib"
  local destination="$TATACHATSDK_NATIVE_MACOS_DIR/libtatachat_sdk.dylib"
  local nm_bin
  nm_bin="$(xcrun --find llvm-nm)"
  mkdir -p "$TATACHATSDK_NATIVE_MACOS_DIR"
  cp "$library" "$destination"
  [[ "$(lipo -archs "$destination")" == arm64 ]] || {
    printf 'TataChatSDK macOS library must contain only arm64\n' >&2
    exit 1
  }
  file "$destination" | grep -q 'dynamically linked shared library' || {
    printf 'TataChatSDK macOS artifact is not a dynamic library\n' >&2
    exit 1
  }
  assert_symbols "$destination" "$nm_bin"
  otool -D "$destination" | tail -n +2 | grep -qx '@rpath/libtatachat_sdk.dylib' || {
    printf 'TataChatSDK macOS install name is invalid\n' >&2
    exit 1
  }
}

verify_android_package() {
  local package="${1:?Android package is required}"
  local entry temporary packaged nm_bin
  [[ -f "$package" ]] || { printf 'Android package not found: %s\n' "$package" >&2; exit 1; }
  case "$package" in
    *.apk) entry='lib/arm64-v8a/libtatachat_sdk.so' ;;
    *.aab) entry='base/lib/arm64-v8a/libtatachat_sdk.so' ;;
    *) printf 'Unsupported Android package: %s\n' "$package" >&2; exit 1 ;;
  esac
  temporary="$(mktemp -d)"
  packaged="$temporary/libtatachat_sdk.so"
  unzip -p "$package" "$entry" > "$packaged" || {
    find "$temporary" -depth -delete
    printf 'Android package missing TataChatSDK library\n' >&2
    exit 1
  }
  nm_bin="${ANDROID_NM:-}"
  if [[ -z "$nm_bin" ]]; then
    local sdk_home="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    nm_bin="$(ls "$sdk_home"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-nm 2>/dev/null | tail -1 || true)"
  fi
  [[ -n "$nm_bin" ]] || {
    find "$temporary" -depth -delete
    printf 'Android llvm-nm not found\n' >&2
    exit 1
  }
  assert_symbols "$packaged" "$nm_bin"
  find "$temporary" -depth -delete
  if unzip -Z1 "$package" | grep -E '(^|/)lib/(armeabi-v7a|x86|x86_64)/libtatachat_sdk\.so$'; then
    printf 'Android package contains unsupported TataChatSDK ABI\n' >&2
    exit 1
  fi
}

verify_ios_package() {
  local app_bundle="${1:?Runner.app is required}"
  local executable="$app_bundle/Runner"
  local framework="$app_bundle/Frameworks/TataChatSDK.framework/TataChatSDK"
  local nm_bin
  [[ -f "$executable" ]] || { printf 'iOS Runner not found\n' >&2; exit 1; }
  [[ -f "$framework" ]] || { printf 'iOS package missing TataChatSDK.framework\n' >&2; exit 1; }
  [[ "$(lipo -archs "$framework")" == arm64 ]] || {
    printf 'Packaged TataChatSDK framework must contain only arm64\n' >&2
    exit 1
  }
  file "$framework" | grep -q 'dynamically linked shared library' || {
    printf 'Packaged TataChatSDK binary is not a dynamic framework\n' >&2
    exit 1
  }
  otool -L "$executable" | grep -q '@rpath/TataChatSDK.framework/TataChatSDK' || {
    printf 'iOS Runner does not link the independent TataChatSDK framework\n' >&2
    exit 1
  }
  nm_bin="$(xcrun --find llvm-nm)"
  assert_symbols "$framework" "$nm_bin"
}

case "$MODE" in
  host) build_host ;;
  macos) build_macos ;;
  android) build_android ;;
  ios) build_ios ;;
  verify-android-package) verify_android_package "${2:-}" ;;
  verify-ios-package) verify_ios_package "${2:-}" ;;
  *) printf 'Usage: %s [host|macos|android|ios|verify-android-package|verify-ios-package]\n' "$0" >&2; exit 64 ;;
esac
