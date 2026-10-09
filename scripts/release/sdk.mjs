#!/usr/bin/env node
import {remoteStep} from '../target.mjs';
// 作业身份及阶段正文唯一归本模块；普通导入不改变环境或运行作业。
import {spawnSync as runExactProcess}from'node:child_process';
import {resolve}from'node:path';
import {fileURLToPath}from'node:url';
import {remoteEnvironment}from'../build.mjs';
export const EXACT_REMOTE_JOB_IDENTITY=Object.freeze({"pipeline":"tatachatsdk.sdk.release","job":"check"});
export const workflowSteps=Object.freeze({
  "0": {
    "shell": "bash",
    "source": "cargo install cargo-audit --locked"
  },
  "1": {
    "shell": "bash",
    "source": "node \"$GITHUB_WORKSPACE/scripts/release/index.mjs\" version-tag verify-release-source --ci-run-id \"$CI_RUN_ID\" --version-tag \"$VERSION_TAG\" --source-sha \"$SOURCE_SHA\" --software-version \"$SOFTWARE_VERSION\" --prefix tatachatsdk-sdk-v --product-id tatachatsdk --target sdk --workflow tatachatsdk.sdk.ci"
  },
  "2": {
    "shell": "bash",
    "source": "native_root=\"$RUNNER_TEMP/tatachatsdk/ci\"\nmkdir -p \"$native_root\"\ngh run download \"$CI_RUN_ID\" --name TataChatSDK-CI --dir \"$native_root\"\ntest \"$(cat \"$native_root/source-sha.txt\")\" = \"$SOURCE_SHA\"\ntest -s \"$native_root/native/android/libtatachat_sdk.so\"\ntest -s \"$native_root/native/ios/TataChatSDK.xcframework/Info.plist\"\ntest -s \"$native_root/native/ios/TataChatSDK.xcframework/ios-arm64/TataChatSDK.framework/Info.plist\"\ntest -s \"$native_root/native/ios/TataChatSDK.xcframework/ios-arm64/TataChatSDK.framework/TataChatSDK\"\ntest -s \"$native_root/native/macos/libtatachat_sdk.dylib\"\n"
  },
  "3": {
    "shell": "bash",
    "source": "output=\"$RUNNER_TEMP/tatachatsdk/release\"\nnode scripts/release.mjs \\\n  --source . \\\n  --native \"$RUNNER_TEMP/tatachatsdk/ci/native\" \\\n  --output \"$output\" \\\n  --archive \"$output/tatachatsdk.tgz\" \\\n  --git-sha \"$SOURCE_SHA\" \\\n  --software-version \"$SOFTWARE_VERSION\"\nnode scripts/release.mjs --verify-assets \"$output\" \\\n  --expected-git-sha \"$SOURCE_SHA\" \\\n  --software-version \"$SOFTWARE_VERSION\"\n"
  }
});
function requireExactRemoteJobEnvironment(){if(process.env.GITHUB_REPOSITORY!=='tuyutata/tatachatsdk')throw Error('准确远端Job仓库身份无效');}
function runExactWorkflowStep(index){requireExactRemoteJobEnvironment();if(!/^(?:0|[1-9][0-9]*)$/.test(String(index||''))||!Object.hasOwn(workflowSteps,String(index)))throw Error('准确远端Job阶段无效');const step=workflowSteps[String(index)];const command=step.shell==='pwsh'?'pwsh':process.platform==='win32'?'bash':'/bin/bash';const args=step.shell==='pwsh'?['-NoLogo','-NoProfile','-NonInteractive','-Command',step.source]:['--noprofile','--norc','-e','-o','pipefail','-c',step.source];const result=runExactProcess(command,args,{cwd:process.cwd(),env:process.env,stdio:'inherit'});if(result.error)throw Error('准确远端Job阶段无法启动');process.exitCode=result.status??1;}
function validateCandidate(){const value=process.env;
if(!/^[0-9a-f]{40}$/.test(value.SOURCE_SHA||'')||!/^[1-9][0-9]*$/.test(value.CI_RUN_ID||'')||!/^\d+\.\d{1,2}\.\d{1,2}$/.test(value.SOFTWARE_VERSION||'')||value.VERSION_TAG!=='tatachatsdk-sdk-v'+value.SOFTWARE_VERSION)throw Error('准确Release候选无效');}


