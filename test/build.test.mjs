// SDK自身的构建回归；不放入编译入口，不连接真实GitHub。
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {sdkName,nextVersion,retainedRuns,cleanupRuns,automate,describeAction} from '../scripts/config.mjs';
import {root,testRoot,claimCache,verifyNative,createFlutterSourceView,assertFlutterSourceView,sourceView,setPackageVersion} from '../scripts/build.mjs';

test('成功才递增补丁，失败不占版本，SDK名称拒绝其它平台和坏版本',()=>{
 const row=(id,version,conclusion)=>({id,status:'completed',conclusion,display_title:sdkName(version),updated_at:'2026-10-19T00:00:00Z'});
 assert.equal(nextVersion([row(1,'1.2.99','success'),row(2,'1.2.100','failure')]),'1.2.100');
 assert.throws(()=>sdkName('1.02.0'));assert.throws(()=>nextVersion([{...row(1,'1.0.0','success'),display_title:'塔塔聊天·iOS·v1.0.0'}]));
});
test('只保留最新成功、失败及活动任务，取消归失败',()=>{
 const rows=[{id:1,status:'completed',conclusion:'success'},{id:2,status:'completed',conclusion:'success'},{id:3,status:'completed',conclusion:'failure'},{id:4,status:'completed',conclusion:'cancelled'},{id:5,status:'in_progress'}].map(value=>({...value,updated_at:'2026-10-19T00:00:00Z'}));
 assert.deepEqual([...retainedRuns(rows)].sort(),[2,4,5]);
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

// HTTP夹具实际消费产品删除入口；没有真实网络、令牌或GitHub记录。
function runRow(id,conclusion,status='completed'){return {id,status,conclusion,display_title:sdkName('1.1.'+id),updated_at:new Date(id*1000).toISOString()};}
function recordsFixture(initial){
 let rows=[...initial];const deleted=[];
 return {deleted,read:async path=>{assert.match(path,/^actions\/workflows\/sdk\.yml\/runs\?/);return {workflow_runs:rows};},remove:async id=>{deleted.push(id);rows=rows.filter(row=>row.id!==id);}};
}
test('产品真实执行旧Run删除，保留最新成功失败和全部活动任务，单独清理不派发',async()=>{
 let rows=[runRow(1,'success'),runRow(2,'failure'),runRow(3,'success'),runRow(4,'failure'),runRow(5,null,'in_progress')];const deleted=[];
 const fetchImpl=async(url,options)=>{
  if(options.method==='DELETE'){const id=Number(url.split('/').at(-1));assert.ok(url.startsWith('https://api.github.com/repos/tuyutata/tatachatsdk/actions/runs/'));deleted.push(id);rows=rows.filter(row=>row.id!==id);return new Response(null,{status:204});}
  assert.equal(options.method,'GET');assert.ok(url.includes('/actions/workflows/sdk.yml/runs?branch=main&event=workflow_dispatch&per_page=100&page='));return Response.json({workflow_runs:rows});
 };
 const declaration=await describeAction({flow:'cleanup',platform:'sdk'});
 const result=await declaration.launch({token:'synthetic',fetchImpl,report:()=>{}});
 assert.deepEqual(result.deleted,[1,2]);assert.deepEqual(result.kept.sort(),[3,4,5]);assert.deepEqual(deleted,[1,2]);
});
test('新失败保留原成功；删除失败或回读仍存在旧记录均明确失败',async()=>{
 const api=recordsFixture([runRow(1,'success'),runRow(2,'failure'),runRow(3,'failure')]);
 assert.deepEqual((await cleanupRuns({...api,report:()=>{}})).kept.sort(),[1,3]);
 const read=async()=>({workflow_runs:[runRow(1,'success'),runRow(2,'success')]});
 await assert.rejects(cleanupRuns({read,remove:async()=>{throw Error('GitHub HTTP 403');},report:()=>{}}),/403/);
 await assert.rejects(cleanupRuns({read,remove:async()=>{},report:()=>{}}),/删除尚未确认/);
});
test('产品等原Run真实结束后才删除旧记录，状态先于完成返回且显示异常不影响流程',async()=>{
 let state=0,posts=0;const events=[],old=runRow(1,'success'),current=runRow(2,'success');let rows=[old];
 const read=async path=>{
  if(path.includes('/workflows/'))return {workflow_runs:rows};
  if(path.includes('/jobs?'))return {jobs:[]};
  assert.equal(path,'actions/runs/2');state++;return state===1?{...current,status:'in_progress',conclusion:null}:current;
 };
 const remove=async id=>{assert.equal(state,2);assert.equal(id,1);rows=[current];};
 const result=await automate({read,remove,interval:0,dispatch:async spec=>{posts++;assert.equal(spec.inputs.version,'1.1.2');rows=[old,{...current,status:'in_progress',conclusion:null}];return {workflow_run_id:2};},report:event=>{events.push(event);if(event.event==='jobs')throw Error('合成显示断开');}});
 assert.equal(result.runID,2);assert.equal(posts,1);assert.equal(events[0].event,'started');assert.equal(events[1].run.status,'in_progress');assert.ok(events.some(event=>event.event==='run'&&event.run.status==='completed'));
});
test('列表分页完整读取，不把第一页当全部历史记录',async()=>{
 const rows=[...Array.from({length:100},(_,index)=>runRow(index+2,'success')),runRow(1,'failure')],deleted=[],pages=[];
 const read=async path=>{const page=Number(new URL('https://example.test/'+path).searchParams.get('page'));pages.push(page);return {workflow_runs:rows.filter(row=>!deleted.includes(row.id)).slice((page-1)*100,page*100)};};
 const result=await cleanupRuns({read,remove:async id=>{deleted.push(id);},report:()=>{}});
 assert.equal(deleted.length,99);assert.deepEqual(result.kept.sort((a,b)=>a-b),[1,101]);assert.ok(pages.includes(2));
});
