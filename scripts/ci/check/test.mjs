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

// 夹具按锁定Pub坐标解析实际文件，并拒绝缓存外、重复坐标、错误身份及符号链接。
test('SDK测试Isar仅消费本轮准确锁定普通库文件', async () => {
  const {realpathSync,symlinkSync}=await import('node:fs');
  const {pathToFileURL}=await import('node:url');
  const {isarCorePath}=await import('./native.mjs');
  const root=realpathSync(mkdtempSync(join(tmpdir(),'chat-ci-isar-')));
  const cache=join(root,'pub'), pkg=join(cache,'hosted/pub.dev/isar_community_flutter_libs-3.3.2');
  const config=join(root,'package_config.json'),lock=join(root,'pubspec.lock'),library=join(pkg,'macos/libisar.dylib');
  mkdirSync(join(pkg,'macos'),{recursive:true});writeFileSync(library,'fixture');
  writeFileSync(join(pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.2\n');
  writeFileSync(lock,'packages:\n  isar_community_flutter_libs:\n    source: hosted\n    version: "3.3.2"\n');
  const packageValue={name:'isar_community_flutter_libs',rootUri:pathToFileURL(pkg+'/').href};
  const set=packages=>writeFileSync(config,JSON.stringify({configVersion:2,packages}));
  const resolve=()=>isarCorePath(config,cache,lock,'darwin','arm64');
  try {
    set([packageValue]);assert.equal(resolve(),library);
    set([packageValue,packageValue]);assert.throws(resolve,/不唯一/);
    set([{...packageValue,rootUri:'https://example.invalid/native'}]);assert.throws(resolve,/坐标无效/);
    const outside=join(root,'outside');mkdirSync(outside);set([{...packageValue,rootUri:pathToFileURL(outside+'/').href}]);assert.throws(resolve,/越出/);
    set([packageValue]);writeFileSync(join(pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.1\n');assert.throws(resolve,/身份与锁/);
    writeFileSync(join(pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.2\n');
    rmSync(library);symlinkSync(lock,library);assert.throws(resolve,/普通文件/);
    rmSync(library);assert.throws(resolve,/普通文件/);
    assert.throws(()=>isarCorePath(config,cache,lock,'linux','arm64'),/宿主不受支持|普通文件/);
  } finally {rmSync(root,{recursive:true,force:true});}
});

// 直接执行阶段9，证明宿主库在Flutter测试前准备，且准备失败不会运行跳过原生的测试。
test('SDK CI宿主原生和锁定Isar准备完成后才执行Flutter测试', async () => {
  const {realpathSync}=await import('node:fs');const {pathToFileURL}=await import('node:url');
  const root=realpathSync(mkdtempSync(join(tmpdir(),'chat-ci-host-'))),source=join(root,'source'),bin=join(root,'bin'),cache=join(root,'pub');
  const pkg=join(cache,'hosted/pub.dev/isar_community_flutter_libs-3.3.2');
  const target=join(root,'cargo'),log=join(root,'calls');
  mkdirSync(join(source,'scripts'),{recursive:true});mkdirSync(join(source,'.dart_tool'));mkdirSync(bin);
  for(const suffix of ['macos/libisar.dylib','linux/libisar.so']){
    mkdirSync(dirname(join(pkg,suffix)),{recursive:true});writeFileSync(join(pkg,suffix),'fixture');
  }
  writeFileSync(join(pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.2\n');
  writeFileSync(join(source,'pubspec.lock'),'packages:\n  isar_community_flutter_libs:\n    source: hosted\n    version: "3.3.2"\n');
  writeFileSync(join(source,'.dart_tool/package_config.json'),JSON.stringify({configVersion:2,packages:[{name:'isar_community_flutter_libs',rootUri:pathToFileURL(pkg+'/').href}]}));
  for(const tool of ['flutter','dart','cargo'])writeFileSync(join(bin,tool),`#!${process.execPath}
const fs=require('node:fs'); const tool=require('node:path').basename(process.argv[1]);
if(tool==='flutter'&&process.argv[2]==='test'){
 if(!fs.existsSync(process.env.ISAR_CORE_LIB_PATH)||process.env.DYLD_LIBRARY_PATH!==process.env.CARGO_TARGET_DIR+'/debug'||!fs.existsSync(process.env.CALLS)||!fs.readFileSync(process.env.CALLS,'utf8').includes('host\\n'))process.exit(73);
}
fs.appendFileSync(process.env.CALLS,tool+' '+process.argv.slice(2).join(' ')+'\\n');
`,{mode:0o755});
  writeFileSync(join(source,'scripts/build-native.sh'),'#!/bin/bash\nset -euo pipefail\n[[ "$1" == host ]]\n[[ "${FAIL_HOST:-}" != 1 ]] || exit 74\nprintf "host\\n" >> "$CALLS"\n',{mode:0o755});
  try {
    for(const fail of [false,true]){
      writeFileSync(log,'');
      const result=spawnSync(process.execPath,[fileURLToPath(new URL('./execute.mjs',import.meta.url)),'workflow-step','9'],{cwd:source,encoding:'utf8',env:{...process.env,
        PATH:bin+':'+process.env.PATH,GITHUB_REPOSITORY:'tuyutata/tatachatsdk',GITHUB_WORKSPACE:fileURLToPath(new URL('../../../',import.meta.url)).replace(/\/$/,''),PUB_CACHE:cache,CARGO_TARGET_DIR:target,CALLS:log,...(fail?{FAIL_HOST:'1'}:{})}});
      assert.equal(result.status,fail?74:0,result.stderr);
      const calls=readFileSync(log,'utf8');assert.equal(calls.includes('flutter test\n'),!fail);
      if(!fail)assert.ok(calls.indexOf('host\n')<calls.indexOf('flutter test\n'));
    }
  }finally{rmSync(root,{recursive:true,force:true});}
});
