#!/usr/bin/env node
// 本仓本目标的完整自动化只由同名Workflow调用；版本与产物均在GitHub生成。
import { createHash } from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';
import { appendFileSync, copyFileSync, createReadStream, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const owner = Object.freeze({"product": "tatachatsdk", "platform": "sdk", "repository": "tuyutata/tatachatsdk", "version_source": {"kind": "pubspec-package", "path": "pubspec.yaml"}, "required_assets": ["tatachatsdk.tgz"], "asset_locations": ["$RUNNER_TEMP/tatachatsdk/release"], "asset_patterns": ["tatachatsdk.tgz"], "required_patterns": ["tatachatsdk.tgz"]});
const commands = Object.freeze({
  "3": {
    "shell": "bash",
    "source": "output=\"$RUNNER_TEMP/tatachatsdk/release\"\nnode .github/workflows/release-sdk.mjs package \\\n  --source . \\\n  --native \"$RUNNER_TEMP/tatachatsdk/native\" \\\n  --output \"$output\" \\\n  --archive \"$output/tatachatsdk.tgz\" \\\n  --git-sha \"$SOURCE_SHA\" \\\n  --software-version \"$SOFTWARE_VERSION\"\nnode .github/workflows/release-sdk.mjs verify-assets \"$output\" \\\n  --expected-git-sha \"$SOURCE_SHA\" \\\n  --software-version \"$SOFTWARE_VERSION\""
  },
  "check-3": {
    "shell": "bash",
    "source": "test \"$(git rev-parse HEAD)\" = \"$SOURCE_SHA\"\nnode --test .github/workflows/release-sdk.mjs\n"
  },
  "check-6": {
    "shell": "bash",
    "source": "# 安装后先验真，再统一准备目标平台缓存与受控修订。\nflutter --version --machine >/dev/null\nplatform=\"sdk\"\nflutter --version >/dev/null\n"
  },
  "check-7": {
    "shell": "bash",
    "source": "sdkmanager \"ndk;28.2.13676358\""
  },
  "check-8": {
    "shell": "bash",
    "source": "build_source=\"$RUNNER_TEMP/tatachatsdk/build-source\"\ntest ! -e \"$build_source\"\nmkdir -p \"$(dirname \"$build_source\")\"\n# 新仓根直接复制受控源码；Git 元数据不进入源码外临时编译目录。\nnode --input-type=module <<'NODE'\nimport { cpSync, mkdirSync, readdirSync } from 'node:fs';\nimport { join } from 'node:path';\nconst output=`${process.env.RUNNER_TEMP}/tatachatsdk/build-source`;mkdirSync(output,{recursive:true});\nfor(const name of readdirSync(process.env.GITHUB_WORKSPACE)){if(['.git','target'].includes(name))continue;cpSync(join(process.env.GITHUB_WORKSPACE,name),join(output,name),{recursive:true});}\nNODE\nnode .github/workflows/release-sdk.mjs analysis-options \"$GITHUB_WORKSPACE\" \"$build_source\"\n"
  },
  "check-9": {
    "shell": "bash",
    "source": "set -euo pipefail\nflutter pub get --enforce-lockfile\ndart format --output=none --set-exit-if-changed lib test\nflutter analyze\ncargo test --manifest-path native/Cargo.toml --all-targets --locked\nexport PRODUCT_WORK_DIR=\"$PWD/target/test\"\nexport CARGO_TARGET_DIR=\"$PRODUCT_WORK_DIR/cargo\"\nexport TATACHATSDK_WORK_DIR=\"$PRODUCT_WORK_DIR/native\"\nexport TATACHATSDK_NATIVE_OUTPUT_DIR=\"$PRODUCT_WORK_DIR/output\"\ntrap 'node ./.github/workflows/release-sdk.mjs native-finish test' EXIT\nnode ./.github/workflows/release-sdk.mjs native host\nexport ISAR_CORE_LIB_PATH=\"$(node \"$GITHUB_WORKSPACE/.github/workflows/release-sdk.mjs\" isar \"$PWD/.dart_tool/package_config.json\" \"$PUB_CACHE\" \"$PWD/pubspec.lock\")\"\nexport DYLD_LIBRARY_PATH=\"$CARGO_TARGET_DIR/debug\"\nexport LD_LIBRARY_PATH=\"$CARGO_TARGET_DIR/debug\"\nflutter test\n"
  },
  "check-10": {
    "shell": "bash",
    "source": "build_source=\"$RUNNER_TEMP/tatachatsdk/build-source\"\nnative_output=\"$RUNNER_TEMP/tatachatsdk/native\"\nandroid_stage=\"$RUNNER_TEMP/tatachatsdk/android-stage\"\nmkdir -p \"$native_output/android\" \"$native_output/ios\" \"$native_output/macos\"\n# 本仓自动化独立编译三端原生组件，不调用本机编译入口。\nTATACHATSDK_NATIVE_ANDROID_DIR=\"$android_stage\" \\\n  node \"$build_source/.github/workflows/release-sdk.mjs\" native android \"$build_source\"\ncp \"$android_stage/arm64-v8a/libtatachat_sdk.so\" \\\n  \"$native_output/android/libtatachat_sdk.so\"\nTATACHATSDK_NATIVE_IOS_DIR=\"$native_output/ios\" \\\n  node \"$build_source/.github/workflows/release-sdk.mjs\" native ios \"$build_source\"\nTATACHATSDK_NATIVE_MACOS_DIR=\"$native_output/macos\" \\\n  node \"$build_source/.github/workflows/release-sdk.mjs\" native macos \"$build_source\"\nprintf '%s\n' \"$SOURCE_SHA\" > \"$RUNNER_TEMP/tatachatsdk/source-sha.txt\"\n"
  }
});
const shaPattern = /^[0-9a-f]{40}$/u;
const fail = message => { throw new Error(message); };
const root = fileURLToPath(new URL('../../', import.meta.url));
const workflowPath = `.github/workflows/release-${owner.platform}.yml`;
const prefix = `${owner.product}-${owner.platform}-v`;

// 自动化独立拥有自身的三端编译与正式包；不调用产品编译、发布入口。
const AUTOMATION_NATIVE_SHELL = "#!/usr/bin/env bash\nset -euo pipefail\n\nMODE=\"${1:-host}\"\nROOT=\"${TATACHATSDK_SOURCE_ROOT:?缺少本产品源码根}\"\nMANIFEST=\"$ROOT/native/Cargo.toml\"\n# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。\nPRODUCT_TEMP_SOURCE=\"$ROOT\"\nPRODUCT_TARGET_TEMP_ROOT=\"${PRODUCT_WORK_DIR:?缺少自动化独占工作根}\"\nif [[ -z \"${PRODUCT_WORK_DIR:-}\" && \"${TMPDIR:-}\" != \"$PRODUCT_TEMP_SOURCE/target/\"* ]]; then\n  export TMPDIR=\"$PRODUCT_TARGET_TEMP_ROOT/\"\nfi\nTATACHATSDK_WORK_DIR=\"${TATACHATSDK_WORK_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tatachatsdk/work}\"\nTATACHATSDK_NATIVE_OUTPUT_DIR=\"${TATACHATSDK_NATIVE_OUTPUT_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tatachatsdk/output}\"\nTATACHATSDK_NATIVE_ANDROID_DIR=\"${TATACHATSDK_NATIVE_ANDROID_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/android}\"\nTATACHATSDK_NATIVE_IOS_DIR=\"${TATACHATSDK_NATIVE_IOS_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/ios}\"\nTATACHATSDK_NATIVE_MACOS_DIR=\"${TATACHATSDK_NATIVE_MACOS_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/macos}\"\nTARGET_DIR=\"${CARGO_TARGET_DIR:-$TATACHATSDK_WORK_DIR/cargo}\"\nexport CARGO_TARGET_DIR=\"$TARGET_DIR\"\nexport TATACHATSDK_WORK_DIR TATACHATSDK_NATIVE_OUTPUT_DIR\nexport TATACHATSDK_NATIVE_ANDROID_DIR TATACHATSDK_NATIVE_IOS_DIR TATACHATSDK_NATIVE_MACOS_DIR\n\ncase \"$MODE\" in\n  host|macos|android|ios)\n    python3 - \"$ROOT\" \"$TATACHATSDK_WORK_DIR\" \"$TATACHATSDK_NATIVE_OUTPUT_DIR\" \\\n      \"$TATACHATSDK_NATIVE_ANDROID_DIR\" \"$TATACHATSDK_NATIVE_IOS_DIR\" \\\n      \"$TATACHATSDK_NATIVE_MACOS_DIR\" \"$TARGET_DIR\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource = Path(sys.argv[1]).resolve()\nfor value in sys.argv[2:]:\n    raw, target = Path(value), Path(value).resolve()\n    if not raw.is_absolute() or target == source or (source in target.parents and source / 'target' not in target.parents):\n        raise SystemExit(f'TataChatSDK可写目录必须是源码外绝对路径：{value}')\nCHECK_OUTPUTS\n    mkdir -p \"$TATACHATSDK_WORK_DIR\" \"$TATACHATSDK_NATIVE_OUTPUT_DIR\"\n    ;;\nesac\n\n# 中文注释：Rust 1.97.1 的优化型宿主 proc-macro 会产生不可加载的错位 Mach-O；\n# 仅把 Release 构建依赖固定为非优化、非裁剪，产品目标仍保持 optimized Release。\nexport CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_OPT_LEVEL=0\nexport CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=0\nexport CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP=none\n\nensure_target() {\n  local target=\"$1\"\n  local compiler=\"${RUSTC:-rustc}\" sysroot libdir library\n  # 只核对实际编译器已具备的目标库；工具准备由开发环境或CI负责。\n  sysroot=\"$(\"$compiler\" --print sysroot)\" || return 1\n  libdir=\"$(\"$compiler\" --print target-libdir --target \"$target\")\" || return 1\n  # 仅统一官方Windows路径分隔符，不选择其他工具或目标。\n  sysroot=\"${sysroot//\\\\//}\"; libdir=\"${libdir//\\\\//}\"\n  if [[ \"$libdir\" == \"$sysroot/lib/rustlib/$target/lib\" && -d \"$libdir\" && ! -L \"$libdir\" ]]; then\n    for library in \"$libdir\"/libstd-*.rlib; do [[ -s \"$library\" && ! -L \"$library\" ]] && return 0; done\n  fi\n  echo \"Rust目标标准库缺失，请先在产品开发环境准备：$target\" >&2\n  return 1\n}\n\nassert_symbols() {\n  local library=\"$1\"\n  local nm_bin=\"${2:-nm}\"\n  local symbols\n  local nm_args=(-g)\n  # Gradle strips the regular ELF symbol table from the final APK but retains\n  # the dynamic exports required by Dart FFI. Read that runtime-visible table\n  # for ELF only; Mach-O keeps its existing global-symbol verification.\n  if file -b \"$library\" | grep -q 'ELF'; then\n    nm_args=(-D --defined-only)\n  fi\n  symbols=\"$(\"$nm_bin\" \"${nm_args[@]}\" \"$library\" 2>/dev/null | awk '{print $NF}' || true)\"\n  local required_symbols=(\n    tatachat_sdk_mls_identity_json\n    tatachat_sdk_mls_store_json\n    tatachat_sdk_mls_create_key_package_json\n    tatachat_sdk_mls_group_create_json\n    tatachat_sdk_mls_group_add_members_json\n    tatachat_sdk_mls_group_remove_members_json\n    tatachat_sdk_mls_group_create_message_json\n    tatachat_sdk_mls_group_process_json\n    tatachat_sdk_mls_group_state_json\n    tatachat_sdk_free_string\n  )\n  local symbol\n  for symbol in \"${required_symbols[@]}\"; do\n    if [[ \"$(grep -Ec \"^_?${symbol}$\" <<<\"$symbols\" || true)\" != 1 ]]; then\n      printf 'TataChatSDK required symbol %s must occur once in %s\\n' \\\n        \"$symbol\" \"$library\" >&2\n      exit 1\n    fi\n  done\n\n  # 中文注释：只导出现行OpenMLS边界；旧直聊、MLS包装和生产smoke接口禁止导出。\n  if grep -Eq '^_?tatachat_sdk_(device_identity|mls_encrypt|mls_decrypt|mls_rekey_state|mls_two_party_smoke)_json$' <<<\"$symbols\"; then\n    printf 'TataChatSDK legacy MLS/direct symbols found in %s\\n' \"$library\" >&2\n    exit 1\n  fi\n}\n\nbuild_host() {\n  cargo build --manifest-path \"$MANIFEST\" --locked\n  case \"$(uname -s)\" in\n    Darwin) library=\"$TARGET_DIR/debug/libtatachat_sdk.dylib\" ;;\n    Linux) library=\"$TARGET_DIR/debug/libtatachat_sdk.so\" ;;\n    *) printf 'Unsupported TataChatSDK host\\n' >&2; exit 1 ;;\n  esac\n  assert_symbols \"$library\"\n}\n\nbuild_android() {\n  ensure_target aarch64-linux-android\n\n  local ndk_home=\"${ANDROID_NDK_HOME:-}\"\n  if [[ -z \"$ndk_home\" ]]; then\n    local sdk_home=\"${ANDROID_HOME:-$HOME/Library/Android/sdk}\"\n    ndk_home=\"$(ls -d \"$sdk_home/ndk/\"* 2>/dev/null | sort -V | tail -1 || true)\"\n  fi\n  [[ -d \"$ndk_home\" ]] || { printf 'Android NDK not found\\n' >&2; exit 1; }\n\n  local toolchain\n  case \"$(uname -s)\" in\n    Darwin)\n      toolchain=\"$ndk_home/toolchains/llvm/prebuilt/darwin-x86_64\"\n      [[ -d \"$toolchain\" ]] ||\n        toolchain=\"$ndk_home/toolchains/llvm/prebuilt/darwin-aarch64\"\n      ;;\n    Linux) toolchain=\"$ndk_home/toolchains/llvm/prebuilt/linux-x86_64\" ;;\n    *) printf 'Unsupported Android build host\\n' >&2; exit 1 ;;\n  esac\n  [[ -d \"$toolchain\" ]] || {\n    printf 'Android NDK toolchain not found\\n' >&2\n    exit 1\n  }\n\n  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=\"$toolchain/bin/aarch64-linux-android24-clang\"\n  export CC_aarch64_linux_android=\"$toolchain/bin/aarch64-linux-android24-clang\"\n  export AR_aarch64_linux_android=\"$toolchain/bin/llvm-ar\"\n  cargo build --manifest-path \"$MANIFEST\" --release --target aarch64-linux-android --locked\n\n  local destination=\"$TATACHATSDK_NATIVE_ANDROID_DIR/arm64-v8a\"\n  mkdir -p \"$destination\"\n  cp \"$TARGET_DIR/aarch64-linux-android/release/libtatachat_sdk.so\" \"$destination/\"\n  assert_symbols \"$destination/libtatachat_sdk.so\" \"$toolchain/bin/llvm-nm\"\n}\n\nbuild_ios_slice() {\n  local target=\"$1\" sdk=\"$2\" flag_name=\"$3\"\n  local sdk_path host_sdk target_flags=\"${!flag_name:-}\"\n  sdk_path=\"$(xcrun --sdk \"$sdk\" --show-sdk-path)\"\n  host_sdk=\"$(xcrun --sdk macosx --show-sdk-path)\"\n  [[ -d \"$sdk_path\" && -d \"$host_sdk\" && \"$sdk_path\" != *[[:space:]]* ]] || {\n    printf 'TataChatSDK Apple SDK path is invalid\\n' >&2; exit 1;\n  }\n  # 宿主宏只链接macOS SDK；目标专属参数选择真机或Simulator SDK，保留未裁剪Mach-O。\n  target_flags=\"${target_flags:+$target_flags }-C strip=none -C link-arg=-isysroot -C link-arg=$sdk_path -C link-arg=-Wl,-install_name,@rpath/TataChatSDK.framework/TataChatSDK\"\n  env SDKROOT=\"$host_sdk\" \"$flag_name=$target_flags\" \\\n    cargo build --manifest-path \"$MANIFEST\" --release --target \"$target\" --locked\n  local library=\"$TARGET_DIR/$target/release/libtatachat_sdk.dylib\"\n  local framework_root=\"$TARGET_DIR/$target-framework\"\n  local framework=\"$framework_root/TataChatSDK.framework\"\n  local nm_bin\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  assert_symbols \"$library\" \"$nm_bin\"\n  local string_offset\n  string_offset=\"$(otool -l \"$library\" | awk '/cmd LC_SYMTAB/{active=1;next} active&&/cmd /{active=0} active&&/stroff/{print $2}')\"\n  [[ -n \"$string_offset\" && $((string_offset % 8)) -eq 0 ]] || {\n    printf 'TataChatSDK iOS LINKEDIT string pool is not 8-byte aligned\\n' >&2\n    exit 1\n  }\n\n  # 中文注释：TataChatSDK 以自己的动态 Framework 进入宿主，Smoldot 不再承载或\n  # 保活任何聊天符号。Framework 的 install name 固定为标准 @rpath，由 Xcode\n  # 嵌入并签名，Dart FFI 只解析这一份已经装载的动态库。\n  if [[ -e \"$framework_root\" ]]; then\n    find \"$framework_root\" -depth -delete\n  fi\n  mkdir -p \"$framework/Headers\" \"$framework/Modules\"\n  cp \"$library\" \"$framework/TataChatSDK\"\n  chmod 755 \"$framework/TataChatSDK\"\n  cp \"$ROOT/native/tatachat_sdk.h\" \"$framework/Headers/tatachat_sdk.h\"\n  cat > \"$framework/Modules/module.modulemap\" <<'MODULEMAP'\nframework module TataChatSDK {\n  umbrella header \"tatachat_sdk.h\"\n  export *\n}\nMODULEMAP\n  cat > \"$framework/Info.plist\" <<'PLIST'\n<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<plist version=\"1.0\">\n<dict>\n  <key>CFBundleDevelopmentRegion</key><string>en</string>\n  <key>CFBundleExecutable</key><string>TataChatSDK</string>\n  <key>CFBundleIdentifier</key><string>org.cocoapods.TataChatSDK</string>\n  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>\n  <key>CFBundleName</key><string>TataChatSDK</string>\n  <key>CFBundlePackageType</key><string>FMWK</string>\n  <key>CFBundleShortVersionString</key><string>1.0.0</string>\n  <key>CFBundleVersion</key><string>1</string>\n  <key>MinimumOSVersion</key><string>16.0</string>\n</dict>\n</plist>\nPLIST\n  assert_symbols \"$framework/TataChatSDK\" \"$nm_bin\"\n\n}\n\nbuild_ios() {\n  # 同一个iOS产物必须同时具备真机和Apple Silicon Simulator切片；缺目标先失败。\n  ensure_target aarch64-apple-ios\n  ensure_target aarch64-apple-ios-sim\n  export IPHONEOS_DEPLOYMENT_TARGET=16.0\n  build_ios_slice aarch64-apple-ios iphoneos CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS\n  build_ios_slice aarch64-apple-ios-sim iphonesimulator CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS\n  local xcframework=\"$TATACHATSDK_NATIVE_IOS_DIR/TataChatSDK.xcframework\"\n  mkdir -p \"$TATACHATSDK_NATIVE_IOS_DIR\"\n  if [[ -e \"$xcframework\" ]]; then\n    find \"$xcframework\" -depth -delete\n  fi\n  xcodebuild -create-xcframework \\\n    -framework \"$TARGET_DIR/aarch64-apple-ios-framework/TataChatSDK.framework\" \\\n    -framework \"$TARGET_DIR/aarch64-apple-ios-sim-framework/TataChatSDK.framework\" \\\n    -output \"$xcframework\"\n  local packaged variant nm_bin\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  for variant in ios-arm64 ios-arm64-simulator; do\n    packaged=\"$xcframework/$variant/TataChatSDK.framework/TataChatSDK\"\n    [[ -f \"$packaged\" && \"$(lipo -archs \"$packaged\")\" == arm64 ]] || {\n      printf 'TataChatSDK iOS slice missing or architecture invalid: %s\\n' \"$variant\" >&2; exit 1;\n    }\n    assert_symbols \"$packaged\" \"$nm_bin\"\n    otool -D \"$packaged\" | tail -n +2 | grep -qx '@rpath/TataChatSDK.framework/TataChatSDK' || {\n      printf 'TataChatSDK iOS framework install name is invalid\\n' >&2; exit 1;\n    }\n  done\n  # 回读Xcode实际平台元数据，不能用两个真机库冒充Simulator切片。\n  python3 - \"$xcframework/Info.plist\" <<'CHECK_IOS_SLICES'\nimport plistlib, sys\nwith open(sys.argv[1], 'rb') as file:\n    libraries = plistlib.load(file).get('AvailableLibraries', [])\nactual = {(item.get('LibraryIdentifier'), item.get('SupportedPlatform'),\n           item.get('SupportedPlatformVariant', ''), tuple(item.get('SupportedArchitectures', [])))\n          for item in libraries}\nexpected = {('ios-arm64', 'ios', '', ('arm64',)), ('ios-arm64-simulator', 'ios', 'simulator', ('arm64',))}\nif len(libraries) != 2 or actual != expected:\n    raise SystemExit('TataChatSDK XCFramework必须包含准确真机与Simulator ARM64切片')\nCHECK_IOS_SLICES\n}\n\nbuild_macos() {\n  ensure_target aarch64-apple-darwin\n  export MACOSX_DEPLOYMENT_TARGET=13.0\n\n  # 中文注释：目标专属参数不得污染宿主 proc-macro；host 模式仍只服务本机调试测试。\n  local macos_rustflags=\"${CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS:-}\"\n  macos_rustflags=\"${macos_rustflags:+$macos_rustflags }-C strip=none -C link-arg=-Wl,-install_name,@rpath/libtatachat_sdk.dylib\"\n  CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS=\"$macos_rustflags\" \\\n    cargo build --manifest-path \"$MANIFEST\" --release --target aarch64-apple-darwin --locked\n\n  local library=\"$TARGET_DIR/aarch64-apple-darwin/release/libtatachat_sdk.dylib\"\n  local destination=\"$TATACHATSDK_NATIVE_MACOS_DIR/libtatachat_sdk.dylib\"\n  local nm_bin\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  mkdir -p \"$TATACHATSDK_NATIVE_MACOS_DIR\"\n  cp \"$library\" \"$destination\"\n  [[ \"$(lipo -archs \"$destination\")\" == arm64 ]] || {\n    printf 'TataChatSDK macOS library must contain only arm64\\n' >&2\n    exit 1\n  }\n  file \"$destination\" | grep -q 'dynamically linked shared library' || {\n    printf 'TataChatSDK macOS artifact is not a dynamic library\\n' >&2\n    exit 1\n  }\n  assert_symbols \"$destination\" \"$nm_bin\"\n  otool -D \"$destination\" | tail -n +2 | grep -qx '@rpath/libtatachat_sdk.dylib' || {\n    printf 'TataChatSDK macOS install name is invalid\\n' >&2\n    exit 1\n  }\n}\n\nverify_android_package() {\n  local package=\"${1:?Android package is required}\"\n  local entry temporary packaged nm_bin\n  [[ -f \"$package\" ]] || { printf 'Android package not found: %s\\n' \"$package\" >&2; exit 1; }\n  case \"$package\" in\n    *.apk) entry='lib/arm64-v8a/libtatachat_sdk.so' ;;\n    *.aab) entry='base/lib/arm64-v8a/libtatachat_sdk.so' ;;\n    *) printf 'Unsupported Android package: %s\\n' \"$package\" >&2; exit 1 ;;\n  esac\n  temporary=\"$(mktemp -d)\"\n  packaged=\"$temporary/libtatachat_sdk.so\"\n  unzip -p \"$package\" \"$entry\" > \"$packaged\" || {\n    find \"$temporary\" -depth -delete\n    printf 'Android package missing TataChatSDK library\\n' >&2\n    exit 1\n  }\n  nm_bin=\"${ANDROID_NM:-}\"\n  if [[ -z \"$nm_bin\" ]]; then\n    local sdk_home=\"${ANDROID_HOME:-$HOME/Library/Android/sdk}\"\n    nm_bin=\"$(ls \"$sdk_home\"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-nm 2>/dev/null | tail -1 || true)\"\n  fi\n  [[ -n \"$nm_bin\" ]] || {\n    find \"$temporary\" -depth -delete\n    printf 'Android llvm-nm not found\\n' >&2\n    exit 1\n  }\n  assert_symbols \"$packaged\" \"$nm_bin\"\n  find \"$temporary\" -depth -delete\n  if unzip -Z1 \"$package\" | grep -E '(^|/)lib/(armeabi-v7a|x86|x86_64)/libtatachat_sdk\\.so$'; then\n    printf 'Android package contains unsupported TataChatSDK ABI\\n' >&2\n    exit 1\n  fi\n}\n\nverify_ios_package() {\n  local app_bundle=\"${1:?Runner.app is required}\"\n  local executable=\"$app_bundle/Runner\"\n  local framework=\"$app_bundle/Frameworks/TataChatSDK.framework/TataChatSDK\"\n  local nm_bin\n  [[ -f \"$executable\" ]] || { printf 'iOS Runner not found\\n' >&2; exit 1; }\n  [[ -f \"$framework\" ]] || { printf 'iOS package missing TataChatSDK.framework\\n' >&2; exit 1; }\n  [[ \"$(lipo -archs \"$framework\")\" == arm64 ]] || {\n    printf 'Packaged TataChatSDK framework must contain only arm64\\n' >&2\n    exit 1\n  }\n  file \"$framework\" | grep -q 'dynamically linked shared library' || {\n    printf 'Packaged TataChatSDK binary is not a dynamic framework\\n' >&2\n    exit 1\n  }\n  otool -L \"$executable\" | grep -q '@rpath/TataChatSDK.framework/TataChatSDK' || {\n    printf 'iOS Runner does not link the independent TataChatSDK framework\\n' >&2\n    exit 1\n  }\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  assert_symbols \"$framework\" \"$nm_bin\"\n}\n\ncase \"$MODE\" in\n  host) build_host ;;\n  macos) build_macos ;;\n  android) build_android ;;\n  ios) build_ios ;;\n  verify-android-package) verify_android_package \"${2:-}\" ;;\n  verify-ios-package) verify_ios_package \"${2:-}\" ;;\n  *) printf 'Usage: %s [host|macos|android|ios|verify-android-package|verify-ios-package]\\n' \"$0\" >&2; exit 64 ;;\nesac\n";
const AUTOMATION_ANALYSIS_OPTIONS = "include: package:flutter_lints/flutter.yaml\n\nanalyzer:\n  exclude:\n    # Isar 官方生成器会调用其自身标记为 experimental 的索引扩展；生成文件不手改。\n    - lib/storage/chat_isar.g.dart\n  language:\n    strict-casts: true\n    strict-inference: true\n    strict-raw-types: true\n\nlinter:\n  rules:\n    - avoid_print\n    - directives_ordering\n    - unawaited_futures\n    - use_super_parameters\n";
const automationPackage=await (async()=>{
const {constants:fsConstants}=await import('node:fs');
const {access,chmod,copyFile,lstat,mkdir,mkdtemp,readFile,readdir,realpath,rm,writeFile}=await import('node:fs/promises');
const {gzipSync,gunzipSync}=await import('node:zlib');
const {createHash}=await import('node:crypto');
const {basename,dirname,isAbsolute,join,posix,relative,resolve,sep}=await import('node:path');
const PRODUCT_ID = 'tatachatsdk';
const PACKAGE_NAME = 'tatachat_sdk';
const ARCHIVE_NAME = 'tatachatsdk.tgz';
const MANIFEST_NAME = 'release-manifest.json';
const CHECKSUMS_NAME = 'SHA256SUMS';
const RELEASE_ASSETS = [ARCHIVE_NAME];
// 自动化工程视图的分析规则由本流程独立维护，不执行编译入口。
const SOURCE_ENTRIES = [
  'LICENSE',
  'pubspec.yaml',
  'pubspec.lock',
  'ios',
  'lib',
  'native',
  'stickers',
];
const GENERATED_COMPONENTS = new Set([
  '.dart_tool',
  '.git',
  '.idea',
  '.DS_Store',
  'build',
  'target',
]);
const PLATFORM_ARTIFACTS = [
  {
    platform: 'android',
    architecture: 'arm64-v8a',
    source: 'android/libtatachat_sdk.so',
    path: 'prebuilt/android-arm64/libtatachat_sdk.so',
  },
  {
    platform: 'ios',
    architecture: 'arm64',
    source: 'ios/TataChatSDK.xcframework',
    path: 'prebuilt/ios-arm64/TataChatSDK.xcframework',
    requiredFiles: [
      'Info.plist',
      'ios-arm64/TataChatSDK.framework/TataChatSDK',
      'ios-arm64/TataChatSDK.framework/Info.plist',
      'ios-arm64-simulator/TataChatSDK.framework/TataChatSDK',
      'ios-arm64-simulator/TataChatSDK.framework/Info.plist',
    ],
  },
  {
    platform: 'macos',
    architecture: 'arm64',
    source: 'macos/libtatachat_sdk.dylib',
    path: 'prebuilt/macos/libtatachat_sdk.dylib',
  },
];

function fail(message) {
  throw new Error(message);
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function assertExactKeys(value, keys, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} 必须是对象`);
  }
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    fail(`${label} 字段不符合正式契约`);
  }
}

function normalizeRelativePath(value) {
  const normalized = value.split(sep).join('/');
  if (
    normalized.length === 0 ||
    normalized.startsWith('/') ||
    normalized.includes('\\') ||
    normalized.split('/').some((component) => component === '' || component === '.' || component === '..')
  ) {
    fail(`非法相对路径：${value}`);
  }
  return normalized;
}



async function copySourceTree(source, destination, relativePath) {
  const sourcePath = join(source, relativePath);
  const stat = await lstat(sourcePath).catch(() => null);
  if (!stat) fail(`TataChatSDK 发布源缺少：${relativePath}`);
  if (stat.isSymbolicLink()) fail(`TataChatSDK 发布源禁止符号链接：${relativePath}`);

  if (stat.isDirectory()) {
    await mkdir(join(destination, relativePath), { recursive: true });
    const entries = (await readdir(sourcePath, { withFileTypes: true }))
      .sort((left, right) => left.name.localeCompare(right.name));
    for (const entry of entries) {
      if (GENERATED_COMPONENTS.has(entry.name)) continue;
      await copySourceTree(source, destination, join(relativePath, entry.name));
    }
    return;
  }

  if (!stat.isFile()) fail(`TataChatSDK 发布源只允许普通文件：${relativePath}`);
  const target = join(destination, relativePath);
  await mkdir(dirname(target), { recursive: true });
  await copyFile(sourcePath, target);
  await chmod(target, stat.mode & 0o111 ? 0o755 : 0o644);
}

async function copyNativeArtifact(source, destination, label) {
  const stat = await lstat(source).catch(() => null);
  if (!stat || stat.isSymbolicLink()) fail(`${label} 缺失或是符号链接：${source}`);
  if (stat.isFile()) {
    if (stat.size === 0) fail(`${label} 为空：${source}`);
    await mkdir(dirname(destination), { recursive: true });
    await copyFile(source, destination);
    await chmod(destination, stat.mode & 0o111 ? 0o755 : 0o644);
    return 1;
  }
  if (!stat.isDirectory()) fail(`${label} 只允许普通文件或目录：${source}`);

  await mkdir(destination, { recursive: true });
  const entries = (await readdir(source, { withFileTypes: true }))
    .sort((left, right) => left.name.localeCompare(right.name));
  let files = 0;
  for (const entry of entries) {
    files += await copyNativeArtifact(
      join(source, entry.name),
      join(destination, entry.name),
      label,
    );
  }
  if (files === 0) fail(`${label} 目录为空：${source}`);
  return files;
}

async function listTree(root, current = '') {
  const absolute = current ? join(root, current) : root;
  const entries = (await readdir(absolute, { withFileTypes: true }))
    .sort((left, right) => left.name.localeCompare(right.name));
  const result = [];
  for (const entry of entries) {
    const child = current ? join(current, entry.name) : entry.name;
    const stat = await lstat(join(root, child));
    if (stat.isSymbolicLink()) fail(`正式包禁止符号链接：${child}`);
    if (stat.isDirectory()) {
      result.push({ path: normalizeRelativePath(child), directory: true, mode: 0o755 });
      result.push(...await listTree(root, child));
    } else if (stat.isFile()) {
      result.push({
        path: normalizeRelativePath(child),
        directory: false,
        mode: stat.mode & 0o111 ? 0o755 : 0o644,
        bytes: await readFile(join(root, child)),
      });
    } else {
      fail(`正式包只允许普通文件和目录：${child}`);
    }
  }
  return result;
}

function writeString(buffer, offset, length, value) {
  const encoded = Buffer.from(value, 'utf8');
  if (encoded.length > length) fail(`tar 字段过长：${value}`);
  encoded.copy(buffer, offset);
}

function writeOctal(buffer, offset, length, value) {
  const encoded = Math.trunc(value).toString(8).padStart(length - 1, '0');
  if (encoded.length > length - 1) fail('tar 数值字段溢出');
  writeString(buffer, offset, length, `${encoded}\0`);
}

function splitTarPath(path) {
  if (Buffer.byteLength(path) <= 100) return { name: path, prefix: '' };
  for (let index = path.length - 1; index > 0; index -= 1) {
    if (path[index] !== '/') continue;
    const prefix = path.slice(0, index);
    const name = path.slice(index + 1);
    if (Buffer.byteLength(name) <= 100 && Buffer.byteLength(prefix) <= 155) {
      return { name, prefix };
    }
  }
  fail(`tar 路径过长：${path}`);
}

function tarHeader(path, size, mode, directory) {
  const header = Buffer.alloc(512, 0);
  const parts = splitTarPath(path);
  writeString(header, 0, 100, parts.name);
  writeOctal(header, 100, 8, mode);
  writeOctal(header, 108, 8, 0);
  writeOctal(header, 116, 8, 0);
  writeOctal(header, 124, 12, size);
  writeOctal(header, 136, 12, 0);
  header.fill(0x20, 148, 156);
  header[156] = directory ? 0x35 : 0x30;
  writeString(header, 257, 6, 'ustar\0');
  writeString(header, 263, 2, '00');
  writeString(header, 345, 155, parts.prefix);
  const checksum = header.reduce((sum, byte) => sum + byte, 0);
  const encoded = checksum.toString(8).padStart(6, '0');
  writeString(header, 148, 8, `${encoded}\0 `);
  return header;
}

async function createArchive(packageRoot) {
  // 中文注释：目录按路径排序、权限归一且时间戳固定为零，确保同一输入只生成同一份正式归档。
  const tree = await listTree(packageRoot);
  const chunks = [tarHeader('tatachatsdk/', 0, 0o755, true)];
  for (const entry of tree) {
    const archivePath = `tatachatsdk/${entry.path}${entry.directory ? '/' : ''}`;
    chunks.push(tarHeader(archivePath, entry.directory ? 0 : entry.bytes.length, entry.mode, entry.directory));
    if (!entry.directory) {
      chunks.push(entry.bytes);
      const padding = (512 - (entry.bytes.length % 512)) % 512;
      if (padding > 0) chunks.push(Buffer.alloc(padding, 0));
    }
  }
  chunks.push(Buffer.alloc(1024, 0));
  return gzipSync(Buffer.concat(chunks), { level: 9, mtime: 0 });
}

function parseOctal(buffer, offset, length, label) {
  const text = buffer.subarray(offset, offset + length).toString('ascii').replace(/\0.*$/s, '').trim();
  if (!/^[0-7]*$/.test(text)) fail(`tar ${label} 不是八进制数`);
  return text ? Number.parseInt(text, 8) : 0;
}

function readTarString(buffer, offset, length) {
  return buffer.subarray(offset, offset + length).toString('utf8').replace(/\0.*$/s, '');
}

function validateArchivePath(path, directory) {
  if (!path.startsWith('tatachatsdk/')) fail(`tar 路径不属于 TataChatSDK：${path}`);
  const logical = directory && path.endsWith('/') ? path.slice(0, -1) : path;
  normalizeRelativePath(logical);
  return logical;
}

function parseTar(archiveBytes) {
  const tar = gunzipSync(archiveBytes);
  const entries = new Map();
  let offset = 0;
  while (offset + 512 <= tar.length) {
    const header = tar.subarray(offset, offset + 512);
    if (header.every((byte) => byte === 0)) break;
    const expectedChecksum = parseOctal(header, 148, 8, '校验和');
    const checksumHeader = Buffer.from(header);
    checksumHeader.fill(0x20, 148, 156);
    const actualChecksum = checksumHeader.reduce((sum, byte) => sum + byte, 0);
    if (expectedChecksum !== actualChecksum) fail('tar 头校验和错误');

    const name = readTarString(header, 0, 100);
    const prefix = readTarString(header, 345, 155);
    const path = prefix ? `${prefix}/${name}` : name;
    const type = String.fromCharCode(header[156] || 0x30);
    if (type !== '0' && type !== '5') fail(`tar 禁止的条目类型：${type}`);
    const directory = type === '5';
    const logicalPath = validateArchivePath(path, directory);
    const size = parseOctal(header, 124, 12, '文件大小');
    if (directory && size !== 0) fail(`tar 目录包含数据：${logicalPath}`);
    const dataStart = offset + 512;
    const dataEnd = dataStart + size;
    if (dataEnd > tar.length) fail(`tar 条目被截断：${logicalPath}`);
    if (entries.has(logicalPath)) fail(`tar 条目重复：${logicalPath}`);
    entries.set(logicalPath, {
      directory,
      bytes: directory ? null : Buffer.from(tar.subarray(dataStart, dataEnd)),
    });
    offset = dataStart + Math.ceil(size / 512) * 512;
  }
  return entries;
}

function expectedPlatforms() {
  return PLATFORM_ARTIFACTS.map(({ platform, architecture, path }) => ({
    architecture,
    artifact: path,
    platform,
  }));
}

function validatePlatformArtifacts(archiveEntries) {
  for (const artifact of PLATFORM_ARTIFACTS) {
    const root = `tatachatsdk/${artifact.path}`;
    if (artifact.requiredFiles) {
      for (const relativePath of artifact.requiredFiles) {
        const entry = archiveEntries.get(`${root}/${relativePath}`);
        if (!entry || entry.directory) fail(`TataChatSDK ${artifact.platform} 原生资产结构不完整`);
      }
    } else {
      const entry = archiveEntries.get(root);
      if (!entry || entry.directory) fail(`TataChatSDK ${artifact.platform} 原生资产缺失`);
    }
  }
}

function validateManifest(manifest, expectedGitSha, expectedSoftwareVersion, archiveEntries) {
  assertExactKeys(
    manifest,
    ['files', 'git_commit_sha', 'package_name', 'platforms', 'product_id', 'software_version'],
    'TataChatSDK Release manifest',
  );
  if (manifest.product_id !== PRODUCT_ID) fail('TataChatSDK Release product_id 错误');
  if (manifest.package_name !== PACKAGE_NAME) fail('TataChatSDK Release package_name 错误');
  if (!/^[0-9a-f]{40}$/.test(manifest.git_commit_sha)) fail('TataChatSDK Release git_commit_sha 非法');
  if (expectedGitSha && manifest.git_commit_sha !== expectedGitSha) fail('TataChatSDK Release 源提交不一致');
  if (typeof manifest.software_version !== 'string' || manifest.software_version.length === 0) {
    fail('TataChatSDK Release software_version 非法');
  }
  if (expectedSoftwareVersion && manifest.software_version !== expectedSoftwareVersion) {
    fail('TataChatSDK Release 软件版本不一致');
  }
  if (JSON.stringify(manifest.platforms) !== JSON.stringify(expectedPlatforms())) {
    fail('TataChatSDK Release 平台闭包错误');
  }
  validatePlatformArtifacts(archiveEntries);
  if (!Array.isArray(manifest.files)) fail('TataChatSDK Release files 必须是数组');

  const archiveFiles = [...archiveEntries.entries()]
    .filter(([path, entry]) => !entry.directory
      && ![`tatachatsdk/${MANIFEST_NAME}`, `tatachatsdk/${CHECKSUMS_NAME}`].includes(path))
    .map(([path, entry]) => ({ path: path.slice('tatachatsdk/'.length), bytes: entry.bytes }))
    .sort((left, right) => left.path.localeCompare(right.path));
  const expectedFileRecords = archiveFiles.map(({ path, bytes }) => ({
    path,
    sha256: sha256(bytes),
    size: bytes.length,
  }));
  for (const record of manifest.files) {
    assertExactKeys(record, ['path', 'sha256', 'size'], `TataChatSDK Release 文件记录 ${record?.path ?? ''}`);
  }
  if (JSON.stringify(manifest.files) !== JSON.stringify(expectedFileRecords)) {
    fail('TataChatSDK Release 文件清单与归档内容不一致');
  }
}

function verifyInternalChecksums(archiveEntries, bytes) {
  const lines = bytes.toString('utf8').trimEnd().split('\n');
  const result = new Map();
  for (const line of lines) {
    const match = line.match(/^([0-9a-f]{64})  ([A-Za-z0-9._/-]+)$/);
    if (!match || result.has(match[2])) fail('SHA256SUMS 格式或资产名称错误');
    result.set(match[2], match[1]);
  }
  const expected = [...archiveEntries.entries()]
    .filter(([path, entry]) => !entry.directory && path !== `tatachatsdk/${CHECKSUMS_NAME}`)
    .map(([path, entry]) => [path.slice('tatachatsdk/'.length), sha256(entry.bytes)])
    .sort(([left], [right]) => left.localeCompare(right));
  if (JSON.stringify([...result.entries()].sort(([left], [right]) => left.localeCompare(right)))
      !== JSON.stringify(expected)) fail('SHA256SUMS 与单包内部文件闭集不一致');
}

async function verifyReleaseAssets(directory, options = {}) {
  const names = (await readdir(directory)).sort();
  if (JSON.stringify(names) !== JSON.stringify([...RELEASE_ASSETS].sort())) {
    fail('TataChatSDK 正式 Release 必须且只能包含一个包');
  }
  const archiveBytes = await readFile(join(directory, ARCHIVE_NAME));
  const entries = parseTar(archiveBytes);
  const internalManifest = entries.get(`tatachatsdk/${MANIFEST_NAME}`);
  if (!internalManifest || internalManifest.directory) fail('归档缺少 TataChatSDK Release manifest');
  const internalChecksums = entries.get(`tatachatsdk/${CHECKSUMS_NAME}`);
  if (!internalChecksums || internalChecksums.directory) fail('归档缺少 TataChatSDK SHA256SUMS');
  verifyInternalChecksums(entries, internalChecksums.bytes);
  const manifest = JSON.parse(internalManifest.bytes.toString('utf8'));
  validateManifest(manifest, options.expectedGitSha, options.softwareVersion, entries);
  return manifest;
}

async function buildRelease({ source, native, output, archive, gitSha, softwareVersion }) {
  if (!/^[0-9a-f]{40}$/.test(gitSha)) fail('构建 TataChatSDK Release 必须提供 40 位小写源提交 SHA');
  if (!softwareVersion || typeof softwareVersion !== 'string') fail('构建 TataChatSDK Release 必须提供软件版本');
  if (basename(archive) !== ARCHIVE_NAME) fail(`TataChatSDK Release 归档名必须是 ${ARCHIVE_NAME}`);
  for (const entry of SOURCE_ENTRIES) await access(join(source, entry), fsConstants.R_OK);
  const header=await lstat(join(source,'native/tatachat_sdk.h'));
  if(!header.isFile()||header.isSymbolicLink())fail('C头文件必须是native下唯一普通原件');
  for(const obsolete of ['scripts/tatachat_sdk.h','stickers/tatachat_sdk.h']){if(await lstat(join(source,obsolete)).then(()=>true,error=>{if(error.code==='ENOENT')return false;throw error;}))fail('C头文件存在旧路径副本：'+obsolete);}

  if (!isAbsolute(output) || resolve(output) !== output || dirname(output) === output) {
    fail('正式包输出目录必须为规范绝对路径');
  }
  const parent = dirname(output);
  const parentInfo = await lstat(parent);
  if (!parentInfo.isDirectory() || parentInfo.isSymbolicLink() || await realpath(parent) !== parent) {
    fail('正式包输出父目录必须为真实普通目录');
  }
  const existingOutput = await lstat(output).catch(error => {
    if (error.code === 'ENOENT') return null;
    throw error;
  });
  if (existingOutput && (!existingOutput.isDirectory() || existingOutput.isSymbolicLink()
      || await realpath(output) !== output)) fail('正式包输出目录无效');
  // 发布临时包只属于本次输出目录的相邻现场，完成后按本轮准确路径清理。
  const temporary = await mkdtemp(join(parent, '.tatachatsdk-release-'));
  const packageRoot = join(temporary, 'tatachatsdk');
  try {
    await mkdir(packageRoot, { recursive: true });
    for (const entry of SOURCE_ENTRIES) await copySourceTree(source, packageRoot, entry);
    // 包介绍只属于输出载荷；产品技术文档不复制进公开源码仓。
    await writeFile(join(packageRoot, 'README.md'),
      `# TataChatSDK\n\nIndependent end-to-end encrypted chat SDK.\n\n`
      + `Package: ${PACKAGE_NAME}\nVersion: ${softwareVersion}\nSource commit: ${gitSha}\n\n`
      + 'Source: https://github.com/tuyutata/tatachatsdk\n', 'utf8');
    for (const artifact of PLATFORM_ARTIFACTS) {
      const input = join(native, artifact.source);
      const destination = join(packageRoot, artifact.path);
      await copyNativeArtifact(input, destination, `TataChatSDK ${artifact.platform} 原生资产`);
    }

    // 中文注释：manifest 只登记业务载荷；内部校验清单再覆盖载荷和 manifest，避免任何自引用字段。
    const files = (await listTree(packageRoot))
      .filter((entry) => !entry.directory)
      .map((entry) => ({ path: entry.path, sha256: sha256(entry.bytes), size: entry.bytes.length }))
      .sort((left, right) => left.path.localeCompare(right.path));
    const manifest = {
      files,
      git_commit_sha: gitSha,
      package_name: PACKAGE_NAME,
      platforms: expectedPlatforms(),
      product_id: PRODUCT_ID,
      software_version: softwareVersion,
    };
    const manifestBytes = Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
    await writeFile(join(packageRoot, MANIFEST_NAME), manifestBytes);
    const checksumRows = [
      ...files.map(({ path, sha256: digest }) => [path, digest]),
      [MANIFEST_NAME, sha256(manifestBytes)],
    ].sort(([left], [right]) => left.localeCompare(right));
    await writeFile(
      join(packageRoot, CHECKSUMS_NAME),
      Buffer.from(`${checksumRows.map(([path, digest]) => `${digest}  ${path}`).join('\n')}\n`, 'utf8'),
    );
    const archiveBytes = await createArchive(packageRoot);

    await rm(output, { recursive: true, force: true });
    await mkdir(output, { recursive: true });
    const finalArchive = join(output, ARCHIVE_NAME);
    await writeFile(finalArchive, archiveBytes);
    if (resolve(archive) !== resolve(finalArchive)) {
      await mkdir(dirname(archive), { recursive: true });
      await copyFile(finalArchive, archive);
    }
    await verifyReleaseAssets(output, { expectedGitSha: gitSha, softwareVersion });
    return manifest;
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}


return {buildRelease,verifyReleaseAssets};
})();

