// 本产品配置需求的公开入口；只登记名称、类型和规则，不保存配置值。
export const manifest=Object.freeze({
  "schema": 1,
  "product_id": "tatachatsdk",
  "configuration": {
    "id": "tatachatsdk",
    "kind": "software",
    "title": "塔塔聊天配置",
    "items": []
  }
});
export function describeConfiguration(){return JSON.parse(JSON.stringify(manifest));}

// 编译与自动化共用本产品声明，不依赖控制台模块。
import {readFileSync} from 'node:fs';
export const tools=Object.freeze({node:'25.2.1',rust:'1.97.1',flutter:'3.47.2',ndk:'28.2.13676358',protoc:'35.0',protocPlugin:'25.0.0'});
export const repository='tuyutata/tatachatsdk';
export function sdkName(version){
 if(typeof version!=='string'||version.length>64||!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/u.test(version))throw Error('SDK版本无效');
 return '塔塔聊天·SDK·v'+version;
}
export function nextVersion(runs){
 const latest=[...runs].filter(run=>run.status==='completed'&&run.conclusion==='success')
  .sort((a,b)=>Date.parse(b.updated_at)-Date.parse(a.updated_at)||b.id-a.id)[0];
 if(!latest){const version=/^version: (\S+)$/mu.exec(readFileSync(new URL('../pubspec.yaml',import.meta.url),'utf8'))?.[1];sdkName(version);return version;}
 const prefix='塔塔聊天·SDK·v',version=latest.display_title?.startsWith(prefix)?latest.display_title.slice(prefix.length):'';
 sdkName(version);const parts=version.split('.');parts[2]=String(BigInt(parts[2])+1n);const next=parts.join('.');sdkName(next);return next;
}
export function retainedRuns(rows){
 const keep=new Set(),states=new Set();
 for(const run of [...rows].sort((a,b)=>Date.parse(b.updated_at)-Date.parse(a.updated_at)||b.id-a.id)){
  if(run.status!=='completed'){keep.add(run.id);continue;}
  const state=run.conclusion==='success'?'success':'failed';if(!states.has(state)){states.add(state);keep.add(run.id);}
 }
 return keep;
}

// 产品自己拥有派发、观察和终态清理；公开输出只传递GitHub状态和固定说明。
function reportEvent(value){
 if(!process.stdout.listenerCount('error'))process.stdout.on('error',()=>{});
 try{process.stdout.write(JSON.stringify(value)+'\n',()=>{});}catch{}
}
function emit(report,value){try{report(value);}catch{}}
function line(report,text){emit(report,{event:'output',stream:'stdout',data:Buffer.from(text+'\n').toString('base64')});}
async function request(token,path,{method='GET',body,fetchImpl=fetch}={}){
 const response=await fetchImpl('https://api.github.com/repos/'+repository+'/'+path,{method,redirect:'error',
  headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','Content-Type':'application/json','X-GitHub-Api-Version':'2026-03-10','User-Agent':'TataChatSDK'},
  ...(body===undefined?{}:{body:JSON.stringify(body)})});
 if(!response.ok)throw Error('GitHub HTTP '+response.status);
 return response.status===204?null:response.json();
}
async function workflowRuns(read){
 const rows=[];
 for(let page=1;;page++){
  const data=await read('actions/workflows/sdk.yml/runs?branch=main&event=workflow_dispatch&per_page=100&page='+page);
  rows.push(...data.workflow_runs);if(data.workflow_runs.length<100)return rows;
 }
}
// 只处理本产品SDK Workflow；活动任务原样保留，删除失败不得伪装成完成。
export async function cleanupRuns({token,fetchImpl=fetch,read=path=>request(token,path,{fetchImpl}),remove=id=>request(token,'actions/runs/'+id,{method:'DELETE',fetchImpl}),completedRun,report=reportEvent}={}){
 const rows=await workflowRuns(read);
 // 同一Run刚结束时列表可能仍显示旧状态；以该Run的真实终态响应为准。
 if(completedRun){const index=rows.findIndex(row=>row.id===completedRun.id);if(index<0)rows.push(completedRun);else rows[index]=completedRun;}
 const keep=retainedRuns(rows),deleted=[];
 for(const row of rows)if(row.status==='completed'&&!keep.has(row.id)){await remove(row.id);deleted.push(row.id);}
 const remaining=await workflowRuns(read),expected=retainedRuns(remaining);
 if(remaining.some(row=>row.status==='completed'&&!expected.has(row.id)))throw Error('SDK旧Run删除尚未确认');
 const latest=[...remaining].filter(row=>row.status==='completed').sort((a,b)=>Date.parse(b.updated_at)-Date.parse(a.updated_at)||b.id-a.id)[0];
 line(report,'SDK记录清理完成：保留最新成功、最新失败及活动任务；已删除 '+deleted.length+' 条旧Run');
 return {runID:latest?.id,deleted,kept:[...expected]};
}
export async function automate({token,fetchImpl=fetch,read=path=>request(token,path,{fetchImpl}),dispatch=spec=>request(token,'actions/workflows/'+spec.workflow+'/dispatches',{method:'POST',body:{ref:spec.ref,inputs:spec.inputs},fetchImpl}),remove,report=reportEvent,interval=3000}={}){
 const rows=await workflowRuns(read),receipt=await dispatch({workflow:'sdk.yml',ref:'main',inputs:{version:nextVersion(rows)}}),runID=receipt.workflow_run_id;
 emit(report,{event:'started',repository,runID});
 let run;
 for(;;){
  run=await read('actions/runs/'+runID);emit(report,{event:'run',run});
  try{emit(report,{event:'jobs',jobs:await read('actions/runs/'+runID+'/jobs?per_page=100&page=1')});}
  catch{line(report,'GitHub Job读取失败；继续读取原Run的真实状态');}
  if(run.status==='completed')break;
  await new Promise(resolve=>setTimeout(resolve,interval));
 }
 try{await cleanupRuns({token,fetchImpl,read,remove,completedRun:run,report});}
 catch(error){throw Error('SDK记录清理失败：'+error.message);}
 return {runID};
}
// 正常自动化与单独清理共用产品实现；清理入口不派发、不重跑已成功的SDK。
export async function describeAction({flow,platform}){
 if(!['release','cleanup'].includes(flow)||platform!=='sdk')throw Error('本产品尚未声明该流程入口：'+flow+'·'+platform);
 return {repository,launch:flow==='cleanup'?cleanupRuns:automate};
}
