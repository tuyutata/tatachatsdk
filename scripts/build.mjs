#!/usr/bin/env node
// 本仓测试、编译及自动化入口；Workflow交付正式版本，原Run终态后实际清理历史。
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,mkdtempSync,existsSync,readFileSync,writeFileSync,copyFileSync,cpSync,rmSync,realpathSync,lstatSync,readdirSync,rmdirSync} from 'node:fs';
import {join,dirname,resolve,basename,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {homedir} from 'node:os';

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
 if(method==='DELETE'&&response.status===404)return null;
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
// 原Run结束后实际删除旧同类记录；Release/Tag先按本仓已有生产回执确认归属。
export async function cleanupRuns({token,fetchImpl=fetch,read=path=>request(token,path,{fetchImpl}),remove=id=>request(token,'actions/runs/'+id,{method:'DELETE',fetchImpl}),completedRun,report=reportEvent}={}){
 const rows=await workflowRuns(read);
 if(completedRun){const index=rows.findIndex(row=>row.id===completedRun.id);if(index<0)rows.push(completedRun);else rows[index]=completedRun;}
 const keep=retainedRuns(rows),stale=rows.filter(row=>row.status==='completed'&&!keep.has(row.id)),deleted=[],errors=[];
 const absent=async path=>{try{await read(path);return false;}catch(error){if(error.message==='GitHub HTTP 404')return true;throw error;}};
 // 删除旧成功之前，新成功必须已有完整SDK Artifact及正式Release/Tag；失败清理独立进行。
 let releases=[];
 try{for(let page=1;;page++){const values=await read('releases?per_page=100&page='+page);releases.push(...values);if(values.length<100)break;}}
 catch(error){errors.push('Release列表读取失败：'+error.message);}
 const owned=releases.flatMap(release=>{let proof;try{proof=JSON.parse(release.body);}catch{return [];}
  if(proof.product_id!==configuration.product_id||proof.platform!=='sdk'||!Number.isSafeInteger(proof.producer_run_id)||proof.producer_run_id<=0)return [];
  if(release.tag_name!==sdkName(proof.software_version)||release.target_commitish!==proof.git_commit_sha)return [];
  return [{release,proof}];});
 let successReady=true;
 if(stale.some(row=>row.conclusion==='success')){
  try{
   const success=rows.filter(row=>row.status==='completed'&&row.conclusion==='success'&&keep.has(row.id))[0];
   const release=owned.find(value=>value.proof.producer_run_id===success.id)?.release;
   if(!release||release.draft||release.prerelease||release.assets?.length!==3)throw Error('新正式Release或附件不完整');
   const artifacts=await read('actions/runs/'+success.id+'/artifacts?per_page=100');
   if(artifacts.artifacts?.filter(value=>value.name===success.display_title&&!value.expired&&value.size_in_bytes>0).length!==1)throw Error('新完整SDK Artifact缺失');
   const tag=await read('git/ref/tags/'+encodeURIComponent(release.tag_name));
   if(tag.object?.type!=='commit'||tag.object.sha!==success.head_sha)throw Error('新正式Tag未确认');
  }catch(error){successReady=false;errors.push('旧成功清理未执行：'+error.message);}
 }
 // 先归还旧发布资产再删Run；某项失败仍清理其它旧失败，不用重跑业务来重试删除。
 for(const {release,proof}of owned){
  if(keep.has(proof.producer_run_id))continue;
  const row=rows.find(value=>value.id===proof.producer_run_id);
  if(row&&row.status!=='completed'||(!row||row.conclusion==='success')&&!successReady)continue;
  try{const current=await read('actions/runs/'+proof.producer_run_id);if(current.status!=='completed')continue;}catch(error){if(error.message!=='GitHub HTTP 404'){errors.push('旧版本Run读取失败：'+error.message);continue;}}
  try{
   const tagPath='git/ref/tags/'+encodeURIComponent(release.tag_name);
   if(!await absent(tagPath)){const currentTag=await read(tagPath);if(currentTag.object?.type!=='commit'||currentTag.object.sha!==proof.git_commit_sha)throw Error('旧Tag归属已变化');}
   await request(token,'releases/'+release.id,{method:'DELETE',fetchImpl});
   const tag='git/refs/tags/'+encodeURIComponent(release.tag_name);
   if(!await absent('git/ref/tags/'+encodeURIComponent(release.tag_name)))await request(token,tag,{method:'DELETE',fetchImpl});
   if(!await absent('releases/'+release.id)||!await absent('git/ref/tags/'+encodeURIComponent(release.tag_name)))throw Error('旧Release或Tag删除尚未确认');
  }catch(error){errors.push('旧发布资产删除失败：'+error.message);}
 }
 for(const row of stale){
  if(row.conclusion==='success'&&!successReady)continue;
  try{const current=await read('actions/runs/'+row.id);if(current.status!=='completed')continue;await remove(row.id);if(!await absent('actions/runs/'+row.id))throw Error('旧Run删除尚未确认');deleted.push(row.id);}
  catch(error){if(error.message!=='GitHub HTTP 404')errors.push('旧Run删除失败：'+error.message);}
 }
 const remaining=await workflowRuns(read),expected=retainedRuns(remaining);
 if(remaining.some(row=>row.status==='completed'&&!expected.has(row.id)))errors.push('SDK旧Run删除尚未确认');
 if(errors.length)throw Error(errors.join('；'));
 line(report,'SDK记录清理完成：最新成功、最新失败各最多一条；旧Run、日志和对应Artifact实际删除 '+deleted.length+' 条');
 return {completed:true,deleted,kept:[...expected]};
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

export const root=resolve(fileURLToPath(new URL('../',import.meta.url)));
import {manifest as configuration,tools,repository} from './config.mjs';
const manifest=join(root,'native/Cargo.toml');
export function testRoot(){const base=join(root,'target/test');mkdirSync(base,{recursive:true});return base;}
function taskDirectory(kind){const base=join(root,'target',kind);mkdirSync(base,{recursive:true});if(realpathSync(base)!==base)throw Error('本轮目录经过链接');return mkdtempSync(join(base,'sdk-'));}
// 原子领取缓存，不等待其它任务；占用或不可写即使用本轮独立目录。
export function claimCache(work){
 const base=join(root,'target/cache'),lock=join(base,'lock');let claimed=false;
 try{mkdirSync(base,{recursive:true});if(realpathSync(base)!==base)throw Error('缓存经过链接');mkdirSync(lock);claimed=true;
  const cargo=join(base,'rust');mkdirSync(cargo,{recursive:true});if(realpathSync(cargo)!==cargo)throw Error('缓存经过链接');
  return {cargo,pub:join(base,'pub'),release(){try{rmdirSync(lock);}catch{}}};
 }catch{if(claimed)try{rmdirSync(lock);}catch{}return {cargo:join(work,'rust'),pub:join(work,'pub'),release(){}};}
}
const controller=new AbortController();
async function run(command,args,{cwd=root,env={},capture=false,signal=controller.signal}={}){
 signal.throwIfAborted();return new Promise((ok,fail)=>{
  const environment={...process.env,...env};delete environment.GH_TOKEN;delete environment.GITHUB_TOKEN;
  const child=spawn(command,args,{cwd,env:environment,detached:true,stdio:['ignore',capture?'pipe':process.stderr,'pipe']});
  let text='',diagnostic='',failure,timer;
  const cancel=()=>{try{process.kill(-child.pid,'SIGTERM');}catch{}timer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch{}},2000);timer.unref?.();};
  signal.addEventListener('abort',cancel,{once:true});
  child.stdout?.on('data',chunk=>{text+=chunk;if(text.length>8*1024**2){failure=Error('工具结果超限');cancel();}});
  child.stderr.on('data',chunk=>{process.stderr.write(chunk);diagnostic=(diagnostic+chunk).slice(-4000);});
  child.once('error',error=>{failure=error;});child.once('close',async(code,termination)=>{
   signal.removeEventListener('abort',cancel);
   if(signal.aborted&&child.pid){
    // 进程组确认退出后才能清理；主进程先退出不能取消对子进程的强制终止。
    await new Promise(resolve=>setTimeout(resolve,2000));try{process.kill(-child.pid,'SIGKILL');}catch{}
    let alive=true;for(let i=0;i<100&&alive;i++){try{process.kill(-child.pid,0);await new Promise(resolve=>setTimeout(resolve,100));}catch(error){if(error.code==='ESRCH')alive=false;else break;}}
    if(alive){if(timer)clearTimeout(timer);const error=Error('SDK子进程组退出未确认，保留本轮现场');error.keepWork=true;return fail(error);}
   }
   if(timer)clearTimeout(timer);
   if(failure||code!==0||termination||signal.aborted)return fail(failure||Error(`${basename(command)}执行失败（${code??termination}）：${diagnostic.slice(-1000)}`));
   ok(text.trim());
  });
 });
}
function buildEnvironment(work,cache){
 return {RUSTUP_TOOLCHAIN:tools.rust,CARGO_TARGET_DIR:cache.cargo,CARGO_INCREMENTAL:'1',TMPDIR:join(work,'tmp')+sep,
  PUB_CACHE:process.env.PUB_CACHE||cache.pub,FLUTTER_SUPPRESS_ANALYTICS:'true'};
}
function flutterExecutable(){const base=process.env.FLUTTER_ROOT||join(root,'target/cache/flutter');return join(base,'bin/flutter');}
async function flutterCheck(env){
 const executable=flutterExecutable();if(!existsSync(executable))throw Error('缺少Flutter '+tools.flutter+'；请交付官方SDK并设置FLUTTER_ROOT');
 // 首次启动先完成官方下载与工具初始化，避免下载进度污染机器格式JSON。
 await run(executable,['--version'],{env});
 const version=JSON.parse(await run(executable,['--version','--machine'],{env,capture:true}));
 if(version.frameworkVersion!==tools.flutter)throw Error('Flutter版本与本产品声明不一致');return executable;
}
const analysisOptions='include: package:flutter_lints/flutter.yaml\nanalyzer:\n  exclude:\n    - lib/storage/chat_isar.g.dart\n    - build/**\n    - android/**\n    - ios/**\n  language:\n    strict-casts: true\n    strict-inference: true\n    strict-raw-types: true\nlinter:\n  rules:\n    - avoid_print\n    - directives_ordering\n    - unawaited_futures\n    - use_super_parameters\n';
export function analysisOptionsBytes(){return Buffer.from(analysisOptions);}
const layout=[['android/TataChatSdkPlugin.java','android/src/main/java/chat/tata/sdk/TataChatSdkPlugin.java'],['android/AndroidManifest.xml','android/src/main/AndroidManifest.xml']];
function platformInput(source,flat,standard){
 const found=[flat,standard].filter(path=>existsSync(join(source,path)));if(found.length!==1)throw Error('SDK平台输入缺失或重复');return found[0];
}
// 现有消费产品仍调用这个真实公开接口；只装配Flutter要求的布局，不复制另一套SDK实现。
export function createFlutterSourceView(source,output){
 if(realpathSync(source)!==source||resolve(output)!==output||source===output||output.startsWith(source+sep)&&!output.startsWith(join(source,'target')+sep))throw Error('SDK工程目录无效');
 if(existsSync(output))throw Error('SDK工程目标已存在');mkdirSync(output,{recursive:true});
 for(const name of ['lib','test','native','ios','android','stickers','scripts','pubspec.yaml','pubspec.lock','README.md','LICENSE']){
  if(!existsSync(join(source,name))&&name==='test')continue;
  cpSync(join(source,name),join(output,name),{recursive:true,filter:path=>!['target','.git','.dart_tool','build','.gradle'].includes(basename(path))});
 }
 for(const [flat,to]of layout){const from=platformInput(source,flat,to);if(from===to)continue;mkdirSync(dirname(join(output,to)),{recursive:true});copyFileSync(join(output,from),join(output,to));rmSync(join(output,from));}
 writeFileSync(join(output,'analysis_options.yaml'),analysisOptionsBytes());return output;
}
export function assertFlutterSourceView(source,output){
 if(realpathSync(source)!==source||realpathSync(output)!==output||source===output)throw Error('SDK工程目录无效');
 for(const [flat,to]of layout){const from=platformInput(source,flat,to);if(existsSync(join(output,flat))||!readFileSync(join(source,from)).equals(readFileSync(join(output,to))))throw Error('SDK Flutter布局与本仓输入不一致');}
 for(const name of ['pubspec.yaml','pubspec.lock','native/tatachat_sdk.h'])if(!readFileSync(join(source,name)).equals(readFileSync(join(output,name))))throw Error('SDK工程声明漂移');
 if(!readFileSync(join(output,'analysis_options.yaml')).equals(analysisOptionsBytes()))throw Error('SDK分析配置漂移');return output;
}
export function sourceView(work){return createFlutterSourceView(root,join(work,'project'));}
async function ensureTarget(target,env){await run('rustup',['target','add','--toolchain',tools.rust,target],{env});}
export async function verifyNative(file,target,runTool=run){
 const android=target==='android';
 const ndk=process.env.ANDROID_NDK_HOME||process.env.ANDROID_NDK_ROOT||join(process.env.ANDROID_HOME||join(homedir(),'Library/Android/sdk'),'ndk',tools.ndk);
 const llvm=join(ndk,'toolchains/llvm/prebuilt',process.platform==='darwin'?'darwin-x86_64':'linux-x86_64','bin');
 const nm=android?join(llvm,'llvm-nm'):'/usr/bin/xcrun';
 const args=android?['-D','--defined-only',file]:['nm','-gU',file];
 const symbols=await runTool(nm,args,{capture:true});
 const expected=[...readFileSync(join(root,'native/tatachat_sdk.h'),'utf8').matchAll(/\b(tatachat_sdk_[a-z_]+)\s*\(/gu)].map(match=>match[1]);
 for(const name of expected)if(!new RegExp('(?:^|\\s)_?'+name+'(?:\\s|$)','mu').test(symbols))throw Error('SDK原生件缺少符号：'+name);
 if(/tatachat_sdk_(?:mls_rekey_state|mls_two_party_smoke|device_identity|mls_encrypt|mls_decrypt)_json/u.test(symbols))throw Error('SDK原生件包含已撤销接口');
 const architecture=await runTool('/usr/bin/file',['-b',file],{capture:true});
 if(android?!/ELF 64-bit.*(?:ARM aarch64|aarch64)/u.test(architecture):!/Mach-O 64-bit.*arm64/u.test(architecture))throw Error('SDK原生件架构不符');
 if(!android){const build=await runTool('/usr/bin/xcrun',['vtool','-show-build',file],{capture:true});
  const platform=target==='macos'?'MACOS':target==='ios-simulator'?'IOSSIMULATOR':'IOS';
  if(!new RegExp('platform\\s+'+platform+'(?:\\s|$)','u').test(build))throw Error('SDK原生件系统目标不符');
  const commands=await runTool('/usr/bin/xcrun',['otool','-l',file],{capture:true}),offset=/cmd LC_SYMTAB[\s\S]*?\bstroff\s+(\d+)/u.exec(commands)?.[1];
  if(!offset||BigInt(offset)%8n!==0n)throw Error('SDK Mach-O字符串表未按8字节对齐');
  const identity=await runTool('/usr/bin/xcrun',['otool','-D',file],{capture:true});
  if(!identity.split('\n').map(value=>value.trim()).includes(target==='macos'?'@rpath/libtatachat_sdk.dylib':'@rpath/TataChatSDK.framework/TataChatSDK'))throw Error('SDK动态库装载名称不符');}
}
async function nativeTarget(target,work,env,version){
 const output=join(work,'native',target);mkdirSync(output,{recursive:true});
 const cargoArgs=['build','--release','--locked','--manifest-path',manifest];
 if(target==='android'){
  const ndk=process.env.ANDROID_NDK_HOME||process.env.ANDROID_NDK_ROOT||join(process.env.ANDROID_HOME||join(homedir(),'Library/Android/sdk'),'ndk',tools.ndk);
  if(!readFileSync(join(ndk,'source.properties'),'utf8').includes('Pkg.Revision = '+tools.ndk))throw Error('Android NDK版本不符');
  const base=join(ndk,'toolchains/llvm/prebuilt',process.platform==='darwin'?'darwin-x86_64':'linux-x86_64','bin');
  const target='aarch64-linux-android';await ensureTarget(target,env);
  await run('cargo',[...cargoArgs,'--target',target],{env:{...env,CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER:join(base,'aarch64-linux-android24-clang'),CC_aarch64_linux_android:join(base,'aarch64-linux-android24-clang'),AR_aarch64_linux_android:join(base,'llvm-ar')}});
  mkdirSync(join(output,'arm64-v8a'));const file=join(output,'arm64-v8a/libtatachat_sdk.so');copyFileSync(join(env.CARGO_TARGET_DIR,target,'release/libtatachat_sdk.so'),file);await verifyNative(file,'android');
 }else if(target==='macos'){
  const triple='aarch64-apple-darwin';await ensureTarget(triple,env);
  await run('cargo',[...cargoArgs,'--target',triple],{env:{...env,CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS:'-C strip=none -C link-arg=-Wl,-install_name,@rpath/libtatachat_sdk.dylib'}});
  const file=join(output,'libtatachat_sdk.dylib');copyFileSync(join(env.CARGO_TARGET_DIR,triple,'release/libtatachat_sdk.dylib'),file);await verifyNative(file,'macos');
 }else if(target==='ios'){
  const frameworks=[];
  for(const [triple,sdk,key]of [['aarch64-apple-ios','iphoneos','CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS'],['aarch64-apple-ios-sim','iphonesimulator','CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS']]){
   await ensureTarget(triple,env);const sdkPath=await run('/usr/bin/xcrun',['--sdk',sdk,'--show-sdk-path'],{capture:true});
   await run('cargo',[...cargoArgs,'--target',triple],{env:{...env,IPHONEOS_DEPLOYMENT_TARGET:'16.0',[key]:`-C strip=none -C link-arg=-isysroot -C link-arg=${sdkPath} -C link-arg=-Wl,-install_name,@rpath/TataChatSDK.framework/TataChatSDK`}});
   const framework=join(output,triple,'TataChatSDK.framework');mkdirSync(join(framework,'Headers'),{recursive:true});mkdirSync(join(framework,'Modules'));
   copyFileSync(join(env.CARGO_TARGET_DIR,triple,'release/libtatachat_sdk.dylib'),join(framework,'TataChatSDK'));copyFileSync(join(root,'native/tatachat_sdk.h'),join(framework,'Headers/tatachat_sdk.h'));
   writeFileSync(join(framework,'Modules/module.modulemap'),'framework module TataChatSDK {\n  umbrella header "tatachat_sdk.h"\n  export *\n}\n');
   writeFileSync(join(framework,'Info.plist'),`<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>TataChatSDK</string><key>CFBundleIdentifier</key><string>org.cocoapods.TataChatSDK</string><key>CFBundleName</key><string>TataChatSDK</string><key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleShortVersionString</key><string>${version}</string><key>CFBundleVersion</key><string>${version}</string><key>MinimumOSVersion</key><string>16.0</string></dict></plist>`);
   await verifyNative(join(framework,'TataChatSDK'),sdk==='iphoneos'?'ios':'ios-simulator');frameworks.push('-framework',framework);
  }
  await run('/usr/bin/xcodebuild',['-create-xcframework',...frameworks,'-output',join(output,'TataChatSDK.xcframework')]);
 }else throw Error('不支持的内部编译目标');
 return output;
}
export async function testSDK(){
 const work=taskDirectory('test'),cache=claimCache(work);mkdirSync(join(work,'tmp'));
 const env=buildEnvironment(work,cache);let safe=true;
 try{
  const flutter=await flutterCheck(env),project=sourceView(work);
  await run('cargo',['test','--locked','--manifest-path',manifest],{env});
  const output=await nativeTarget('macos',work,env,'1.0.0');
  await run(flutter,['pub','get','--enforce-lockfile'],{cwd:project,env});
  const config=JSON.parse(readFileSync(join(project,'.dart_tool/package_config.json'),'utf8'));
  const entry=config.packages.find(value=>value.name==='isar_community_flutter_libs');if(!entry)throw Error('Pub原锁缺少Isar原生包');
  const packageRoot=fileURLToPath(new URL(entry.rootUri,new URL('file://'+join(project,'.dart_tool/package_config.json'))));
  const isar=join(work,'libisar.dylib');copyFileSync(join(packageRoot,'macos/libisar.dylib'),isar);
  const testEnv={...env,FLUTTER_TEST:'true',TATACHATSDK_TEST_WORK_ROOT:work,TATACHATSDK_TEST_NATIVE_LIBRARY:join(output,'libtatachat_sdk.dylib'),ISAR_CORE_LIB_PATH:isar};
  await run(flutter,['analyze','--fatal-infos'],{cwd:project,env:testEnv});
  await run(flutter,['test','--concurrency=1','--reporter=expanded'],{cwd:project,env:testEnv});
 }catch(error){safe=!error.keepWork;throw error;}finally{if(safe){cache.release();rmSync(work,{recursive:true,force:true});}}
}
export function setPackageVersion(project,version){
 sdkName(version);
 for(const [file,pattern,text]of [
  ['pubspec.yaml',/^version: .+$/mu,'version: '+version],
  ['ios/tatachat_sdk.podspec',/spec\.version = '[^']*'/u,"spec.version = '"+version+"'"],
  ['android/build.gradle.kts',/^version = "[^"]*"$/mu,'version = "'+version+'"'],
 ]){const path=join(project,file),before=readFileSync(path,'utf8');if(!pattern.test(before))throw Error('SDK版本声明缺失：'+file);writeFileSync(path,before.replace(pattern,text));}
}
export async function buildSDK({target,version=process.env.SDK_VERSION||/^version: (\S+)$/mu.exec(readFileSync(join(root,'pubspec.yaml'),'utf8'))?.[1]}={}){
 sdkName(version);const work=taskDirectory('build'),cache=claimCache(work);mkdirSync(join(work,'tmp'));let completed=false,safe=true;
 try{
  const env=buildEnvironment(work,cache);for(const value of target?[target]:['android','ios','macos'])await nativeTarget(value,work,env,version);
  if(target){completed=true;return {work,output:join(work,'native',target)};}
  const project=sourceView(work);
  rmSync(join(project,'ios/TataChatSDK.xcframework'),{recursive:true,force:true});
  cpSync(join(work,'native/ios/TataChatSDK.xcframework'),join(project,'ios/TataChatSDK.xcframework'),{recursive:true});
  cpSync(join(work,'native/android'),join(project,'android/src/main/jniLibs'),{recursive:true});
  copyFileSync(join(work,'native/macos/libtatachat_sdk.dylib'),join(project,'native/libtatachat_sdk.dylib'));
  setPackageVersion(project,version);
  for(const entry of readdirSync(work))if(entry!=='project')rmSync(join(work,entry),{recursive:true,force:true});
  completed=true;return {work,output:project};
 }catch(error){safe=!error.keepWork;throw error;}finally{if(safe){cache.release();if(!completed)rmSync(work,{recursive:true,force:true});}}
}
export async function protocol(){
 const protoc=process.env.PROTOC,plugin=process.env.PROTOC_GEN_DART;
 if(!protoc?.startsWith('/')||!plugin?.startsWith('/'))throw Error('协议生成须显式提供官方protoc及Dart插件绝对路径');
 if(await run(protoc,['--version'],{capture:true})!=='libprotoc '+tools.protoc)throw Error('protoc版本不符');
 const work=taskDirectory('build'),output=join(work,'protocol');mkdirSync(output);
 try{await run(protoc,['--proto_path='+join(root,'lib/protocol'),'--dart_out='+output,'--plugin=protoc-gen-dart='+plugin,...['basic_content','media_content','message','attachment','chat_frame'].map(name=>join(root,'lib/protocol',name+'.proto'))]);return {work,output};}
 catch(error){if(!error.keepWork)rmSync(work,{recursive:true,force:true});throw error;}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)&&!process.env.NODE_TEST_CONTEXT){
 for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>controller.abort());
 try{
  const [command,...args]=process.argv.slice(2);
  if(process.versions.node!==tools.node)throw Error('Node版本与本产品声明不一致');
  if(command==='automate')await automate({token:process.env.GH_TOKEN||process.env.GITHUB_TOKEN});
  else if(command==='cleanup')console.log(JSON.stringify(await cleanupRuns({token:process.env.GH_TOKEN||process.env.GITHUB_TOKEN})));
  else if(command==='test')await testSDK();
  else if(command==='protocol')console.log(JSON.stringify(await protocol()));
  else if(command==='native'&&args.length===1)console.log(JSON.stringify(await buildSDK({target:args[0]})));
  else if(!command){const result=await buildSDK();console.log(JSON.stringify(result));}
  else throw Error('用法：node scripts/build.mjs [test|native android/ios/macos|protocol|automate|cleanup]');
 }catch(error){console.error(error.message);process.exitCode=1;}
}