// 自动化独立确认自身GitHub Tag；不调用本机发布流程。
async function inspectProductRelease(release,platform,readTag){
  if(platform!=='sdk')fail('本目标平台无效');
  const name=release?.tag_name;
  if(typeof name!=='string'||!name.startsWith(prefix))return null;
  const fields=/^tatachatsdk-sdk-v([0-9]+\.[0-9]+\.[0-9]+)-r([1-9][0-9]*)-a([1-9][0-9]*)$/u.exec(name);
  if(!fields)fail('本目标Tag身份无效');
  const [run_id,run_attempt]=fields.slice(2).map(Number);
  if(![run_id,run_attempt].every(Number.isSafeInteger))fail('本目标运行坐标越界');
  const ref=await readTag(name);
  if(ref?.ref!==`refs/tags/${name}`||ref.object?.type!=='commit'||!shaPattern.test(ref.object.sha||''))fail('本目标Tag提交无效');
  return {platform:'sdk',run_id,run_attempt,version:fields[1],source_sha:ref.object.sha,tag:name};
}

function automationNative(mode, source=process.cwd()) {
  runVersion();
  if(!['host','android','ios','macos'].includes(mode)||!isAbsolute(source)||resolve(source)!==source
    ||realpathSync(source)!==source||!lstatSync(source).isDirectory())fail('自动化原生编译输入无效');
  const expected=join(process.env.RUNNER_TEMP||'',owner.product,'build-source');
  if(source!==expected)fail('自动化原生编译只接受本次源码副本');
  const work=process.env.PRODUCT_WORK_DIR||join(process.env.RUNNER_TEMP,owner.product,'native-work');
  if(!isAbsolute(work)||resolve(work)!==work||!work.startsWith(process.env.RUNNER_TEMP+sep))fail('自动化原生现场无效');
  mkdirSync(work,{recursive:true});
  const env={...process.env,PRODUCT_WORK_DIR:work,TATACHATSDK_SOURCE_ROOT:source,
    TATACHATSDK_WORK_DIR:process.env.TATACHATSDK_WORK_DIR||join(work,'native'),
    TATACHATSDK_NATIVE_OUTPUT_DIR:process.env.TATACHATSDK_NATIVE_OUTPUT_DIR||join(work,'output')};
  const result=spawnSync('bash',['--noprofile','--norc','-c',AUTOMATION_NATIVE_SHELL,'tatachatsdk-automation-native',mode],
    {cwd:source,env,stdio:'inherit',timeout:3_600_000});
  if(result.error||result.status!==0||result.signal)fail('自动化原生编译失败：'+mode);
}

