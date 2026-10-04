#!/usr/bin/env node
import { spawnSync as runExactProcess } from 'node:child_process';
function validateCandidate(){const value=process.env;
if(!/^[0-9a-f]{40}$/.test(value.SOURCE_SHA||'')||!/^[1-9][0-9]*$/.test(value.CI_RUN_ID||'')||!/^\d+\.\d{1,2}\.\d{1,2}$/.test(value.SOFTWARE_VERSION||'')||value.VERSION_TAG!=='tatachatsdk-sdk-v'+value.SOFTWARE_VERSION)throw Error('准确Release候选无效');}

// 本文件只执行 tatachatsdk.sdk.release 的 check Job；阶段编号由本仓唯一 Workflow 固定，禁止接收其它身份。
export const EXACT_REMOTE_JOB_IDENTITY=Object.freeze({"pipeline":"tatachatsdk.sdk.release","job":"check"});

function requireExactRemoteJobEnvironment() {
  const expected = 'tuyutata/tatachatsdk';
  if (!expected || process.env.GITHUB_REPOSITORY !== expected) {
    throw new Error('准确远端Job仓库身份无效');
  }
}
const workflowSteps=Object.freeze({"0":{"shell":"bash","source":"cargo install cargo-audit --locked"},"1":{"shell":"bash","source":"node \"$GITHUB_WORKSPACE/scripts/release/index.mjs\" version-tag verify-release-source --ci-run-id \"$CI_RUN_ID\" --version-tag \"$VERSION_TAG\" --source-sha \"$SOURCE_SHA\" --software-version \"$SOFTWARE_VERSION\" --prefix tatachatsdk-sdk-v --product-id tatachatsdk --target sdk --workflow tatachatsdk.sdk.ci"},"2":{"shell":"bash","source":"native_root=\"$RUNNER_TEMP/tatachatsdk/ci\"\nmkdir -p \"$native_root\"\ngh run download \"$CI_RUN_ID\" --name TataChatSDK-CI --dir \"$native_root\"\ntest \"$(cat \"$native_root/source-sha.txt\")\" = \"$SOURCE_SHA\"\ntest -s \"$native_root/native/android/libtatachat_sdk.so\"\ntest -s \"$native_root/native/ios/TataChatSDK.xcframework/Info.plist\"\ntest -s \"$native_root/native/ios/TataChatSDK.xcframework/ios-arm64/TataChatSDK.framework/Info.plist\"\ntest -s \"$native_root/native/ios/TataChatSDK.xcframework/ios-arm64/TataChatSDK.framework/TataChatSDK\"\ntest -s \"$native_root/native/macos/libtatachat_sdk.dylib\"\n"},"3":{"shell":"bash","source":"output=\"$RUNNER_TEMP/tatachatsdk/release\"\nnode scripts/release.mjs \\\n  --source . \\\n  --native \"$RUNNER_TEMP/tatachatsdk/ci/native\" \\\n  --output \"$output\" \\\n  --archive \"$output/tatachatsdk.tgz\" \\\n  --git-sha \"$SOURCE_SHA\" \\\n  --software-version \"$SOFTWARE_VERSION\"\nnode scripts/release.mjs --verify-assets \"$output\" \\\n  --expected-git-sha \"$SOURCE_SHA\" \\\n  --software-version \"$SOFTWARE_VERSION\"\n"}});
function runExactWorkflowStep(index){requireExactRemoteJobEnvironment();if(!/^(?:0|[1-9][0-9]*)$/.test(String(index||''))||!Object.hasOwn(workflowSteps,String(index)))throw new Error('准确远端Job阶段无效');const step=workflowSteps[String(index)];const command=step.shell==='pwsh'?'pwsh':(process.platform==='win32'?'bash':'/bin/bash');const args=step.shell==='pwsh'?['-NoLogo','-NoProfile','-NonInteractive','-Command',step.source]:['--noprofile','--norc','-e','-o','pipefail','-c',step.source];const result=runExactProcess(command,args,{cwd:process.cwd(),env:process.env,stdio:'inherit'});if(result.error)throw new Error('准确远端Job阶段无法启动');if(result.status!==0)process.exitCode=Number.isInteger(result.status)?result.status:1;}

requireExactRemoteJobEnvironment();
validateCandidate();
if(process.argv[2]==='validate-inputs') process.exit(0);
if(process.argv[2]!=='workflow-step')throw new Error('准确Release Job只接受workflow-step');
runExactWorkflowStep(process.argv[3]);
