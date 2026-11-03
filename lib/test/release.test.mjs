// 完整包测试只验证真实ZIP布局与来源边界；合成原生字节不代替各平台编译验收。
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {mkdirSync,mkdtempSync,readFileSync,writeFileSync,readdirSync,rmSync,symlinkSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {root,testRoot,sdkName,sourceView,setPackageVersion,verifyPackage,consume} from '../../scripts/build.mjs';
const source={version:'1.2.100',sourceSha:'a'.repeat(40),sourceRun:42,sourceAttempt:2};
const digest=value=>createHash('sha256').update(value).digest('hex');
function fixture(t,{change}={}){
 const work=mkdtempSync(join(testRoot(),'release-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
 const project=sourceView(work);setPackageVersion(project,source.version);
 for(const file of ['native/libtatachat_sdk.dylib','android/src/main/jniLibs/arm64-v8a/libtatachat_sdk.so','ios/TataChatSDK.xcframework/Info.plist','ios/TataChatSDK.xcframework/ios-arm64/TataChatSDK.framework/TataChatSDK','ios/TataChatSDK.xcframework/ios-arm64-simulator/TataChatSDK.framework/TataChatSDK']){
  const path=join(project,file);mkdirSync(join(path,'..'),{recursive:true});writeFileSync(path,'synthetic-layout-only');
 }
 change?.(project);
 const directory=join(work,'download');mkdirSync(directory);const name=sdkName(source.version);
 execFileSync('zip',['-q','-r','-y',join(directory,name+'.zip'),'project'],{cwd:work});
 const proof={product_id:'tatachatsdk',platform:'sdk',software_version:source.version,git_commit_sha:source.sourceSha,producer_run_id:source.sourceRun,producer_run_attempt:source.sourceAttempt,assets:[{name:name+'.zip',sha256:digest(readFileSync(join(directory,name+'.zip')))}]};
 const json=JSON.stringify(proof);writeFileSync(join(directory,name+'.json'),json);
 writeFileSync(join(directory,name+'.sha256'),proof.assets[0].sha256+'  '+name+'.zip\n'+digest(json)+'  '+name+'.json\n');
 return {work,project,directory,name,proof,output:join(work,'consumer')};
}
test('完整Release按准确来源消费并交付SDK自身公开源码视图',async t=>{
 const value=fixture(t),before=readdirSync(value.directory).map(name=>[name,digest(readFileSync(join(value.directory,name)))]);
 assert.deepEqual(await verifyPackage(value.directory,source),value.proof);
 assert.deepEqual(await consume({...value,...source}),{output:value.output});
 assert.equal(readFileSync(join(value.output,'pubspec.yaml'),'utf8'),readFileSync(join(value.project,'pubspec.yaml'),'utf8'));
 assert.equal(readFileSync(join(value.output,'native/libtatachat_sdk.dylib'),'utf8'),'synthetic-layout-only');
 assert.deepEqual(readdirSync(value.directory).map(name=>[name,digest(readFileSync(join(value.directory,name)))]),before);
 await assert.rejects(consume({...value,...source}),/输入或输出无效/);
});
test('篡改、错提交及错Run均拒绝消费且不留下输出',async t=>{
 for(const change of ['sha','attempt','run','bytes','extra']){
  const value=fixture(t),expected={...source};
  if(change==='sha')expected.sourceSha='b'.repeat(40);
  if(change==='attempt')expected.sourceAttempt++;
  if(change==='run')expected.sourceRun++;
  if(change==='bytes')writeFileSync(join(value.directory,value.name+'.zip'),'tampered');
  if(change==='extra')writeFileSync(join(value.directory,'extra'),'unexpected');
  await assert.rejects(consume({...value,...expected}));assert.equal(existsSync(value.output),false);
 }
});
test('已校验ZIP中的链接、缺原生件、工具残留和错包版本仍拒绝',async t=>{
 for(const change of [
  project=>symlinkSync('/tmp',join(project,'native/link')),
  project=>rmSync(join(project,'native/libtatachat_sdk.dylib')),
  project=>mkdirSync(join(project,'.dart_tool')),
  project=>setPackageVersion(project,'1.2.101'),
 ]){
  const value=fixture(t,{change});await assert.rejects(consume({...value,...source}));assert.equal(existsSync(value.output),false);
 }
});
test('聊天SDK从正式Release计算新版本，保留源码版本下限并忽略草稿预发布',()=>{
 const workflow=readFileSync(join(root,'.github/workflows/sdk.yml'),'utf8');
 const match=/node --input-type=module >> "\$GITHUB_OUTPUT" <<'NODE'\n([\s\S]*?)          NODE/u.exec(workflow);assert.ok(match);
 const program=match[1].replace(/^          /gmu,'').replace(/^import .*\n/gmu,'');
 for(const [declared,previous,expected]of [['1.0.0',null,'1.0.0'],['2.0.0','1.9.99','2.0.0'],['1.0.0','1.0.9','1.0.10']]){
  const release=(version,extra={})=>({draft:false,prerelease:false,published_at:'2026-11-02',body:JSON.stringify({product_id:'tatachatsdk',platform:'sdk',software_version:version}),...extra});
  const rows=[release('9.0.0',{draft:true}),release('9.0.1',{prerelease:true}),...previous?[release(previous)]:[]],lines=[];
  new Function('readFileSync','process','console',program)(path=>path==='pubspec.yaml'?'version: '+declared+'\n':JSON.stringify([rows]),{env:{RUNNER_TEMP:'/fixture'}},{log:value=>lines.push(value)});
  assert.deepEqual(lines,['version='+expected]);
 }
});