function automationNativeFinish(scope) {
  runVersion();
  if(scope!=='test')fail('自动化原生收尾职责无效');
  const source=join(process.env.RUNNER_TEMP||'',owner.product,'build-source');
  if(resolve(root)!==source||!isAbsolute(source)||realpathSync(source)!==source)fail('自动化收尾源码身份无效');
  const work=join(source,'target/test');
  if(existsSync(work))rmSync(work,{recursive:true,force:true});
}

function automationIsar(configPath,pubCache,lockPath){
  runVersion();
  const ordinary=(path,directory=false)=>{
    if(!isAbsolute(path)||resolve(path)!==path)fail('自动化Isar路径无效');
    const stat=lstatSync(path);if(!(directory?stat.isDirectory():stat.isFile())||stat.isSymbolicLink()
      ||realpathSync(path)!==path)fail('自动化Isar输入不是普通文件或目录');return path;
  };
  ordinary(configPath);ordinary(pubCache,true);ordinary(lockPath);
  const lock=readFileSync(lockPath,'utf8');
  const blocks=[...lock.matchAll(/^  isar_community_flutter_libs:\n(?:[ \t]{4,}[^\n]*\n)+/gmu)];
  if(blocks.length!==1||!/^    source: hosted$/mu.test(blocks[0][0]))fail('自动化Isar锁定包无效');
  const versions=[...blocks[0][0].matchAll(/^    version: "([0-9]+\.[0-9]+\.[0-9]+)"$/gmu)];
  if(versions.length!==1)fail('自动化Isar版本不唯一');
  const config=JSON.parse(readFileSync(configPath,'utf8'));
  const packages=Array.isArray(config.packages)?config.packages.filter(item=>item.name==='isar_community_flutter_libs'):[];
  if(config.configVersion!==2||packages.length!==1||typeof packages[0].rootUri!=='string')fail('自动化Isar包坐标无效');
  const url=new URL(packages[0].rootUri,pathToFileURL(configPath));
  if(url.protocol!=='file:'||url.search||url.hash)fail('自动化Isar来源无效');
  const packageRoot=ordinary(fileURLToPath(url).replace(/[\/]$/u,''),true),part=relative(pubCache,packageRoot);
  if(!part||part==='..'||part.startsWith('..'+sep)||isAbsolute(part)
    ||packageRoot!==join(pubCache,'hosted','pub.dev','isar_community_flutter_libs-'+versions[0][1]))fail('自动化Isar缓存坐标不符');
  const manifest=readFileSync(ordinary(join(packageRoot,'pubspec.yaml')),'utf8');
  if(!/^name: isar_community_flutter_libs$/mu.test(manifest)
    ||!new RegExp('^version: '+versions[0][1].replaceAll('.','\\.')+'$','mu').test(manifest))fail('自动化Isar包身份无效');
  const library=process.platform==='darwin'?'macos/libisar.dylib':process.platform==='linux'?'linux/libisar.so':null;
  if(!library)fail('自动化Isar宿主不受支持');
  process.stdout.write(ordinary(join(packageRoot,library))+'\n');
}

