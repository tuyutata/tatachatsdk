import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, existsSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

test('tatachatsdk.sdk.ci的check远端Job物理独立', () => {
  const source = readFileSync(new URL('./execute.mjs', import.meta.url), 'utf8');
  assert.ok(source.includes('{"pipeline":"tatachatsdk.sdk.ci","job":"check"}'));
  assert.match(source, /function runExactWorkflowStep\(index\)/u);
  assert.match(source, /function requireExactRemoteJobEnvironment\(\)/u);
});

// 真实执行产品入口的只读拒绝分支，不联网、不编译、不读取任何发布凭据。
test('独立 SDK Job 拒绝旧聚合仓、其它产品和缺少仓库身份', () => {
  const script = fileURLToPath(new URL('./execute.mjs', import.meta.url));
  for (const repository of ['unregistered-owner/unregistered-product', 'crcfrcn/unregistered-product', 'tuyutata/tatachatserver', 'crcfrcn/citizensdk', '']) {
    const result = spawnSync(process.execPath, [script, 'workflow-step', '999'], {
      encoding: 'utf8', env: { ...process.env, GITHUB_REPOSITORY: repository },
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /准确远端Job仓库身份无效/u);
  }
});

// 根目录复制实际覆盖含空格路径、隐藏源码与 Git 元数据排除，禁止回写来源。
test('CI 临时工程来自完整 SDK 仓根且排除 Git 元数据', () => {
  const work = mkdtempSync(join(tmpdir(), 'tatachatsdk-root-'));
  const source = join(work, 'source with spaces');
  const temporary = join(work, 'runner with spaces');
  mkdirSync(join(source, '.git'), { recursive: true });
  mkdirSync(join(source, 'lib'), { recursive: true });
  mkdirSync(temporary);
  writeFileSync(join(source, '.git/config'), 'synthetic git metadata');
  writeFileSync(join(source, '.source'), 'controlled hidden source');
  writeFileSync(join(source, 'lib/api.dart'), 'controlled source');
  try {
    const result = spawnSync(process.execPath, [fileURLToPath(new URL('./execute.mjs', import.meta.url)), 'workflow-step', '8'], {
      cwd: source, encoding: 'utf8', env: { ...process.env,
        PATH: dirname(process.execPath) + ':/usr/bin:/bin',
        GITHUB_REPOSITORY: 'tuyutata/tatachatsdk', GITHUB_WORKSPACE: source, RUNNER_TEMP: temporary },
    });
    assert.equal(result.status, 0, result.stderr);
    const output = join(temporary, 'tatachatsdk/build-source');
    assert.equal(readFileSync(join(output, 'lib/api.dart'), 'utf8'), 'controlled source');
    assert.equal(readFileSync(join(output, '.source'), 'utf8'), 'controlled hidden source');
    assert.equal(existsSync(join(output, '.git')), false);
    assert.equal(readFileSync(join(source, '.git/config'), 'utf8'), 'synthetic git metadata');
    const repeated = spawnSync(process.execPath, [fileURLToPath(new URL('./execute.mjs', import.meta.url)), 'workflow-step', '8'], {
      cwd: source, encoding: 'utf8', env: { ...process.env,
        PATH: dirname(process.execPath) + ':/usr/bin:/bin',
        GITHUB_REPOSITORY: 'tuyutata/tatachatsdk', GITHUB_WORKSPACE: source, RUNNER_TEMP: temporary },
    });
    assert.notEqual(repeated.status, 0);
  } finally { rmSync(work, { recursive: true, force: true }); }
});

// 实际 Bash 分词必须分别调用 Android、iOS、macOS；伪编译器只生成夹具字节。
test('三端 CI 原生调用使用真实 Shell 续行且四项输出完整', () => {
  const work = mkdtempSync(join(tmpdir(), 'tatachatsdk-native-steps-'));
  const source = join(work, 'source with spaces');
  const temporary = join(work, 'runner with spaces');
  const build = join(temporary, 'tatachatsdk/build-source');
  mkdirSync(source);
  mkdirSync(join(build, 'scripts'), { recursive: true });
  const compiler = join(build, 'scripts/build-native.sh');
  writeFileSync(compiler, `#!/bin/bash
set -euo pipefail
printf '%s\n' "$1" >> "$RUNNER_TEMP/native-actions"
case "$1" in
  android)
    mkdir -p "$TATACHATSDK_NATIVE_ANDROID_DIR/arm64-v8a"
    printf 'android fixture' > "$TATACHATSDK_NATIVE_ANDROID_DIR/arm64-v8a/libtatachat_sdk.so"
    ;;
  ios) printf 'ios fixture' > "$TATACHATSDK_NATIVE_IOS_DIR/fixture" ;;
  macos) printf 'macos fixture' > "$TATACHATSDK_NATIVE_MACOS_DIR/libtatachat_sdk.dylib" ;;
  *) exit 91 ;;
esac
`, { mode: 0o755 });
  try {
    const result = spawnSync(process.execPath, [fileURLToPath(new URL('./execute.mjs', import.meta.url)), 'workflow-step', '10'], {
      cwd: source, encoding: 'utf8', env: { ...process.env,
        PATH: dirname(process.execPath) + ':/usr/bin:/bin',
        GITHUB_REPOSITORY: 'tuyutata/tatachatsdk', GITHUB_WORKSPACE: source,
        RUNNER_TEMP: temporary, SOURCE_SHA: '0123456789abcdef0123456789abcdef01234567' },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(readFileSync(join(temporary, 'native-actions'), 'utf8'), 'android\nios\nmacos\n');
    assert.equal(readFileSync(join(temporary, 'tatachatsdk/native/android/libtatachat_sdk.so'), 'utf8'), 'android fixture');
    assert.equal(readFileSync(join(temporary, 'tatachatsdk/native/ios/fixture'), 'utf8'), 'ios fixture');
    assert.equal(readFileSync(join(temporary, 'tatachatsdk/native/macos/libtatachat_sdk.dylib'), 'utf8'), 'macos fixture');
    assert.equal(readFileSync(join(temporary, 'tatachatsdk/source-sha.txt'), 'utf8'), '0123456789abcdef0123456789abcdef01234567\n');
  } finally { rmSync(work, { recursive: true, force: true }); }
});