const directInvocation=Boolean(!process.execArgv.some(value=>/^(?:-e|--eval(?:=|$)|--input-type(?:=|$))/u.test(value)) && process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url));
const testInvocation=directInvocation && (process.argv[2]==='test'||process.env.NODE_TEST_CONTEXT==='child-v8'&&process.argv.length===2);
if(directInvocation&&!testInvocation){try{
 if(process.env.GITHUB_ACTIONS==='true'&&String(process.env.GITHUB_WORKFLOW||'').startsWith('tatachatsdk.'))Object.assign(process.env,remoteEnvironment());
 requireExactRemoteJobEnvironment();
 validateCandidate();if(process.argv[2]!=='validate-inputs'){if(process.argv[2]!=='workflow-step')throw Error('准确Release Job只接受workflow-step');runExactWorkflowStep(process.argv[3]);}
}catch(error){console.error(error.message);process.exitCode=1;}}

// 正式实现结束；以下回归仅在本文件作为测试入口时注册。
if (testInvocation) {
const {default: assert}=await import('node:assert/strict');
const { readFileSync, writeFileSync, mkdirSync, mkdtempSync, existsSync, rmSync }=await import('node:fs');
const { spawnSync }=await import('node:child_process');
const { dirname, join }=await import('node:path');
const { testRoot: tmpdir }=await import('../build.mjs');
const { fileURLToPath }=await import('node:url');
const {default: test}=await import('node:test');

test('tatachatsdk.sdk.release的check远端Job物理独立', () => {
  const source = readFileSync(new URL('./sdk.mjs', import.meta.url), 'utf8');
  assert.ok(source.includes('{"pipeline":"tatachatsdk.sdk.release","job":"check"}'));
  assert.match(source, /function runExactWorkflowStep\(index\)/u);
  assert.match(source, /function requireExactRemoteJobEnvironment\(\)/u);
});

// 真实执行产品入口的只读拒绝分支，不联网、不编译、不读取任何发布凭据。
test('独立 SDK Job 拒绝旧聚合仓、其它产品和缺少仓库身份', () => {
  const script = fileURLToPath(new URL('./sdk.mjs', import.meta.url));
  for (const repository of ['unregistered-owner/unregistered-product', 'crcfrcn/unregistered-product', 'tuyutata/tuyuserve', 'crcfrcn/citizensdk', '']) {
    const result = spawnSync(process.execPath, [script, 'workflow-step', '999'], {
      encoding: 'utf8', env: { ...process.env, GITHUB_REPOSITORY: repository },
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /准确远端Job仓库身份无效/u);
  }
});

test('Release 候选只接受准确独立 SDK 仓及完整版本输入', () => {
  const script = fileURLToPath(new URL('./sdk.mjs', import.meta.url));
  const env = { ...process.env, GITHUB_REPOSITORY: 'tuyutata/tatachatsdk',
    SOURCE_SHA: '0123456789abcdef0123456789abcdef01234567', CI_RUN_ID: '1',
    SOFTWARE_VERSION: '1.0.0', VERSION_TAG: 'tatachatsdk-sdk-v1.0.0' };
  const valid = spawnSync(process.execPath, [script, 'validate-inputs'], { encoding: 'utf8', env });
  assert.equal(valid.status, 0, valid.stderr);
  const invalid = spawnSync(process.execPath, [script, 'validate-inputs'], {
    encoding: 'utf8', env: { ...env, VERSION_TAG: 'tatachatsdk-sdk-v1.0.1' },
  });
  assert.notEqual(invalid.status, 0);
  assert.match(invalid.stderr, /准确Release候选无效/u);
  const boundary = spawnSync(process.execPath, [script, 'workflow-step', '999'], { encoding: 'utf8', env });
  assert.notEqual(boundary.status, 0);
  assert.match(boundary.stderr, /准确远端Job阶段无效/u);
});

}