function automationAnalysisOptions(source,output){
  runVersion();
  if(resolve(source)!==resolve(root)||!isAbsolute(output)||resolve(output)!==output||!output.startsWith(process.env.RUNNER_TEMP+sep)
    ||!lstatSync(output).isDirectory()||lstatSync(output).isSymbolicLink())fail('自动化分析配置工程无效');
  writeFileSync(join(output,'analysis_options.yaml'),AUTOMATION_ANALYSIS_OPTIONS,{flag:'wx',mode:0o600});
}

function commandOptions(args){
  const values=new Map();for(let i=0;i<args.length;i+=2){
    if(!args[i]?.startsWith('--')||!args[i+1]||values.has(args[i].slice(2)))fail('自动化包参数无效');
    values.set(args[i].slice(2),args[i+1]);
  }
  return values;
}

async function automationPackageCommand(args){
  const identity=runVersion(),values=commandOptions(args);
  for(const name of ['source','native','output','archive','git-sha','software-version'])if(!values.has(name))fail('自动化完整包输入缺失：'+name);
  if(values.get('git-sha')!==identity.source_sha||values.get('software-version')!==identity.version)fail('自动化完整包身份无效');
  await automationPackage.buildRelease({source:resolve(values.get('source')),native:values.get('native'),
    output:values.get('output'),archive:values.get('archive'),gitSha:identity.source_sha,softwareVersion:identity.version});
}

