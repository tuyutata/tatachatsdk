// 每个workspace包只发现并运行自己的测试；辅助文件不登记为用例。
import {readdirSync,statSync} from 'node:fs';
import {join,resolve,relative} from 'node:path';

export function discoverTests(packages){
 const seen=new Set();
 return packages.map(item=>{
  const files=[];
  function visit(folder){
   for(const entry of readdirSync(folder,{withFileTypes:true})){
    const file=join(folder,entry.name);
    if(entry.isSymbolicLink())throw Error('测试目录不允许链接');
    if(entry.isDirectory())visit(file);
    else if(entry.isFile()&&entry.name.endsWith('_test.dart')){
     const path=resolve(file);if(seen.has(path))throw Error('测试重复发现');seen.add(path);files.push(path);
    }
   }
  }
  const folder=item.testPath||join(item.path,item.name==='tatachat_sdk'?'lib/test':'test');
  if(statSync(folder,{throwIfNoEntry:false})?.isDirectory())visit(folder);
  if(files.length===0)throw Error('包缺少真实测试：'+item.name);
  return {...item,files:files.sort()};
 });
}

export function verifyReport(text,files,cwd){
 const rows=text.trim().split('\n').filter(Boolean).map(line=>JSON.parse(line));
 const suites=new Map(rows.filter(row=>row.type==='suite').map(row=>[row.suite.id,resolve(cwd,row.suite.path)]));
 const loaded=new Set(suites.values());
 if(files.some(file=>!loaded.has(resolve(file)))||[...loaded].some(file=>!files.includes(file)))throw Error('测试文件加载不完整或越界');
 const tests=new Map(rows.filter(row=>row.type==='testStart').map(row=>[row.test.id,row.test]));
 const started=rows.filter(row=>row.type==='testStart').map(row=>row.test.id);
 const ended=rows.filter(row=>row.type==='testDone');
 if(new Set(started).size!==started.length||new Set(ended.map(row=>row.testID)).size!==ended.length||started.length!==ended.length||started.some(id=>!ended.some(row=>row.testID===id)))throw Error('测试结束事件不完整或重复');
 for(const suite of suites.keys())if(!ended.some(row=>!row.hidden&&tests.get(row.testID)?.suiteID===suite))throw Error('测试文件没有实际用例');
 if(rows.some(row=>row.type==='error')||ended.some(row=>row.result!=='success'||row.skipped)||rows.filter(row=>row.type==='done').length!==1||!rows.some(row=>row.type==='done'&&row.success===true))throw Error('测试失败、跳过或未正常结束');
 return {files:files.length,passed:ended.filter(row=>!row.hidden).length,ended:ended.length};
}

export async function runWorkspaceTests({project,flutter,env,run,packages}){
 const groups=discoverTests(packages);let passed=0,files=0,ended=0;
 for(const item of groups){
  let output;
  try{output=await run(flutter,['test','--no-pub','--concurrency=1','--reporter=json',...item.files.map(file=>relative(item.path,file))],{cwd:item.path,env,capture:true});}
  catch(error){
   for(const line of (error.testOutput||'').split('\n')){try{const row=JSON.parse(line);if(row.type==='error')process.stderr.write(item.name+': '+String(row.error).slice(0,700)+'\n');}catch{}}
   throw error;
  }
  const result=verifyReport(output,item.files,item.path);passed+=result.passed;files+=result.files;ended+=result.ended;
  process.stderr.write(JSON.stringify({package:item.name,...result})+'\n');
 }
 process.stderr.write(JSON.stringify({workspace:groups.length,files,passed,ended,failed:0,skipped:0})+'\n');
}
