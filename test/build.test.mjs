// SDK自身的构建回归；不放入编译入口，不连接真实GitHub。
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {sdkName} from '../scripts/build.mjs';
import {describeAction} from '../scripts/config.mjs';
import {root,testRoot,claimCache,verifyNative,createFlutterSourceView,assertFlutterSourceView,sourceView,setPackageVersion} from '../scripts/build.mjs';

test('SDK产物名称保留本地安全边界，自动化仅声明数据',()=>{
 assert.equal(sdkName('1.2.100'),'塔塔聊天·SDK·v1.2.100');for(const value of ['1.02.0','../1.0.0','1.0.0\n'])assert.throws(()=>sdkName(value));
 assert.deepEqual(describeAction({flow:'release',platform:'sdk'}),{repository:'tuyutata/tatachatsdk',workflow:'sdk.yml',ref:'main',inputs:{}});
});

test('真实原生件核验拒绝缺符号、错误架构和退役接口',async()=>{
 const symbols=[...readFileSync(join(root,'native/tatachat_sdk.h'),'utf8').matchAll(/\b(tatachat_sdk_[a-z_]+)\s*\(/gu)].map(value=>value[1]).join('\n');
 await assert.rejects(verifyNative('/fixture','macos',async()=>''),/缺少符号/);
 await assert.rejects(verifyNative('/fixture','macos',async command=>command==='/usr/bin/file'?'ELF x86-64':symbols),/架构/);
 await assert.rejects(verifyNative('/fixture','macos',async()=>symbols+'\ntatachat_sdk_mls_two_party_smoke_json'),/撤销接口/);
});
test('Flutter公开布局入口用于源码与正式SDK，漂移必须失败',t=>{
 const work=mkdtempSync(join(testRoot(),'layout-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
 const project=createFlutterSourceView(root,join(work,'project'));assert.equal(assertFlutterSourceView(root,project),project);
 const consumer=createFlutterSourceView(project,join(work,'consumer'));assert.equal(assertFlutterSourceView(project,consumer),consumer);
 writeFileSync(join(project,'android/src/main/AndroidManifest.xml'),'损坏');assert.throws(()=>assertFlutterSourceView(root,project),/不一致/);
});
test('缓存占用立即使用本轮目录，不释放别人的锁',t=>{
 const work=mkdtempSync(join(testRoot(),'cache-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
 const first=claimCache(work),second=claimCache(work);t.after(()=>first.release());
 assert.equal(second.cargo,join(work,'rust'));assert.equal(second.pub,join(work,'pub'));second.release();
 assert.ok(existsSync(join(root,'target/cache/lock')));
});
test('交付目录的三处版本一致，正式源码不被改写',t=>{
 const work=mkdtempSync(join(testRoot(),'version-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
 const before=readFileSync(join(root,'pubspec.yaml')),project=sourceView(work);setPackageVersion(project,'1.2.100');
 assert.match(readFileSync(join(project,'pubspec.yaml'),'utf8'),/^version: 1\.2\.100$/mu);
 assert.match(readFileSync(join(project,'ios/tatachat_sdk.podspec'),'utf8'),/spec\.version = '1\.2\.100'/u);
 assert.match(readFileSync(join(project,'android/build.gradle.kts'),'utf8'),/^version = "1\.2\.100"$/mu);
 assert.ok(readFileSync(join(root,'pubspec.yaml')).equals(before));
});

// HTTP夹具实际消费产品删除入口；原Run、日志、Artifact及发布资产共用同一合成服务。