async function automationVerifyAssets(args){
  const identity=runVersion(),directory=args[0],values=commandOptions(args.slice(1));
  if(values.get('expected-git-sha')!==identity.source_sha||values.get('software-version')!==identity.version)fail('自动化验真身份无效');
  await automationPackage.verifyReleaseAssets(directory,{expectedGitSha:identity.source_sha,softwareVersion:identity.version});
}

export function context(environment = process.env) {
  const number = name => {
    const value = environment[name];
    if (!/^[1-9][0-9]*$/u.test(value || '') || !Number.isSafeInteger(Number(value))) fail('GitHub运行坐标无效');
    return Number(value);
  };
  if (environment.GITHUB_ACTIONS !== 'true' || environment.GITHUB_REPOSITORY !== owner.repository
    || environment.GITHUB_REF !== 'refs/heads/main' || environment.GITHUB_EVENT_NAME !== 'workflow_dispatch'
    || !shaPattern.test(environment.GITHUB_SHA || '')
    || environment.GITHUB_WORKFLOW_REF !== `${owner.repository}/${workflowPath}@refs/heads/main`) fail('所属GitHub运行身份无效');
  return { repository: owner.repository, product_id: owner.product, platform: owner.platform,
    source_sha: environment.GITHUB_SHA, run_id: number('GITHUB_RUN_ID'),
    run_number: number('GITHUB_RUN_NUMBER'), run_attempt: number('GITHUB_RUN_ATTEMPT'), workflow: workflowPath };
}

