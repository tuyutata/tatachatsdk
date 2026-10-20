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

// 本仓流程的公开入口声明；调用方只交付标准传输能力，不拥有产品规则或任务宿主。
export async function describeAction({flow,platform}){
 if(flow!=='release'||platform!=='sdk')throw Error('本产品尚未声明该流程入口：'+flow+'·'+platform);
 return {repository,launch:async({read,dispatch})=>{
  const rows=[];
  for(let page=1;;page++){const data=await read('actions/workflows/sdk.yml/runs?branch=main&event=workflow_dispatch&per_page=100&page='+page);rows.push(...data.workflow_runs);if(data.workflow_runs.length<100)break;}
  const receipt=await dispatch({workflow:'sdk.yml',ref:'main',inputs:{version:nextVersion(rows)}});
  return {runID:receipt.workflow_run_id};
 }};
}