export async function request(path, { method = 'GET', body, raw = false, size, fetch: send = globalThis.fetch } = {}) {
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (!token || /[\s\u0000-\u001f\u007f]/u.test(token)) fail('缺少GitHub任务令牌');
  const url = path.startsWith('https://') ? new URL(path) : new URL(`https://api.github.com/repos/${owner.repository}/${path}`);
  if (!['api.github.com', 'uploads.github.com'].includes(url.hostname) || url.protocol !== 'https:' || url.username || url.password || !url.pathname.startsWith(`/repos/${owner.repository}/`)) fail('GitHub接口地址无效');
  const headers = { Authorization: `Bearer ${token}`, Accept: raw ? 'application/octet-stream' : 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2026-03-10', 'User-Agent': owner.product };
  if (body !== undefined) headers['Content-Type'] = body?.pipe ? 'application/octet-stream' : 'application/json';
  if(body?.pipe){if(!Number.isSafeInteger(size)||size<=0)fail('资产上传长度无效');headers['Content-Length']=String(size);}
  let response = await send(url, { method, headers, redirect: raw ? 'manual' : 'error', signal: AbortSignal.timeout(300_000),
    ...(body === undefined ? {} : { body: body?.pipe ? body : JSON.stringify(body), ...(body?.pipe ? { duplex: 'half' } : {}) }) });
  if(raw&&response.status===302){
    const location=new URL(response.headers.get('location'));
    if(location.protocol!=='https:'||location.username||location.password)fail('正式资产回读地址无效');
    response=await send(location,{method:'GET',redirect:'error',credentials:'omit',signal:AbortSignal.timeout(300_000)});
  }
  if (response.status === 404) return null;
  if (!response.ok) fail(`GitHub接口失败：${response.status}，操作未确认`);
  if (raw) return response;
  return response.status === 204 ? {} : response.json();
}

export async function pages(path, field = null, api = request) {
  const rows = [];
  for (let page = 1; ; page++) {
    const data = await api(`${path}${path.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
    const values = field ? data?.[field] : data;
    if (!Array.isArray(values)) fail('GitHub分页数据无效');
    rows.push(...values);
    if (values.length < 100) return rows;
  }
}

function seedVersion() {
  const text = readFileSync(join(root, owner.version_source.path), 'utf8');
  const value = /^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$/mu.exec(text)?.[1];
  if (!value) fail('本仓软件版本真源无效');
  return value;
}

export function nextVersion(seed, versions, runNumber = 1) {
  const parse = value => {
    const match = /^(0|[1-9]\d*)\.(0|[1-9]\d?)\.(0|[1-9]\d?)$/u.exec(value);
    if (!match) fail('软件版本无效');
    const parts=match.slice(1).map(Number);if(parts.some(value=>!Number.isSafeInteger(value)))fail('软件版本越界');return parts;
  };
  const values = [seed, ...versions].map(parse).sort((a,b) => a[0]-b[0] || a[1]-b[1] || a[2]-b[2]);
  let [major, minor, patch] = values.at(-1);
  if (versions.length) { if (++patch > 99) { patch = 0; if (++minor > 99) { minor = 0; major++; } } }
  if(!Number.isSafeInteger(runNumber)||runNumber<1)fail('版本运行序号无效');
  const initial=parse(seed),floor=BigInt(initial[0])*10000n+BigInt(initial[1])*100n+BigInt(initial[2])+BigInt(runNumber-1);
  const historical=BigInt(major)*10000n+BigInt(minor)*100n+BigInt(patch);
  if(floor>historical){major=Number(floor/10000n);minor=Number(floor/100n%100n);patch=Number(floor%100n);}
  if(![major,minor,patch].every(Number.isSafeInteger))fail('软件版本越界');
  return `${major}.${minor}.${patch}`;
}

function output(name, value, file = process.env.GITHUB_OUTPUT) {
  if (!file || /[\r\n]/u.test(String(value))) fail('GitHub步骤输出无效');
  appendFileSync(file, `${name}=${value}\n`);
}

export async function prepare() {
  const identity = context();
  const releases = await pages('releases');
  const versions = [];
  for (const release of releases) {
    if (release.draft || release.prerelease || !String(release.tag_name).startsWith(prefix)) continue;
    const notes = (await inspectProductRelease(release,owner.platform,tag=>request('git/ref/tags/'+encodeURIComponent(tag))));
    if (!notes || notes.platform !== owner.platform) continue;
    const run = await request(`actions/runs/${notes.run_id}`);
    if (run?.status === 'completed' && run.conclusion === 'success' && run.path === workflowPath) versions.push(notes.version);
  }
  const version = nextVersion(seedVersion(), versions, identity.run_number);
  const tag = `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`;
  for (const [name,value] of Object.entries({version, tag, source_sha:identity.source_sha,
    run_id:identity.run_id, run_attempt:identity.run_attempt, run_number:identity.run_number})) output(name,value);
}

function runVersion() {
  const identity = context();
  const version = process.env.RELEASE_VERSION;
  const tag = process.env.RELEASE_TAG;
  nextVersion(version, []);
  if (tag !== `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`) fail('本次版本与Tag不一致');
  return {...identity, version, tag};
}

export function job() {
  const identity = runVersion();
  if (execFileSync('git', ['rev-parse','HEAD'], {cwd:root,encoding:'utf8'}).trim() !== identity.source_sha) fail('检出源码不符');
  const packageSource=join(root,'pubspec.yaml');
  const packageText=readFileSync(packageSource,'utf8');
  if(!/^version:\s*\d+\.\d+\.\d+(?:\+\d+)?\s*$/mu.test(packageText))fail('SDK版本真源无效');
  writeFileSync(packageSource,packageText.replace(/^version:.*$/mu,'version: '+identity.version));
  const work = join(process.env.RUNNER_TEMP, owner.product, owner.platform, String(identity.run_id), String(identity.run_attempt), process.env.GITHUB_JOB);
  mkdirSync(work,{recursive:true});
  const variables = {RELEASE_WORK:work, RELEASE_ASSETS_DIR:join(work,'assets'), SOURCE_SHA:identity.source_sha,
    SOFTWARE_VERSION:identity.version, VERSION_TAG:identity.tag, BUILD_NUMBER:String(identity.run_number),
    CARGO_HOME:join(work,'cargo-home'), CARGO_TARGET_DIR:join(work,'cargo'), PUB_CACHE:join(work,'pub'),
    GRADLE_USER_HOME:join(work,'gradle'), npm_config_cache:join(work,'npm'), XDG_CACHE_HOME:join(work,'cache'),
    TMPDIR:join(work,'tmp'), TMP:join(work,'tmp'), TEMP:join(work,'tmp')};
  for (const path of ['cargo-home','cargo','pub','gradle','npm','cache','tmp','assets']) mkdirSync(join(work,path),{recursive:true});
  const packageTemporary=join(root,'target/build/github-package');mkdirSync(packageTemporary,{recursive:true});
  Object.assign(variables,{TMPDIR:packageTemporary,TMP:packageTemporary,TEMP:packageTemporary});
  for (const [name,value] of Object.entries(variables)) { process.env[name]=value; output(name,value,process.env.GITHUB_ENV); }
}

export function step(key) {
  runVersion();
  const value = commands[key];
  if (!value || !['bash','pwsh'].includes(value.shell)) fail('本目标构建步骤无效');
  const directory = join(process.env.RELEASE_WORK,'commands');mkdirSync(directory,{recursive:true});
  const file = join(directory, value.shell === 'pwsh' ? 'step.ps1' : 'step.sh');
  writeFileSync(file, value.shell === 'bash' ? 'set -euo pipefail\n'+value.source : "$ErrorActionPreference = 'Stop'\n"+value.source,{mode:0o700});
  const result = spawnSync(value.shell === 'pwsh' ? 'pwsh' : 'bash', value.shell === 'pwsh' ? ['-NoProfile','-File',file] : [file],
    {cwd:process.cwd(),env:process.env,stdio:'inherit'});
  rmSync(file,{force:true});
  if (result.error || result.status !== 0) fail(`本仓构建步骤失败：${key}`);
}

function regular(path) {
  const stat=lstatSync(path);if(!stat.isFile()||stat.isSymbolicLink()||stat.size<=0)fail('正式产物不是非空普通文件');return stat;
}
async function digestFile(path) { const hash=createHash('sha256');for await(const bytes of createReadStream(path))hash.update(bytes);return hash.digest('hex'); }
function assetName(name) { if(!name||name!==basename(name)||/[\u0000-\u001f\u007f]/u.test(name))fail('正式资产文件名无效');return name; }

export async function collect(paths) {
  const identity=runVersion(),destination=process.env.RELEASE_ASSETS_DIR;
  if(!destination||!paths.length)fail('本仓没有完整产物');mkdirSync(destination,{recursive:true});
  const files=[];
  for(const path of paths){const file=resolve(path),stat=regular(file),name=assetName(basename(file));
    if(files.some(row=>row.name===name))fail('正式资产重名');
    const target=join(destination,name);if(file!==target)copyFileSync(file,target);
    files.push({name,size:stat.size,sha256:await digestFile(target)});
  }
  if(owner.required_assets.some(name=>!files.some(row=>row.name===name)))fail('本目标必要产物缺失');
  const metadata={schema:1,...identity,assets:files};
  writeFileSync(join(destination,'automation.json'),JSON.stringify(metadata,null,2)+'\n');
  output('assets',destination);return metadata;
}

export async function collectProduced() {
  const paths=[],seen=new Set();
  const expand=value=>value.replace(/\$\{([A-Z_]+)\}|\$([A-Z_]+)/gu,(_,a,b)=>process.env[a||b]||'');
  for(const location of owner.asset_locations){
    const path=expand(location);if(!path||!existsSync(path))continue;
    const candidates=lstatSync(path).isDirectory()?readdirSync(path).map(name=>join(path,name)):[path];
    for(const candidate of candidates){if(!lstatSync(candidate).isFile()||seen.has(resolve(candidate)))continue;
      const name=basename(candidate);if(!owner.asset_patterns.some(pattern=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(name)))continue;
      seen.add(resolve(candidate));paths.push(candidate);
    }
  }
  if(owner.required_patterns.some(pattern=>!paths.some(path=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(basename(path)))))fail('本目标完整正式资产缺失');
  return collect(paths);
}



export async function publish(directory) {
  const identity=runVersion();const metadata=JSON.parse(readFileSync(join(directory,'automation.json'),'utf8'));
  if(Object.entries(identity).some(([key,value])=>metadata[key]!==value)||!Array.isArray(metadata.assets)||!metadata.assets.length)fail('完整产物身份无效');
  const files=metadata.assets;
  if(readdirSync(directory).sort().join('\0')!==[...files.map(value=>value.name),'automation.json'].sort().join('\0'))fail('产物目录与完整资产集合不符');
  for(const file of files){const path=join(directory,assetName(file.name));if(regular(path).size!==file.size||await digestFile(path)!==file.sha256)fail('正式产物在交付前改变');}
  if(await request(`git/ref/tags/${encodeURIComponent(identity.tag)}`)!==null)fail('本次Tag已经存在');
  await request('git/refs',{method:'POST',body:{ref:`refs/tags/${identity.tag}`,sha:identity.source_sha}});
  const release=await request('releases',{method:'POST',body:{tag_name:identity.tag,target_commitish:identity.source_sha,
    name:`${owner.product} · ${owner.platform} · ${identity.version}`,draft:false,prerelease:false,make_latest:'false',
    body:`${owner.product} · ${owner.platform} · ${identity.version}\nSource: ${identity.source_sha}\nRun: ${identity.run_id} / ${identity.run_attempt}`}});
  if(!Number.isSafeInteger(release?.id)||!release.upload_url)fail('正式Release创建未确认');
  for(const file of files){const url=new URL(release.upload_url.replace(/\{.*$/u,''));url.searchParams.set('name',file.name);
    const asset=await request(url.href,{method:'POST',body:createReadStream(join(directory,file.name)),size:file.size});
    if(asset?.name!==file.name||asset.size!==file.size||asset.state!=='uploaded')fail('正式资产上传未确认');
    const response=await request(asset.url,{raw:true});if(!response?.body)fail('正式资产回读失败');
    const hash=createHash('sha256');let size=0;for await(const bytes of response.body){hash.update(bytes);size+=bytes.length;if(size>file.size)fail('正式资产回读超过声明大小');}
    if(size!==file.size||hash.digest('hex')!==file.sha256)fail('GitHub资产逐件回读不一致');
  }
  const readback=await request(`releases/${release.id}`);if((await inspectProductRelease(readback,owner.platform,tag=>request('git/ref/tags/'+encodeURIComponent(tag))))?.run_id!==identity.run_id||readback.draft||readback.prerelease
    ||readback.assets?.length!==files.length)fail('完整正式Release回查失败');
  for(const file of files){const asset=readback.assets.find(value=>value.name===file.name);if(!asset||asset.state!=='uploaded'||asset.size!==file.size||asset.digest!==`sha256:${file.sha256}`)fail('完整正式资产证明回查失败');}
  output('verified','true');output('release_id',release.id);output('tag',identity.tag);
}

function ownedRun(run) {
  // 每个目标只处理自身现行Workflow；文件缺失不能证明历史任务归属。
  return Number.isSafeInteger(run?.id)&&run.id>0&&run.path===workflowPath
    &&run.head_branch==='main'&&run.event==='workflow_dispatch'
    &&(!run.repository||run.repository.full_name===owner.repository);
}

export function cleanupPlan(runs,current,result) {
  if(!['success','failed'].includes(result)||!ownedRun(current)||!Number.isFinite(Date.parse(current.created_at)))fail('清理所属任务身份无效');
  const earlier=run=>Date.parse(run.created_at)<Date.parse(current.created_at)
    ||Date.parse(run.created_at)===Date.parse(current.created_at)&&run.id<current.id;
  return runs.filter(run=>ownedRun(run)&&run.id!==current.id&&run.status==='completed'&&earlier(run)
    &&(run.conclusion==='success'?'success':'failed')===result).sort((a,b)=>a.id-b.id);
}

async function remove(path,api) { await api(path,{method:'DELETE'});const readPath=path.replace(/^git\/refs\//u,'git/ref/');if(await api(readPath)!==null)fail('删除回查仍存在，清理失败'); }
async function removeRunRelease(run,releases,api) {
  for(const release of releases){
    const metadata=(await inspectProductRelease(release,owner.platform,tag=>api('git/ref/tags/'+encodeURIComponent(tag))));
    if(!metadata||metadata.run_id!==run.id)continue;
    if(metadata.source_sha!==run.head_sha)fail('正式Release与所属Run不一致');
    const tag=metadata.tag;
    const again=await api(`actions/runs/${run.id}`);
    if(again&&again.id!==Number(process.env.GITHUB_RUN_ID)
      &&(again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`releases/${release.id}`,api);
    const beforeTag=await api(`actions/runs/${run.id}`);
    if(beforeTag&&beforeTag.id!==Number(process.env.GITHUB_RUN_ID)
      &&(beforeTag.status!=='completed'||beforeTag.run_attempt!==run.run_attempt||beforeTag.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
  }
}
export async function cleanup(result,identity=context(),api=request) {
  const current=await api(`actions/runs/${identity.run_id}`);
  const plan=cleanupPlan(await pages('actions/runs','workflow_runs',api),current,result);
  const releases=await pages('releases',null,api),removed=[];
  for(const row of plan){const run=await api(`actions/runs/${row.id}`);if(!run){removed.push(row.id);continue;}
    if(run.run_attempt!==row.run_attempt||cleanupPlan([run],current,result).length!==1)continue;
    await removeRunRelease(run,releases,api);
    // 失败若只形成Tag也按它的准确Run坐标处理，不能留下同类孤立产物。
    const tags=await api(`git/matching-refs/tags/${prefix}`);
    if(!Array.isArray(tags))fail('所属Tag集合无效');
    for(const reference of tags){
      const tag=String(reference.ref||'').slice('refs/tags/'.length);
      if(!String(reference.ref||'').startsWith('refs/tags/'+prefix)
        ||!new RegExp(`-r${run.id}-a[1-9][0-9]*$`,'u').test(tag)||Number(tag.slice(tag.lastIndexOf('-a')+2))>run.run_attempt)continue;
      if(reference.object?.type!=='commit'||reference.object.sha!==run.head_sha)fail('所属Tag来源已改变，停止清理');
      const again=await api(`actions/runs/${run.id}`);
      if(!again||cleanupPlan([again],current,result).length!==1)fail('所属任务已改变，停止清理');
      await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
    }
    for(const asset of await pages(`actions/runs/${run.id}/artifacts`,'artifacts',api)){
      if(!Number.isSafeInteger(asset.id)||asset.id<=0)fail('所属Artifact坐标无效');
      const again=await api(`actions/runs/${run.id}`);if(!again||again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion)fail('历史任务已变化，停止清理');
      await remove(`actions/artifacts/${asset.id}`,api);
    }
    const final=await api(`actions/runs/${run.id}`);
    if(final&&(final.run_attempt!==run.run_attempt||cleanupPlan([final],current,result).length!==1))fail('历史任务状态改变，停止清理');
    if(final)await remove(`actions/runs/${run.id}`,api);removed.push(run.id);
  }
  return removed;
}

export function precedingResult(needs) {
  if(!needs||typeof needs!=='object'||Array.isArray(needs)||!Object.keys(needs).length)fail('前置任务结果缺失');
  return Object.values(needs).every(value=>value?.result==='success')?'success':'failed';
}
async function discardCurrent(identity,api) {
  for(const release of await pages('releases',null,api)){
    const metadata=(await inspectProductRelease(release,owner.platform,tag=>api('git/ref/tags/'+encodeURIComponent(tag))));
    if(metadata?.run_id===identity.run_id&&metadata.run_attempt===identity.run_attempt)
      await removeRunRelease({id:identity.run_id,head_sha:identity.source_sha},[release],api);
  }
  const tag=process.env.RELEASE_TAG;
  if(tag&&tag.startsWith(prefix)&&tag.endsWith(`-r${identity.run_id}-a${identity.run_attempt}`)){
    const path=`git/refs/tags/${encodeURIComponent(tag)}`;
    if(await api(path.replace(/^git\/refs\//u,'git/ref/'))!==null)await remove(path,api);
  }
}
export async function finish(needs=JSON.parse(process.env.RELEASE_NEEDS||'null'),api=request,identity=context()) {
  const result=precedingResult(needs),errors=[];
  const attempt=async action=>{try{return await action();}catch(error){errors.push(error);return null;}};
  let removed;
  if(result==='success') {
    removed=await attempt(()=>cleanup('success',identity,api));
    if(errors.length) {
      await attempt(()=>discardCurrent(identity,api));
      await attempt(()=>cleanup('failed',identity,api));
    }
  } else {
    // 本次撤销失败也必须尝试清理同目标旧失败；各项真实错误均保留。
    await attempt(()=>discardCurrent(identity,api));
    removed=await attempt(()=>cleanup('failed',identity,api));
  }
  if(errors.length)throw new AggregateError(errors,'本目标最后处理失败：'+errors.map(error=>error.message).join('；'));
  if(process.env.GITHUB_STEP_SUMMARY)appendFileSync(process.env.GITHUB_STEP_SUMMARY,`本目标${result==='success'?'成功':'失败'}；已清理同类旧Run：${removed.join('、')||'无'}。\n`);
  if(result==='failed')fail('前置任务未全部成功');
}

const direct=process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url);
const testing=direct&&Boolean(process.env.NODE_TEST_CONTEXT)&&process.argv.length===2;
if(direct&&!testing){
  try{const [command,...args]=process.argv.slice(2);
    if(command==='package')await automationPackageCommand(args);
    else if(command==='verify-assets')await automationVerifyAssets(args);
    else if(command==='analysis-options')automationAnalysisOptions(args[0],args[1]);
    else if(command==='native')automationNative(args[0],args[1]);
    else if(command==='native-finish')automationNativeFinish(args[0]);
    else if(command==='isar')automationIsar(...args);
    else if(command==='prepare')await prepare();else if(command==='job')job();else if(command==='step')step(args[0]);
    else if(command==='collect')await collect(args);
    else if(command==='collect-produced')await collectProduced();else if(command==='publish')await publish(args[0]);else if(command==='finish')await finish();
    else fail('自动化命令无效');
  }catch(error){console.error(error.message);process.exitCode=1;}
}

if(testing){
  const {default:assert}=await import('node:assert/strict');const {default:test}=await import('node:test');

  test('旧入口不能成为任一现行平台的清理归属证明',()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    const old={...current,id:1,status:'completed',conclusion:'success',created_at:'2026-01-01T00:00:00Z'};
    for(const path of ['.github/workflows/release.yml',`.github/workflows/${owner.product}-${owner.platform}-ci.yml`,'.github/workflows/deleted.yml'])
      assert.deepEqual(cleanupPlan([{...old,path}],current,'success'),[]);
  });
  test('撤销当前产物失败仍处理旧失败且最终失败',async()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    let releases=0,history=0;
    const api=async path=>{
      if(path.startsWith('releases?')){if(++releases===1)throw Error('撤销中断');return [];}
      if(path==='actions/runs/9')return current;
      if(path.startsWith('actions/runs?')){history++;return {workflow_runs:[]};}
      throw Error('未声明请求');
    };
    await assert.rejects(finish({build:{result:'failure'}},api,{run_id:9}),/撤销中断/);
    assert.equal(history,1);assert.equal(releases,2);
  });
  test('清理旧失败Run同时回收其多个Attempt的准确孤立Tag',async()=>{
    const old={id:2,run_attempt:2,path:workflowPath,head_branch:'main',event:'workflow_dispatch',head_sha:'a'.repeat(40),status:'completed',conclusion:'failure',created_at:'2026-01-01T00:00:00Z'},current={...old,id:9,status:'in_progress',created_at:'2026-01-02T00:00:00Z'};
    const deleted=new Set(),tags=[1,2].map(attempt=>({ref:`refs/tags/${prefix}1.0.0-r2-a${attempt}`,object:{type:'commit',sha:old.head_sha}}));
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){deleted.add(path);return {};}
      if(deleted.has(path)||deleted.has(path.replace('git/ref/','git/refs/')))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:[old,current]};
      if(path.startsWith('releases?')||path.includes('/artifacts?'))return path.includes('/artifacts?')?{artifacts:[]}:[];
      if(path.startsWith('git/matching-refs/'))return tags;
      if(path==='actions/runs/2')return old;if(path==='actions/runs/9')return current;
      throw Error('未声明的请求');
    };
    assert.deepEqual(await cleanup('failed',{run_id:9},api),[2]);assert.equal([...deleted].filter(path=>path.startsWith('git/refs/')).length,2);
  });
  test('全部前置成功才成功，其余结论一律失败',()=>{
    assert.equal(precedingResult({build:{result:'success'},publish:{result:'success'}}),'success');
    for(const result of ['failure','cancelled','skipped','timed_out',undefined])assert.equal(precedingResult({build:{result}}),'failed');
    assert.throws(()=>precedingResult({}));
  });
  test('当前Run尚在运行也能清理同目标旧结果，保护其它目标和活动任务',()=>{
    const row=(id,conclusion='success',status='completed',path=workflowPath)=>({id,conclusion,status,path,head_branch:'main',event:'workflow_dispatch',created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(6,null,'in_progress');const rows=[row(1),row(2,'failure'),row(3,'success','in_progress'),row(4,'success','completed','.github/workflows/release-other.yml'),current,row(7)];
    assert.deepEqual(cleanupPlan(rows,current,'success').map(row=>row.id),[1]);
    assert.deepEqual(cleanupPlan(rows,current,'failed').map(row=>row.id),[2]);
  });
  test('软件版本进位与越界',()=>{
    assert.equal(nextVersion('1.0.0',['1.99.99']),'2.0.0');
    assert.throws(()=>nextVersion('1.0.0',[],0));
  });
  test('历史完整分页不截断超过1000条记录',async()=>{
    const rows=Array.from({length:1005},(_,id)=>({id}));const api=async path=>rows.slice((Number(/page=(\d+)$/u.exec(path)[1])-1)*100,Number(/page=(\d+)$/u.exec(path)[1])*100);
    assert.equal((await pages('releases',null,api)).length,1005);
  });
  test('失败清理只删除所属旧失败产物及Run，成功和活动任务独立保留',async()=>{
    const row=(id,conclusion,status='completed')=>({id,run_attempt:1,conclusion,status,path:workflowPath,head_branch:'main',event:'workflow_dispatch',repository:{full_name:owner.repository},head_sha:'a'.repeat(40),created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(10,null,'in_progress'),rows=[row(1,'success'),row(2,'failure'),row(3,null,'in_progress'),current];
    const gone=new Set(),removed=[];
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){removed.push(path);gone.add(path);return {};}
      if(gone.has(path))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:rows};
      if(path.startsWith('releases?')||path.startsWith('git/matching-refs/'))return [];
      if(path.startsWith('actions/runs/2/artifacts?'))return {artifacts:[{id:20}]};
      if(path==='actions/artifacts/20')return {id:20};
      const match=/^actions\/runs\/(\d+)$/u.exec(path);if(match)return rows.find(row=>row.id===Number(match[1]))??null;
      throw Error('未声明的模拟接口：'+path);
    };
    assert.deepEqual(await cleanup('failed',{run_id:10},api),[2]);
    assert.deepEqual(removed,['actions/artifacts/20','actions/runs/2']);
  });

  test('GitHub运行序号保证成功历史清理后版本不会回到初始值',()=>{
    assert.equal(nextVersion('1.0.0',[],4),'1.0.3');
    assert.equal(nextVersion('1.99.99',[],2),'2.0.0');
    assert.equal(nextVersion('1.0.0',['3.0.0'],4),'3.0.1');
    assert.throws(()=>nextVersion('1.0.0',[],0));
  });

  test('宿主原生库保留至Flutter测试结束并由本仓入口收尾',()=>{
    const source=commands['check-9'].source;
    assert.ok(source.includes('export PRODUCT_WORK_DIR="$PWD/target/test"'));
    assert.ok(source.includes('export CARGO_TARGET_DIR="$PRODUCT_WORK_DIR/cargo"'));
    const trap=source.indexOf("trap 'node ./.github/workflows/release-sdk.mjs native-finish test' EXIT");
    const native=source.indexOf('node ./.github/workflows/release-sdk.mjs native host');
    const flutter=source.indexOf('flutter test');
    assert.ok(trap>=0&&trap<native&&native<flutter);
    assert.ok(source.includes('export DYLD_LIBRARY_PATH="$CARGO_TARGET_DIR/debug"'));
  });

}
