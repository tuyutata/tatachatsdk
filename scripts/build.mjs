#!/usr/bin/env node
// 本产品独立拥有资源需求、工程准备与编译；公开回执仅提供验真资源，不提供执行命令。
import {spawn} from 'node:child_process';
import {checkFixedWork,clearFixedWork,fixedWork,withFixedWork,taskScope,trackWorkProcess,workEnvironment} from './target.mjs';
import {AsyncLocalStorage} from 'node:async_hooks';
import {rmSync,constants as fsConstants,chmodSync,closeSync,openSync,readlinkSync,unlinkSync,copyFileSync,existsSync,lstatSync,mkdirSync,readFileSync,readdirSync,realpathSync,symlinkSync,writeFileSync} from 'node:fs';
import {dirname,isAbsolute,join,parse,relative,resolve,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
export const contract=JSON.parse(readFileSync(join(root,'scripts/flows.json'),'utf8'));
const product=contract.product_id, prefix=product.toUpperCase();
const inside=(base,path)=>{const r=relative(base,path);return r===''||!isAbsolute(r)&&r!=='..'&&!r.startsWith('..'+sep);};
const fail=message=>{throw Error(product+' Build：'+message);};
export function checkWork(work) { return checkFixedWork(work); }

// 产品自己拥有target工作边界；测试与独立入口也不借用调用方的全局缓存。
export function productTarget(platform) {
 platformContract(platform);
 return join(root,'target');
}
export function temporaryRoot(platform=Object.keys(contract.platforms)[0],scope='test',suppliedInput) {
 if(!['test','tmp','build','ci','release','publish'].includes(scope))fail('临时目录职责无效');
 platformContract(platform);const expected=fixedWork(scope==='test'?'test':'build');
 if(suppliedInput!=null&&suppliedInput!==expected)fail('临时工作根必须是本产品固定目录');
 return checkFixedWork(expected,{create:true});
}
// 测试继承当前平台现场；独立执行没有任务身份时才选产品首个平台。
export const testRoot=platform=>{
 const workflow=String(process.env.GITHUB_WORKFLOW||'').split('.');
 const local=process.env.TMPDIR?relative(join(root,'target'),resolve(process.env.TMPDIR)).split(sep)[0]:undefined;
 const inherited=workflow[0]===product&&Object.hasOwn(contract.platforms,workflow[1])?workflow[1]
  :Object.hasOwn(contract.platforms,local)?local:undefined;
 return temporaryRoot(platform||inherited||Object.keys(contract.platforms)[0],'test');
};
// 远端Runner基础设施仍归GitHub；本产品步骤的可写临时目录归准确平台流程target。
export function remoteEnvironment(environment=process.env) {
 const [id,platform,flow,...extra]=String(environment.GITHUB_WORKFLOW||'').split('.');
 if(id!==product||extra.length||!Object.hasOwn(contract.platforms,platform)||!['ci','release'].includes(flow))fail('远端临时目录缺少准确产品平台流程身份');
 const temporary=temporaryRoot(platform,flow,null);
 return {...environment,RUNNER_TEMP:temporary,TMPDIR:temporary,TMP:temporary,TEMP:temporary};
}

// 展开来源根由本产品指定，调用者不识别任何产品来源名称。
export function resourceSourceRoot(name,work){checkWork(work);if(!/^[a-z][a-z0-9_]*$/u.test(name))fail('来源名称无效');return join(work,'git-sources',name);}
// 清理只针对当前执行拥有的工作根；工具全部退出后删除并回读，固定根本身保留。
export function clearWork(work) { return clearFixedWork(work); }

export function platformContract(platform) {
 if(!Object.hasOwn(contract.platforms,platform))fail('平台未声明');
 return contract.platforms[platform];
}
const sourceRoot=()=>root;
const nativePlatform=platform=>platform.endsWith('android')?'Android':platform.includes('linux-arm')?'LinuxARM':platform.includes('linux-amd')?'LinuxAMD':platform.endsWith('windows')?'Windows':'macOS';
const osPlatform=platform=>platform.includes('linux-')?'linux':platform.replace(/^(?:host|client)-/u,'');

// 只读声明与原始锁；每个第一方Git来源必须同时匹配固定URL、40位提交和resolved-ref。
export function lockedSources() {
 const source=sourceRoot(),path=join(source,'pubspec.yaml');if(!existsSync(path))return [];
 const manifest=readFileSync(path,'utf8'),lock=readFileSync(join(source,'pubspec.lock'),'utf8'),result=[];
 for(const name of ['citizen_sdk','tatachat_sdk']) {
  const block=text=>[...text.matchAll(new RegExp('^  '+name+':\\r?\\n(?: {4,}[^\\n]*\\n|[ \\t]*\\n)+','gm'))];
  const a=block(manifest),b=block(lock);if(!a.length)continue;
  if(a.length!==1||b.length!==1)fail('Git来源记录不唯一');
  const value=(text,key)=>{const m=[...text.matchAll(new RegExp('^ +'+key+':\\s*([^\\n]+)$','gm'))];if(m.length!==1)fail('Git来源字段不唯一');return m[0][1].trim().replace(/^["']|["']$/gu,'');};
  const url=value(a[0][0],'url'),ref=value(a[0][0],'ref');
  if(!/^https:\/\/github\.com\/[a-z0-9-]+\/[a-z0-9-]+\.git$/u.test(url)||!/^[a-f0-9]{40}$/u.test(ref)
   ||value(a[0][0],'path')!=='.'||value(b[0][0],'url')!==url||value(b[0][0],'resolved-ref')!==ref||value(b[0][0],'ref')!==ref)fail('Git声明和锁不一致');
  result.push({name,url,ref});
 }return result;
}
export function requirements(platform,work) {
 checkWork(work);const declared=platformContract(platform);
 const locks=declared.locks.map(value=>({...value})),sources=lockedSources(),archives=[];
 for(const source of sources) {
  const packageRoot=join(work,'git-sources',source.name);
  if(existsSync(packageRoot)) {
   const path=source.name==='citizen_sdk'?'Cargo.lock':'native/Cargo.lock';
   locks.push({ecosystem:'cargo',path,source_package:source.name});
   if(source.name==='citizen_sdk') {
    const lock=JSON.parse(readFileSync(join(packageRoot,'scripts/dependencies.lock.json'),'utf8'));
    const p=nativePlatform(platform);
    const entries=[['zxing-cpp',lock.environment['zxing-cpp']],...((p==='LinuxARM'||p==='LinuxAMD')?Object.entries(lock.native.sources):p==='Windows'?[['sqlite',lock.native.sources.sqlite]]:[])];
    for(const [name,value]of entries)archives.push({ecosystem:'native',name,...value,group:'sdk-native'});
   }
  }
 }
 // 原生源归档坐标归本产品已有声明；准备后才提出展开源码的Cargo锁。
 for(const lock of declared.locks){const file=join(root,lock.path);if(!existsSync(file)||!lstatSync(file).isFile()||lstatSync(file).isSymbolicLink())fail('原始锁缺失或带链接：'+lock.path);}
 return {schema:1,product_id:product,platform,tools:declared.tools,locks,sources,archives};
}

export function resourceEnvironment(platform,work,receipt,base={}) {
 checkWork(work);const declared=platformContract(platform);
 if(!receipt||receipt.schema!==1||receipt.product_id!==product||receipt.platform!==platform||receipt.work!==work||receipt.offline!==true
  ||!receipt.tools||!receipt.dependencies||!receipt.archives)fail('资源回执身份无效');
 const env={HOME:base.HOME,USER:base.USER,LOGNAME:base.LOGNAME,LANG:'zh_CN.UTF-8',LC_ALL:'C',
  ...receipt.environment,TMPDIR:join(work,'tmp')+sep,TMP:join(work,'tmp'),TEMP:join(work,'tmp'),XDG_CACHE_HOME:join(work,'cache'),XDG_CONFIG_HOME:join(work,'config'),
  CARGO_TARGET_DIR:join(work,'work/cargo-target'),CARGO_NET_OFFLINE:'true',CARGO_INCREMENTAL:'1',
  npm_config_offline:'true',npm_config_audit:'false',npm_config_fund:'false'};
 const allowedEnvironment=new Set(['PRODUCT_WORK_DIR','PRODUCT_BASH_BIN','PRODUCT_RSYNC_BIN','PATH','DEVELOPER_DIR','SDKROOT','DART_EXECUTABLE','XCODEBUILD','CODESIGN','SECURITY','XCRUN','XCODE_SELECT','CC','CXX','SWIFT','OTOOL','INSTALL_NAME_TOOL','LIPO','MAKE','AR','RANLIB','NM','STRIP','LLVM_NM','LD','LDCXX','CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER','ANDROID_HOME','ANDROID_SDK_ROOT','ANDROID_NDK_HOME','ANDROID_USER_HOME','ANDROID_EMULATOR_HOME','GRADLE_INIT_SCRIPT','GRADLE_USER_HOME']);
 if(Object.keys(receipt.environment||{}).some(key=>!allowedEnvironment.has(key)))fail('资源回执包含未声明环境或注入变量');
 for(const tool of declared.tools) {
  const value=receipt.tools[tool.id];
  if(!value||typeof value.path!=='string'||!isAbsolute(value.path)||resolve(value.path)!==value.path)fail('缺少准确版本的工具：'+tool.id);
  const s=lstatSync(value.path);if(!s.isFile()||!(s.mode&0o111))fail('工具入口必须是普通执行器：'+tool.id);
 }
 const aliases={node:'NODE',git:'GIT',flutter:'FLUTTER',rust:'RUSTC',python:'PYTHON',java:'JAVA',gradle:'GRADLE',
  cmake:'CMAKE',cocoapods:'POD',protoc:'PROTOC',zig:'ZIG','worker-build':'WORKER_BUILD','wasm-bindgen':'WASM_BINDGEN_BIN','wasm-opt':'WASM_OPT_BIN',esbuild:'ESBUILD_BIN',
  perl:'PERL',m4:'M4',bison:'BISON',flex:'FLEX',tcl:'TCLSH',gettext:'GETTEXT',openssl:'OPENSSL'};
 for(const [id,name]of Object.entries(aliases))if(receipt.tools[id])env[name]=receipt.tools[id].path;
 // POSIX旧Shell不进入正式PATH；基础工具只通过产品已验真的GNU投影交付。
 const paths=Object.entries(receipt.tools).filter(([id])=>id!=='posix').map(([,value])=>dirname(value.path));
 env.PATH=[...new Set([...paths,...(env.PATH||'').split(':')].filter(Boolean))].join(':');
 if(env.GIT)env.PRODUCT_GIT_BIN=env.GIT;
 if(env.RUSTC)env.CARGO=join(dirname(env.RUSTC),'cargo');
 if(env.FLUTTER){env.FLUTTER_ROOT=dirname(dirname(env.FLUTTER));env.DART_EXECUTABLE=join(env.FLUTTER_ROOT,'bin/cache/dart-sdk/bin/dart');}
 if(env.PYTHON)env.PYTHONHOME=dirname(dirname(env.PYTHON));
 if(env.JAVA)env.JAVA_HOME=dirname(dirname(env.JAVA));
 if(env.OPENSSL)env.TUYU_OPENSSL_PREFIX=dirname(dirname(env.OPENSSL));
 const own=receipt.dependencies.own||{};
 // 原始锁要求的目录必须显式交付，不能落入用户默认缓存。
 for(const lock of declared.locks){const key={npm:'npmCache',pub:'pubCache',cargo:'cargoHome'}[lock.ecosystem];if(key&&!own[key])fail('缺少原始锁依赖回执：'+lock.ecosystem);}
 for(const [key,name]of [['npmCache','npm_config_cache'],['pubCache','PUB_CACHE'],['cargoHome','CARGO_HOME']])if(own[key]){
  checkDependency(work,own[key]);env[name]=own[key];
 }
 env[prefix+'_WORK_DIR']=work;env[prefix+'_BUILD_WORK_DIR']=join(work,'work');env[prefix+'_DEPENDENCY_DIR']=join(work,'dependencies');
 env[prefix+'_BUILD_DIR']=join(work,'work/flutter');env[prefix+'_ARTIFACT_DIR']=work;env[prefix+'_OFFLINE']='true';
 env.BUILD_DIR=join(work,'work/flutter');env[prefix+'_NODE_BIN']=env.NODE;
 env[prefix+'_PROJECT_ROOT']=join(work,'source-view',sourceRoot().replace(/^\/+/u,''));
 env.PRODUCT_SOURCE_DIR=env[prefix+'_PROJECT_ROOT'];
 if(env.GRADLE)env[prefix+'_GRADLE_BIN']=env.GRADLE;
 env.GRADLE_USER_HOME=join(work,'dependencies/gradle');env.CP_HOME_DIR=join(work,'dependencies/cocoapods');
 env[prefix+'_PUB_OFFLINE']='true';env.GRADLE_OPTS='-Dorg.gradle.project.android.builder.sdkDownload=false';
 if(receipt.archives.native)env.CHATSERVER_NATIVE_ARCHIVE=receipt.archives.native[0].path;
 if(receipt.archives.protocol)env.CHATSERVER_PROTOCOL_ARCHIVE=receipt.archives.protocol[0].path;
 return env;
}
function checkDependency(work,path){if(!isAbsolute(path)||resolve(path)!==path||!inside(work,path)||path===work||!lstatSync(path).isDirectory()||realpathSync(path)!==path)fail('依赖回执越界或无效');}
// 分析配置唯一归本模块；从来源模块读取声明，当前工程独占生成。
export function analysisOptionsBytes(source=root) {
 const input=join(source,'scripts/build.mjs'),info=lstatSync(input,{throwIfNoEntry:false});
 if(!info?.isFile()||info.isSymbolicLink()||realpathSync(input)!==input)fail('分析配置须来自唯一普通源文件');
 const text=readFileSync(input,'utf8'),marker='export const BUILD_SHELL_SOURCES = Object.freeze(',start=text.search(/^export const BUILD_SHELL_SOURCES = Object\.freeze\(/mu);
 if(start<0)fail('分析配置源码声明缺失');
 // JSON只包含字符串；解析第一个完整对象，不执行来源脚本。
 let quoted=false,escaped=false,depth=0,end=-1;
 for(let i=start+marker.length;i<text.length;i++){
  const c=text[i];if(quoted){if(escaped)escaped=false;else if(c==='\\')escaped=true;else if(c==='"')quoted=false;continue;}
  if(c==='"')quoted=true;else if(c==='{')depth++;else if(c==='}'&&!--depth){end=i+1;break;}
 }
 if(end<0)fail('分析配置源码声明不完整');const value=JSON.parse(text.slice(start+marker.length,end));
 if(typeof value.analysis!=='string'||!value.analysis)fail('分析配置源码无效');return Buffer.from(value.analysis);
}
export function materializeAnalysisOptions(source,project) {
 for(const path of [source,project])if(!isAbsolute(path)||resolve(path)!==path||!lstatSync(path).isDirectory()||lstatSync(path).isSymbolicLink()||realpathSync(path)!==path)fail('分析配置工程路径无效');
 if(project===root||project===source)fail('分析配置只允许派生工程');
 if(lstatSync(join(source,'analysis_options.yaml'),{throwIfNoEntry:false}))fail('源码存在重复分析配置');
 const output=join(project,'analysis_options.yaml');writeFileSync(output,analysisOptionsBytes(source),{flag:'wx',mode:0o600});return output;
}
// 工程输入复制到本轮真实目录，保证包解析与写入均不进入正式源码；内部链接映射到同轮副本。
export function createView(source,destination) {
 if(realpathSync(source)!==source||!lstatSync(source).isDirectory()||!isAbsolute(destination)||resolve(destination)!==destination||inside(source,destination)||inside(destination,source))fail('工程输入与输出边界无效');
 let parent=dirname(destination);while(!existsSync(parent))parent=dirname(parent);
 if(!lstatSync(parent).isDirectory()||realpathSync(parent)!==parent)fail('工程输出经过链接');
 if(lstatSync(destination,{throwIfNoEntry:false}))fail('本轮工程已存在');mkdirSync(destination,{recursive:true,mode:0o700});
 const generated=new Set(['.git','.dart_tool','.gradle','.symlinks','Pods','build','target','node_modules','ephemeral','.cache','.DS_Store','swiftpm','dist','tsconfig.tsbuildinfo']);
 function visit(from,to){for(const name of readdirSync(from).sort()){if(generated.has(name))continue;const a=join(from,name),b=join(to,name),s=lstatSync(a);
  if(s.isDirectory()){mkdirSync(b);visit(a,b);}else if(s.isFile()){copyFileSync(a,b);}
  else if(s.isSymbolicLink()){const target=realpathSync(a);if(!inside(source,target)||!lstatSync(target).isFile())fail('源码链接越界');symlinkSync(join(destination,relative(source,target)),b);}else fail('源码文件类型无效');
 }}visit(source,destination);materializeAnalysisOptions(source,destination);return destination;
}
// 归档坐标只接受本产品当前锁；完整性在build前核验，prepare允许稍后展开的锁。

async function stageArchives(work,receipt) {
 // 归档都来自回执；先按本产品锁回读摘要，再交给现有原生准备器，缺失时禁止下载。
 for(const item of receipt.archives['sdk-native']||[]) {
  
  const directory=join(work,'sdk-native/sources/archives');mkdirSync(directory,{recursive:true});
  const suffix=new URL(item.url).pathname.endsWith('.zip')?'.zip':'.tar.gz';
  const target=join(directory,item.sha256+suffix);if(!existsSync(target))copyFileSync(item.path,target);
 }
}
export async function prepare(platform,work,receipt,base) {
 const env=resourceEnvironment(platform,work,receipt,base),source=sourceRoot();
 for(const name of ['work','tmp','cache','config','dependencies','stage'])mkdirSync(join(work,name),{recursive:true,mode:0o700});
 await stageArchives(work,receipt);

 return {schema:1,product_id:product,platform,work};
}
export async function build(platform,work,receipt,base) {
 const env=resourceEnvironment(platform,work,receipt,base),declared=platformContract(platform);
 await stageArchives(work,receipt);
 const shell=receipt.tools.bash?.path;
 if(!shell)fail('缺少显式Shell资源');
 const project=env[prefix+'_PROJECT_ROOT'];

  env.TATACHATSDK_WORK_DIR=join(work,'work/native');env.TATACHATSDK_NATIVE_OUTPUT_DIR=join(work,'work/output');
  for(const path of ['work/native','work/output'])mkdirSync(join(work,path),{recursive:true});
  await run(shell,[join(root,'scripts/build-native.sh'),'host'],env);

 return completeBuild(platform,work,receipt,env);
}

// 每次调用拥有自己的取消和进程集合，导入API并发也不能共享执行状态。
const executions=new AsyncLocalStorage();
export async function runBuildProcess(file,args,env,cwd=root,{capture=false,input,accepted=[0],timeout=7200000,signal=executions.getStore()?.signal,passHost=false,streamError=false}={}) {
 signal?.throwIfAborted();
 return new Promise((ok,reject)=>{
  const child=spawn(file,args,{cwd,env:workEnvironment(env),detached:true,stdio:['pipe','pipe','pipe',...(passHost?[3]:[])]});
  trackWorkProcess(child.pid);
  let stdout=[],stderr=[],bytes=0,reason,settled=false;
  const stop=()=>{try{process.kill(-child.pid,'SIGTERM');}catch(error){if(error.code!=='ESRCH')reason='无法取消产品工具进程组';}};
  let killer;
  const terminate=()=>{stop();clearTimeout(killer);killer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch{}},1500);};
  const forced=setTimeout(()=>{reason='产品工具超时';terminate();},timeout);forced.unref();
  const abort=()=>{reason='产品任务已取消';terminate();};
  signal?.addEventListener('abort',abort,{once:true});if(signal?.aborted)abort();
  const consume=(chunk,out)=>{bytes+=chunk.length;if(bytes>16*1024*1024){reason='产品工具输出超限';terminate();return;}out.push(chunk);if(!capture)process.stderr.write(chunk);};
  child.stdout.on('data',chunk=>consume(chunk,stdout));child.stderr.on('data',chunk=>{if(capture&&streamError)process.stderr.write(chunk);else consume(chunk,stderr);});
  child.stdin.on('error',()=>{reason='产品工具输入失败';stop();});
  child.once('error',()=>{reason='产品工具无法启动';});
  child.once('close',async(code,termination)=>{
   clearTimeout(forced);clearTimeout(killer);
   // 主进程close不代表后代退出；未退出的同组工具必须停止并确认，之后才能清理材料。
   const alive=()=>{if(!child.pid)return false;try{process.kill(-child.pid,0);return true;}catch(error){return error.code!=='ESRCH';}};
   if(alive()){reason??='产品工具退出后仍有后代';stop();for(let n=0;n<15&&alive();n++)await new Promise(r=>setTimeout(r,100));if(alive())try{process.kill(-child.pid,'SIGKILL');}catch{};for(let n=0;n<15&&alive();n++)await new Promise(r=>setTimeout(r,100));}
   if(alive()){reason='产品工具后代退出未确认，保留工作目录';const state=executions.getStore();if(state)state.unconfirmed=true;}
   signal?.removeEventListener('abort',abort);clearTimeout(killer);
   if(signal?.aborted)reason='产品任务已取消';
   if(settled)return;settled=true;
   if(reason||termination||!accepted.includes(code))reject(Error(reason||'产品工具执行失败'));
   else ok({stdout:Buffer.concat(stdout).toString('utf8'),stderr:Buffer.concat(stderr).toString('utf8'),code});
  });
  child.stdin.end(input);
 });
}
const run=async(file,args,env,cwd=root,capture=false)=>(await runBuildProcess(file,args,env,cwd,{capture})).stdout;

export function outputDigest(path) {
 const hash=createHash('sha256');const base=path;
 function visit(file){const info=lstatSync(file);const name=relative(base,file);
  if(info.isSymbolicLink()){const real=realpathSync(file);if(!inside(base,real))fail('输出链接越界');hash.update(JSON.stringify([name,'link',readlinkSync(file)])+'\n');}
  else if(info.isDirectory()){hash.update(JSON.stringify([name,'directory'])+'\n');for(const child of readdirSync(file).sort())visit(join(file,child));}
  else if(info.isFile()&&info.nlink===1){hash.update(JSON.stringify([name,'file',Boolean(info.mode&0o111),info.size])+'\n');hash.update(readFileSync(file));}
  else fail('输出包含特殊文件或硬链接');
 }visit(path);return hash.digest('hex');
}
// 摘要只读执行源码；所属根技术文档及target等运行数据不改变编译身份。
function sourceDigest() {
 const hash=createHash('sha256'),rootData=new Set(['cache','target','rely','tools','tasks','TATA.md','MAP.md','CODEX.md','CLAUDE.md','README.md','TataChatSDK.md']);
 const generated=new Set(['.git','node_modules','.dart_tool','.gradle','.symlinks','Pods','build','target','ephemeral','.cache','.DS_Store']);
 function visit(path){for(const name of readdirSync(path).sort()){
  if(generated.has(name)||path===root&&rootData.has(name))continue;
  const file=join(path,name),info=lstatSync(file);hash.update(relative(root,file)+'\n');
  if(info.isDirectory())visit(file);else if(info.isFile()){hash.update(String(Boolean(info.mode&0o111)));hash.update(readFileSync(file));}
  else if(info.isSymbolicLink()){const real=realpathSync(file);if(!inside(root,real))fail('产品源码链接越界');hash.update(readlinkSync(file));}
  else fail('产品源码特殊输入未声明');
 }}visit(root);return hash.digest('hex');
}

// 宿主完整Build先由调用方消费回执、安装并收尾；独立执行由本产品清空现场。
export async function execute(platform,work,request={},options={}) {
 checkWork(work);
 return withFixedWork(taskScope(work),()=>executeTask(platform,work,request,options),{environment:options.environment||process.env,retain:request.resource_mode==='provided'||(options.environment||process.env).PRODUCT_HOST_FD==='3'});
}
async function executeTask(platform,work,request={},options={}) {
 checkWork(work);platformContract(platform);
 if(!inside(productTarget(platform),work)||work===productTarget(platform))fail('执行工作根与当前产品平台不一致');
 options.signal?.throwIfAborted();
 if(!request||typeof request!=='object'||Array.isArray(request)||Object.keys(request).some(k=>!['schema','product_id','platform','work','run_id','program_digest'].includes(k))
  ||request.schema!==undefined&&request.schema!==1||request.run_id!==undefined&&!/^[1-9][0-9]{8}$/u.test(request.run_id)||request.program_digest!==undefined&&!/^[a-f0-9]{64}$/u.test(request.program_digest)
  ||request.product_id!==undefined&&request.product_id!==product||request.platform!==undefined&&request.platform!==platform||request.work!==undefined&&request.work!==work)fail('公开Build请求身份或字段无效');
 chmodSync(work,0o700);
 const lock=join(work,'.product-build.lock'),resultFile=join(work,'build-result.json');
 if(existsSync(resultFile))fail('本轮完整Build已有结果，禁止复用旧终态');
 const handle=openSync(lock,'wx',0o600);closeSync(handle);
 const cancellation=new AbortController(),abort=()=>cancellation.abort();options.signal?.addEventListener('abort',abort,{once:true});if(options.signal?.aborted)abort();
 const state={signal:cancellation.signal,cancellation,host:options.host,unconfirmed:false,finished:false};
 try{return await executions.run(state,async()=>{
  const initial=sourceDigest(),stages=options.stages||{requirements,resources:(...args)=>import('./resources.mjs').then(m=>m.resources(...args)),prepare,build};
  const unchanged=()=>{state.signal.throwIfAborted();if(sourceDigest()!==initial)fail('产品源码或锁在执行期间改变');};
  const resourcesOptions={signal:state.signal,offline:Boolean(options.offline),environment:options.environment||process.env};
  await stages.requirements(platform,work);unchanged();
  let receipt=await stages.resources(platform,work,request,resourcesOptions);unchanged();
  await stages.prepare(platform,work,receipt,resourcesOptions.environment);unchanged();
  await stages.requirements(platform,work);
  receipt=await stages.resources(platform,work,receipt,resourcesOptions);unchanged();
  const result=await stages.build(platform,work,receipt,resourcesOptions.environment);unchanged();
  checkBuildResult(result,platform,work,request.run_id);
  writeFileSync(resultFile,JSON.stringify(result)+'\n',{flag:'wx',mode:0o600});return result;
 });}catch(error){if(String(error?.message).includes('退出未确认'))state.unconfirmed=true;throw error;}finally{state.finished=true;state.socket?.destroy();options.signal?.removeEventListener('abort',abort);if(!state.unconfirmed){unlinkSync(lock);if(request.resource_mode!=='provided'&&(options.environment||process.env).PRODUCT_HOST_FD!=='3')clearWork(work);}}
}
export function checkBuildResult(value,platform,work,runId) {
 const declared=platformContract(platform);
 if(!value||Object.keys(value).sort().join(',')!==(runId?'completion,files,platform,product_id,run_id,schema,work':'completion,files,platform,product_id,schema,work')
  ||value.schema!==1||value.product_id!==product||value.platform!==platform||value.work!==work||value.completion!==declared.completion
  ||runId&&value.run_id!==runId||!Array.isArray(value.files)||value.files.length!==declared.files.length)fail('完整Build结果身份或完成方式无效');
 for(let n=0;n<value.files.length;n++){const entry=value.files[n],file=join(work,declared.files[n]);
  if(Object.keys(entry).sort().join(',')!=='path,sha256'||entry.path!==file||!inside(work,file)||realpathSync(file)!==file||!/^[a-f0-9]{64}$/u.test(entry.sha256)||outputDigest(file)!==entry.sha256)fail('完整Build产物摘要或边界无效');}
 return value;
}
async function completeBuild(platform,work,receipt,env) {
 const declared=platformContract(platform);
 if(declared.completion==='device-install')fail('本产品未声明设备安装实现');
 if(declared.completion==='macos-artifact')for(const name of declared.files)await run(env.CODESIGN,['--verify','--deep','--strict',join(work,name)],env);
 const result={schema:1,product_id:product,platform,work,completion:declared.completion,
  files:declared.files.map(name=>{const path=join(work,name);if(!inside(work,path)||realpathSync(path)!==path)fail('Build候选越界');return {path,sha256:outputDigest(path)};})};
 if(receipt.run_id)result.run_id=receipt.run_id;return checkBuildResult(result,platform,work,receipt.run_id);
}

// 模块先完成初始化，资源模块才能反向导入本文件的唯一校验；异步CLI在独立Promise中执行。
async function runCLI(){
 const [operation,,flag,work]=process.argv.slice(2);
 if(['execute','resources','prepare','build'].includes(operation)&&flag==='--work'){
  checkWork(work);
  return withFixedWork(taskScope(work),()=>runCommand(),{environment:process.env,retain:process.env.PRODUCT_HOST_FD==='3'||process.env.PRODUCT_RESOURCE_FD==='4'});
 }
 return runCommand();
}
async function runCommand(){
 if(["native","protocol"].includes(process.argv[2])){process.exitCode=await runOwnedShell(process.argv[2],process.argv.slice(3));return;}
 const [command,platform,option,work,...extra]=process.argv.slice(2);
 if(command==='temporary-root') {
  if(work!==undefined||extra.length)fail('临时入口参数无效');
  const host=process.platform==='darwin'?'macos':process.platform==='win32'?'windows':process.platform==='linux'?(process.arch==='arm64'?'linux-arm':process.arch==='x64'?'linux-amd':undefined):undefined;
  const fallback=option?.endsWith('macos')?option.slice(0,-5)+host:option;
  const chosen=Object.hasOwn(contract.platforms,platform)?platform
   :platform&&option?.endsWith('-'+platform)&&Object.hasOwn(contract.platforms,option)?option
   :Object.hasOwn(contract.platforms,'host-'+platform)?'host-'+platform:!platform?(Object.hasOwn(contract.platforms,fallback)?fallback:option):platform;
  platformContract(chosen);process.stdout.write(temporaryRoot(chosen,'tmp')+'\n');
 } else {

 if(!['requirements','resources','prepare','build','execute'].includes(command)||option!=='--work'||extra.some(x=>x!=='--offline')||extra.length>1||extra.length&&!['resources','execute'].includes(command))fail('固定入口参数无效');
 checkWork(work);
 if(command==='requirements')process.stdout.write(JSON.stringify(requirements(platform,work))+'\n');
 else{
  const cancellation=new AbortController();for(const name of ['SIGTERM','SIGINT'])process.once(name,()=>cancellation.abort());
  let input='';for await(const chunk of process.stdin){input+=chunk;if(Buffer.byteLength(input)>2*1024*1024)fail('公开输入超限');}
  const request=input?JSON.parse(input):{},options={environment:process.env,signal:cancellation.signal,offline:extra.includes('--offline')};
  let result;
  if(command==='execute'){
   const {bootstrapNode}=await import('./resources.mjs');const node=await bootstrapNode(work,options);
   if(realpathSync(process.execPath)!==realpathSync(node.path)){
    const environment=Object.fromEntries(['HOME','USER','LOGNAME','LANG','LC_ALL','PRODUCT_TOOL_ROOT','PRODUCT_DEPENDENCY_ROOT','PRODUCT_HOST_FD','PRODUCT_WORK_LEASE'].filter(k=>typeof process.env[k]==='string').map(k=>[k,process.env[k]]));
    result=JSON.parse((await runBuildProcess(node.path,[fileURLToPath(import.meta.url),command,platform,option,work,...extra],workEnvironment(environment),root,{capture:true,streamError:true,input:JSON.stringify(request),signal:cancellation.signal,passHost:environment.PRODUCT_HOST_FD==='3'})).stdout);
   }else result=await execute(platform,work,request,options);
  }else if(command==='resources')result=await (await import('./resources.mjs')).resources(platform,work,request,options);
  else result=await executions.run({signal:cancellation.signal},()=>command==='prepare'?prepare(platform,work,request,process.env):build(platform,work,request,process.env));
  process.stdout.write(JSON.stringify(result)+'\n');
 }
}
}


// 原生编译、协议生成和分析配置的唯一正文；原有消费者入口只转交参数。
export const BUILD_SHELL_SOURCES = Object.freeze({"native": "#!/usr/bin/env bash\nset -euo pipefail\n\nMODE=\"${1:-host}\"\nROOT=\"${TATACHATSDK_SOURCE_ROOT:?缺少本产品源码根}\"\nMANIFEST=\"$ROOT/native/Cargo.toml\"\n# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。\nPRODUCT_TEMP_SOURCE=\"$ROOT\"\nPRODUCT_TARGET_TEMP_ROOT=\"$(\"${PRODUCT_NODE_BIN:-${NODE:-node}}\" \"$PRODUCT_TEMP_SOURCE/scripts/build.mjs\" temporary-root \"${PLATFORM:-${platform:-}}\" 'sdk')\" || exit 1\nif [[ -z \"${PRODUCT_WORK_DIR:-}\" && \"${TMPDIR:-}\" != \"$PRODUCT_TEMP_SOURCE/target/\"* ]]; then\n  export TMPDIR=\"$PRODUCT_TARGET_TEMP_ROOT/\"\nfi\nTATACHATSDK_WORK_DIR=\"${TATACHATSDK_WORK_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tatachatsdk/work}\"\nTATACHATSDK_NATIVE_OUTPUT_DIR=\"${TATACHATSDK_NATIVE_OUTPUT_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tatachatsdk/output}\"\nTATACHATSDK_NATIVE_ANDROID_DIR=\"${TATACHATSDK_NATIVE_ANDROID_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/android}\"\nTATACHATSDK_NATIVE_IOS_DIR=\"${TATACHATSDK_NATIVE_IOS_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/ios}\"\nTATACHATSDK_NATIVE_MACOS_DIR=\"${TATACHATSDK_NATIVE_MACOS_DIR:-$TATACHATSDK_NATIVE_OUTPUT_DIR/macos}\"\nTARGET_DIR=\"${CARGO_TARGET_DIR:-$TATACHATSDK_WORK_DIR/cargo}\"\nexport CARGO_TARGET_DIR=\"$TARGET_DIR\"\nexport TATACHATSDK_WORK_DIR TATACHATSDK_NATIVE_OUTPUT_DIR\nexport TATACHATSDK_NATIVE_ANDROID_DIR TATACHATSDK_NATIVE_IOS_DIR TATACHATSDK_NATIVE_MACOS_DIR\n\ncase \"$MODE\" in\n  host|macos|android|ios)\n    python3 - \"$ROOT\" \"$TATACHATSDK_WORK_DIR\" \"$TATACHATSDK_NATIVE_OUTPUT_DIR\" \\\n      \"$TATACHATSDK_NATIVE_ANDROID_DIR\" \"$TATACHATSDK_NATIVE_IOS_DIR\" \\\n      \"$TATACHATSDK_NATIVE_MACOS_DIR\" \"$TARGET_DIR\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource = Path(sys.argv[1]).resolve()\nfor value in sys.argv[2:]:\n    raw, target = Path(value), Path(value).resolve()\n    if not raw.is_absolute() or target == source or (source in target.parents and source / 'target' not in target.parents):\n        raise SystemExit(f'TataChatSDK可写目录必须是源码外绝对路径：{value}')\nCHECK_OUTPUTS\n    mkdir -p \"$TATACHATSDK_WORK_DIR\" \"$TATACHATSDK_NATIVE_OUTPUT_DIR\"\n    ;;\nesac\n\n# 中文注释：Rust 1.97.1 的优化型宿主 proc-macro 会产生不可加载的错位 Mach-O；\n# 仅把 Release 构建依赖固定为非优化、非裁剪，产品目标仍保持 optimized Release。\nexport CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_OPT_LEVEL=0\nexport CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=0\nexport CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP=none\n\nensure_target() {\n  local target=\"$1\"\n  local compiler=\"${RUSTC:-rustc}\" sysroot libdir library\n  # 只核对实际编译器已具备的目标库；工具准备由开发环境或CI负责。\n  sysroot=\"$(\"$compiler\" --print sysroot)\" || return 1\n  libdir=\"$(\"$compiler\" --print target-libdir --target \"$target\")\" || return 1\n  # 仅统一官方Windows路径分隔符，不选择其他工具或目标。\n  sysroot=\"${sysroot//\\\\//}\"; libdir=\"${libdir//\\\\//}\"\n  if [[ \"$libdir\" == \"$sysroot/lib/rustlib/$target/lib\" && -d \"$libdir\" && ! -L \"$libdir\" ]]; then\n    for library in \"$libdir\"/libstd-*.rlib; do [[ -s \"$library\" && ! -L \"$library\" ]] && return 0; done\n  fi\n  echo \"Rust目标标准库缺失，请先在产品开发环境准备：$target\" >&2\n  return 1\n}\n\nassert_symbols() {\n  local library=\"$1\"\n  local nm_bin=\"${2:-nm}\"\n  local symbols\n  local nm_args=(-g)\n  # Gradle strips the regular ELF symbol table from the final APK but retains\n  # the dynamic exports required by Dart FFI. Read that runtime-visible table\n  # for ELF only; Mach-O keeps its existing global-symbol verification.\n  if file -b \"$library\" | grep -q 'ELF'; then\n    nm_args=(-D --defined-only)\n  fi\n  symbols=\"$(\"$nm_bin\" \"${nm_args[@]}\" \"$library\" 2>/dev/null | awk '{print $NF}' || true)\"\n  local required_symbols=(\n    tatachat_sdk_mls_identity_json\n    tatachat_sdk_mls_store_json\n    tatachat_sdk_mls_create_key_package_json\n    tatachat_sdk_mls_group_create_json\n    tatachat_sdk_mls_group_add_members_json\n    tatachat_sdk_mls_group_remove_members_json\n    tatachat_sdk_mls_group_create_message_json\n    tatachat_sdk_mls_group_process_json\n    tatachat_sdk_mls_group_state_json\n    tatachat_sdk_free_string\n  )\n  local symbol\n  for symbol in \"${required_symbols[@]}\"; do\n    if [[ \"$(grep -Ec \"^_?${symbol}$\" <<<\"$symbols\" || true)\" != 1 ]]; then\n      printf 'TataChatSDK required symbol %s must occur once in %s\\n' \\\n        \"$symbol\" \"$library\" >&2\n      exit 1\n    fi\n  done\n\n  # 中文注释：只导出现行OpenMLS边界；旧直聊、MLS包装和生产smoke接口禁止导出。\n  if grep -Eq '^_?tatachat_sdk_(device_identity|mls_encrypt|mls_decrypt|mls_rekey_state|mls_two_party_smoke)_json$' <<<\"$symbols\"; then\n    printf 'TataChatSDK legacy MLS/direct symbols found in %s\\n' \"$library\" >&2\n    exit 1\n  fi\n}\n\nbuild_host() {\n  cargo build --manifest-path \"$MANIFEST\" --locked\n  case \"$(uname -s)\" in\n    Darwin) library=\"$TARGET_DIR/debug/libtatachat_sdk.dylib\" ;;\n    Linux) library=\"$TARGET_DIR/debug/libtatachat_sdk.so\" ;;\n    *) printf 'Unsupported TataChatSDK host\\n' >&2; exit 1 ;;\n  esac\n  assert_symbols \"$library\"\n}\n\nbuild_android() {\n  ensure_target aarch64-linux-android\n\n  local ndk_home=\"${ANDROID_NDK_HOME:-}\"\n  if [[ -z \"$ndk_home\" ]]; then\n    local sdk_home=\"${ANDROID_HOME:-$HOME/Library/Android/sdk}\"\n    ndk_home=\"$(ls -d \"$sdk_home/ndk/\"* 2>/dev/null | sort -V | tail -1 || true)\"\n  fi\n  [[ -d \"$ndk_home\" ]] || { printf 'Android NDK not found\\n' >&2; exit 1; }\n\n  local toolchain\n  case \"$(uname -s)\" in\n    Darwin)\n      toolchain=\"$ndk_home/toolchains/llvm/prebuilt/darwin-x86_64\"\n      [[ -d \"$toolchain\" ]] ||\n        toolchain=\"$ndk_home/toolchains/llvm/prebuilt/darwin-aarch64\"\n      ;;\n    Linux) toolchain=\"$ndk_home/toolchains/llvm/prebuilt/linux-x86_64\" ;;\n    *) printf 'Unsupported Android build host\\n' >&2; exit 1 ;;\n  esac\n  [[ -d \"$toolchain\" ]] || {\n    printf 'Android NDK toolchain not found\\n' >&2\n    exit 1\n  }\n\n  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=\"$toolchain/bin/aarch64-linux-android24-clang\"\n  export CC_aarch64_linux_android=\"$toolchain/bin/aarch64-linux-android24-clang\"\n  export AR_aarch64_linux_android=\"$toolchain/bin/llvm-ar\"\n  cargo build --manifest-path \"$MANIFEST\" --release --target aarch64-linux-android --locked\n\n  local destination=\"$TATACHATSDK_NATIVE_ANDROID_DIR/arm64-v8a\"\n  mkdir -p \"$destination\"\n  cp \"$TARGET_DIR/aarch64-linux-android/release/libtatachat_sdk.so\" \"$destination/\"\n  assert_symbols \"$destination/libtatachat_sdk.so\" \"$toolchain/bin/llvm-nm\"\n}\n\nbuild_ios_slice() {\n  local target=\"$1\" sdk=\"$2\" flag_name=\"$3\"\n  local sdk_path host_sdk target_flags=\"${!flag_name:-}\"\n  sdk_path=\"$(xcrun --sdk \"$sdk\" --show-sdk-path)\"\n  host_sdk=\"$(xcrun --sdk macosx --show-sdk-path)\"\n  [[ -d \"$sdk_path\" && -d \"$host_sdk\" && \"$sdk_path\" != *[[:space:]]* ]] || {\n    printf 'TataChatSDK Apple SDK path is invalid\\n' >&2; exit 1;\n  }\n  # 宿主宏只链接macOS SDK；目标专属参数选择真机或Simulator SDK，保留未裁剪Mach-O。\n  target_flags=\"${target_flags:+$target_flags }-C strip=none -C link-arg=-isysroot -C link-arg=$sdk_path -C link-arg=-Wl,-install_name,@rpath/TataChatSDK.framework/TataChatSDK\"\n  env SDKROOT=\"$host_sdk\" \"$flag_name=$target_flags\" \\\n    cargo build --manifest-path \"$MANIFEST\" --release --target \"$target\" --locked\n  local library=\"$TARGET_DIR/$target/release/libtatachat_sdk.dylib\"\n  local framework_root=\"$TARGET_DIR/$target-framework\"\n  local framework=\"$framework_root/TataChatSDK.framework\"\n  local nm_bin\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  assert_symbols \"$library\" \"$nm_bin\"\n  local string_offset\n  string_offset=\"$(otool -l \"$library\" | awk '/cmd LC_SYMTAB/{active=1;next} active&&/cmd /{active=0} active&&/stroff/{print $2}')\"\n  [[ -n \"$string_offset\" && $((string_offset % 8)) -eq 0 ]] || {\n    printf 'TataChatSDK iOS LINKEDIT string pool is not 8-byte aligned\\n' >&2\n    exit 1\n  }\n\n  # 中文注释：TataChatSDK 以自己的动态 Framework 进入宿主，Smoldot 不再承载或\n  # 保活任何聊天符号。Framework 的 install name 固定为标准 @rpath，由 Xcode\n  # 嵌入并签名，Dart FFI 只解析这一份已经装载的动态库。\n  if [[ -e \"$framework_root\" ]]; then\n    find \"$framework_root\" -depth -delete\n  fi\n  mkdir -p \"$framework/Headers\" \"$framework/Modules\"\n  cp \"$library\" \"$framework/TataChatSDK\"\n  chmod 755 \"$framework/TataChatSDK\"\n  cp \"$ROOT/native/tatachat_sdk.h\" \"$framework/Headers/tatachat_sdk.h\"\n  cat > \"$framework/Modules/module.modulemap\" <<'MODULEMAP'\nframework module TataChatSDK {\n  umbrella header \"tatachat_sdk.h\"\n  export *\n}\nMODULEMAP\n  cat > \"$framework/Info.plist\" <<'PLIST'\n<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<plist version=\"1.0\">\n<dict>\n  <key>CFBundleDevelopmentRegion</key><string>en</string>\n  <key>CFBundleExecutable</key><string>TataChatSDK</string>\n  <key>CFBundleIdentifier</key><string>org.cocoapods.TataChatSDK</string>\n  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>\n  <key>CFBundleName</key><string>TataChatSDK</string>\n  <key>CFBundlePackageType</key><string>FMWK</string>\n  <key>CFBundleShortVersionString</key><string>1.0.0</string>\n  <key>CFBundleVersion</key><string>1</string>\n  <key>MinimumOSVersion</key><string>16.0</string>\n</dict>\n</plist>\nPLIST\n  assert_symbols \"$framework/TataChatSDK\" \"$nm_bin\"\n\n}\n\nbuild_ios() {\n  # 同一个iOS产物必须同时具备真机和Apple Silicon Simulator切片；缺目标先失败。\n  ensure_target aarch64-apple-ios\n  ensure_target aarch64-apple-ios-sim\n  export IPHONEOS_DEPLOYMENT_TARGET=16.0\n  build_ios_slice aarch64-apple-ios iphoneos CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS\n  build_ios_slice aarch64-apple-ios-sim iphonesimulator CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS\n  local xcframework=\"$TATACHATSDK_NATIVE_IOS_DIR/TataChatSDK.xcframework\"\n  mkdir -p \"$TATACHATSDK_NATIVE_IOS_DIR\"\n  if [[ -e \"$xcframework\" ]]; then\n    find \"$xcframework\" -depth -delete\n  fi\n  xcodebuild -create-xcframework \\\n    -framework \"$TARGET_DIR/aarch64-apple-ios-framework/TataChatSDK.framework\" \\\n    -framework \"$TARGET_DIR/aarch64-apple-ios-sim-framework/TataChatSDK.framework\" \\\n    -output \"$xcframework\"\n  local packaged variant nm_bin\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  for variant in ios-arm64 ios-arm64-simulator; do\n    packaged=\"$xcframework/$variant/TataChatSDK.framework/TataChatSDK\"\n    [[ -f \"$packaged\" && \"$(lipo -archs \"$packaged\")\" == arm64 ]] || {\n      printf 'TataChatSDK iOS slice missing or architecture invalid: %s\\n' \"$variant\" >&2; exit 1;\n    }\n    assert_symbols \"$packaged\" \"$nm_bin\"\n    otool -D \"$packaged\" | tail -n +2 | grep -qx '@rpath/TataChatSDK.framework/TataChatSDK' || {\n      printf 'TataChatSDK iOS framework install name is invalid\\n' >&2; exit 1;\n    }\n  done\n  # 回读Xcode实际平台元数据，不能用两个真机库冒充Simulator切片。\n  python3 - \"$xcframework/Info.plist\" <<'CHECK_IOS_SLICES'\nimport plistlib, sys\nwith open(sys.argv[1], 'rb') as file:\n    libraries = plistlib.load(file).get('AvailableLibraries', [])\nactual = {(item.get('LibraryIdentifier'), item.get('SupportedPlatform'),\n           item.get('SupportedPlatformVariant', ''), tuple(item.get('SupportedArchitectures', [])))\n          for item in libraries}\nexpected = {('ios-arm64', 'ios', '', ('arm64',)), ('ios-arm64-simulator', 'ios', 'simulator', ('arm64',))}\nif len(libraries) != 2 or actual != expected:\n    raise SystemExit('TataChatSDK XCFramework必须包含准确真机与Simulator ARM64切片')\nCHECK_IOS_SLICES\n}\n\nbuild_macos() {\n  ensure_target aarch64-apple-darwin\n  export MACOSX_DEPLOYMENT_TARGET=13.0\n\n  # 中文注释：目标专属参数不得污染宿主 proc-macro；host 模式仍只服务本机调试测试。\n  local macos_rustflags=\"${CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS:-}\"\n  macos_rustflags=\"${macos_rustflags:+$macos_rustflags }-C strip=none -C link-arg=-Wl,-install_name,@rpath/libtatachat_sdk.dylib\"\n  CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS=\"$macos_rustflags\" \\\n    cargo build --manifest-path \"$MANIFEST\" --release --target aarch64-apple-darwin --locked\n\n  local library=\"$TARGET_DIR/aarch64-apple-darwin/release/libtatachat_sdk.dylib\"\n  local destination=\"$TATACHATSDK_NATIVE_MACOS_DIR/libtatachat_sdk.dylib\"\n  local nm_bin\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  mkdir -p \"$TATACHATSDK_NATIVE_MACOS_DIR\"\n  cp \"$library\" \"$destination\"\n  [[ \"$(lipo -archs \"$destination\")\" == arm64 ]] || {\n    printf 'TataChatSDK macOS library must contain only arm64\\n' >&2\n    exit 1\n  }\n  file \"$destination\" | grep -q 'dynamically linked shared library' || {\n    printf 'TataChatSDK macOS artifact is not a dynamic library\\n' >&2\n    exit 1\n  }\n  assert_symbols \"$destination\" \"$nm_bin\"\n  otool -D \"$destination\" | tail -n +2 | grep -qx '@rpath/libtatachat_sdk.dylib' || {\n    printf 'TataChatSDK macOS install name is invalid\\n' >&2\n    exit 1\n  }\n}\n\nverify_android_package() {\n  local package=\"${1:?Android package is required}\"\n  local entry temporary packaged nm_bin\n  [[ -f \"$package\" ]] || { printf 'Android package not found: %s\\n' \"$package\" >&2; exit 1; }\n  case \"$package\" in\n    *.apk) entry='lib/arm64-v8a/libtatachat_sdk.so' ;;\n    *.aab) entry='base/lib/arm64-v8a/libtatachat_sdk.so' ;;\n    *) printf 'Unsupported Android package: %s\\n' \"$package\" >&2; exit 1 ;;\n  esac\n  temporary=\"$(mktemp -d)\"\n  packaged=\"$temporary/libtatachat_sdk.so\"\n  unzip -p \"$package\" \"$entry\" > \"$packaged\" || {\n    find \"$temporary\" -depth -delete\n    printf 'Android package missing TataChatSDK library\\n' >&2\n    exit 1\n  }\n  nm_bin=\"${ANDROID_NM:-}\"\n  if [[ -z \"$nm_bin\" ]]; then\n    local sdk_home=\"${ANDROID_HOME:-$HOME/Library/Android/sdk}\"\n    nm_bin=\"$(ls \"$sdk_home\"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-nm 2>/dev/null | tail -1 || true)\"\n  fi\n  [[ -n \"$nm_bin\" ]] || {\n    find \"$temporary\" -depth -delete\n    printf 'Android llvm-nm not found\\n' >&2\n    exit 1\n  }\n  assert_symbols \"$packaged\" \"$nm_bin\"\n  find \"$temporary\" -depth -delete\n  if unzip -Z1 \"$package\" | grep -E '(^|/)lib/(armeabi-v7a|x86|x86_64)/libtatachat_sdk\\.so$'; then\n    printf 'Android package contains unsupported TataChatSDK ABI\\n' >&2\n    exit 1\n  fi\n}\n\nverify_ios_package() {\n  local app_bundle=\"${1:?Runner.app is required}\"\n  local executable=\"$app_bundle/Runner\"\n  local framework=\"$app_bundle/Frameworks/TataChatSDK.framework/TataChatSDK\"\n  local nm_bin\n  [[ -f \"$executable\" ]] || { printf 'iOS Runner not found\\n' >&2; exit 1; }\n  [[ -f \"$framework\" ]] || { printf 'iOS package missing TataChatSDK.framework\\n' >&2; exit 1; }\n  [[ \"$(lipo -archs \"$framework\")\" == arm64 ]] || {\n    printf 'Packaged TataChatSDK framework must contain only arm64\\n' >&2\n    exit 1\n  }\n  file \"$framework\" | grep -q 'dynamically linked shared library' || {\n    printf 'Packaged TataChatSDK binary is not a dynamic framework\\n' >&2\n    exit 1\n  }\n  otool -L \"$executable\" | grep -q '@rpath/TataChatSDK.framework/TataChatSDK' || {\n    printf 'iOS Runner does not link the independent TataChatSDK framework\\n' >&2\n    exit 1\n  }\n  nm_bin=\"$(xcrun --find llvm-nm)\"\n  assert_symbols \"$framework\" \"$nm_bin\"\n}\n\ncase \"$MODE\" in\n  host) build_host ;;\n  macos) build_macos ;;\n  android) build_android ;;\n  ios) build_ios ;;\n  verify-android-package) verify_android_package \"${2:-}\" ;;\n  verify-ios-package) verify_ios_package \"${2:-}\" ;;\n  *) printf 'Usage: %s [host|macos|android|ios|verify-android-package|verify-ios-package]\\n' \"$0\" >&2; exit 64 ;;\nesac\n", "protocol": "#!/usr/bin/env bash\nset -euo pipefail\n\nroot=\"${TATACHATSDK_SOURCE_ROOT:?缺少本产品源码根}\"\nprotocol_dir=\"$root/lib/protocol\"\n# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。\nPRODUCT_TEMP_SOURCE=\"$root\"\nPRODUCT_TARGET_TEMP_ROOT=\"$(\"${PRODUCT_NODE_BIN:-${NODE:-node}}\" \"$PRODUCT_TEMP_SOURCE/scripts/build.mjs\" temporary-root \"${PLATFORM:-${platform:-}}\" 'sdk')\" || exit 1\nif [[ -z \"${PRODUCT_WORK_DIR:-}\" && \"${TMPDIR:-}\" != \"$PRODUCT_TEMP_SOURCE/target/\"* ]]; then\n  export TMPDIR=\"$PRODUCT_TARGET_TEMP_ROOT/\"\nfi\nwork_dir=\"${TATACHATSDK_WORK_DIR:?缺少本产品固定工作根}\"\n\n[[ \"$#\" -eq 0 ]] || { printf '%s\\n' 'TataChatSDK协议生成不接受参数' >&2; exit 1; }\ncase \"$(uname -s)/$(uname -m)\" in\n  Darwin/arm64) protoc_platform=macos ;;\n  Linux/aarch64) protoc_platform=linux-arm ;;\n  Linux/x86_64) protoc_platform=linux-amd ;;\n  *) printf '%s\\n' 'TataChatSDK协议生成宿主不受支持' >&2; exit 1 ;;\nesac\n\n# 两项生成工具均由SDK自己的锁定声明准备到源码外目录；禁止读取系统PATH中的偶然版本。\nprotoc_executable=\"$(\"${PRODUCT_NODE_BIN:?缺少本产品Node}\" \"$root/scripts/dependencies.mjs\" prepare protoc \"$protoc_platform\" \\\n  \"$work_dir\")\"\nplugin_executable=\"$(\"${PRODUCT_NODE_BIN:?缺少本产品Node}\" \"$root/scripts/dependencies.mjs\" prepare protoc_plugin sdk \\\n  \"$work_dir\")\"\n[[ \"$protoc_executable\" = /* && -f \"$protoc_executable\" && -x \"$protoc_executable\" ]] \\\n  || { printf '%s\\n' 'TataChatSDK protoc路径无效' >&2; exit 1; }\n[[ \"$plugin_executable\" = /* && -f \"$plugin_executable\" && -x \"$plugin_executable\" ]] \\\n  || { printf '%s\\n' 'TataChatSDK protoc_plugin路径无效' >&2; exit 1; }\n\noutput_dir=\"$work_dir/protocol\"\nmkdir -p \"$output_dir\"\n\"$protoc_executable\" \\\n  --proto_path=\"$protocol_dir\" \\\n  --dart_out=\"$output_dir\" \\\n  --plugin=\"protoc-gen-dart=$plugin_executable\" \\\n  \"$protocol_dir/basic_content.proto\" \\\n  \"$protocol_dir/media_content.proto\" \\\n  \"$protocol_dir/message.proto\" \\\n  \"$protocol_dir/attachment.proto\" \\\n  \"$protocol_dir/chat_frame.proto\"\n", "analysis": "include: package:flutter_lints/flutter.yaml\n\nanalyzer:\n  exclude:\n    # Isar 官方生成器会调用其自身标记为 experimental 的索引扩展；生成文件不手改。\n    - lib/storage/chat_isar.g.dart\n  language:\n    strict-casts: true\n    strict-inference: true\n    strict-raw-types: true\n\nlinter:\n  rules:\n    - avoid_print\n    - directives_ordering\n    - unawaited_futures\n    - use_super_parameters\n"});
export async function runOwnedShell(name,args,environment=process.env) {
 if(!['native','protocol'].includes(name))fail('Shell入口无效');
 const work=environment.TATACHATSDK_WORK_DIR||environment.PRODUCT_WORK_DIR||temporaryRoot(undefined,'build');checkWork(work);
 return withFixedWork(taskScope(work),async()=>{const result=await runBuildProcess(environment.PRODUCT_BASH_BIN||'/bin/bash',['--noprofile','--norc','-c',BUILD_SHELL_SOURCES[name],'tatachatsdk-'+name,...args],{...environment,TATACHATSDK_WORK_DIR:work,TATACHATSDK_SOURCE_ROOT:root,PRODUCT_NODE_BIN:environment.NODE||process.execPath},root);return result.code;},{environment});
}

const directInvocation=Boolean(!process.execArgv.some(value=>/^(?:-e|--eval(?:=|$)|--input-type(?:=|$))/u.test(value)) && process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url));
const testInvocation=directInvocation && (process.argv[2]==='test'||process.env.NODE_TEST_CONTEXT==='child-v8'&&process.argv.length===2);
// CLI拒绝必须真实失败，不能留成未完成顶层await或输出成功回执。
if(directInvocation&&!testInvocation){
 void runCLI().catch(error=>{console.error(error);process.exitCode=1;});
}

// 正式实现结束；以下回归仅在本文件作为测试入口时注册。
if (testInvocation) {
// 产品独立入口：真实只读需求、资源身份、路径隔离与锁定归档失败关闭。
const {test}=await import('node:test');
const {spawnSync}=await import('node:child_process');
const {default: assert}=await import('node:assert/strict');
const {existsSync,lstatSync,mkdtempSync,readFileSync,readdirSync,realpathSync,rmSync,mkdirSync,symlinkSync,writeFileSync}=await import('node:fs');
const tmpdir=testRoot;
const {dirname,join,resolve}=await import('node:path');


const {default:fs}=await import('node:fs');
const {fixedWork,checkFixedWork,clearFixedWork,finishFixedWork}=await import('./target.mjs');
// 本产品测试使用固定根；资源夹具的内部目录不成为另一套工作根。
const scripts=import.meta.dirname;
function fixtureWork(){const work=checkFixedWork(fixedWork('build'),{create:true});finishFixedWork(work);return work;}
function removeFixture(path,options={}){if(path===fixedWork('build')||path===fixedWork('test')){if(fs.existsSync(path))clearFixedWork(path);return;}fs.rmSync(path,options);}

function writeFixture(path,data,options){
 fs.writeFileSync(path,data,options);
 if(String(path).endsWith('/scripts/build.mjs')&&String(data).includes("from './target.mjs'")){
  for(const name of ['target.mjs'])fs.copyFileSync(join(scripts,name),join(dirname(path),name));
 }
}

function copyFixture(source,destination,...options){
 fs.copyFileSync(source,destination,...options);
 if(String(destination).endsWith('/scripts/build.mjs'))for(const name of ['target.mjs'])fs.copyFileSync(join(scripts,name),join(dirname(destination),name));
}

const sandbox=fixtureWork;
const root=resolve(import.meta.dirname,'..'),base=root;
const fixture=work=>{
 const platform=Object.keys(contract.platforms).find(value=>value.endsWith('android'))||Object.keys(contract.platforms)[0];
 const own={};for(const value of contract.platforms[platform].locks){const key={npm:'npmCache',pub:'pubCache',cargo:'cargoHome'}[value.ecosystem];if(key){own[key]=join(work,key);mkdirSync(own[key]);}}
 return {schema:1,product_id:contract.product_id,platform,work,offline:true,
 tools:Object.fromEntries(contract.platforms[platform].tools.map(tool=>[tool.id,{version:tool.version,path:process.execPath}])),
 dependencies:{own},archives:{},environment:{}};
};
test('每个平台从自身原始锁只读提出需求；缺失原始Pod锁按源码事实拒绝',async()=>{
 const work=sandbox();try{for(const platform of Object.keys(contract.platforms)){
  const before=readdirSync(work),apple=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;
  if(apple&&existsSync(join(base,apple,'Podfile'))&&!existsSync(join(base,apple,'Podfile.lock'))){
   await assert.rejects(async()=>requirements(platform,work),/CocoaPods原始锁缺失/);
  }else{
   const result=await requirements(platform,work);assert.equal(result.product_id,contract.product_id);
   assert.equal(result.platform,platform);assert.equal(result.schema,1);
   assert.ok(result.tools.every(value=>value.id&&value.version));
   assert.ok(result.locks.every(value=>['cargo','pub','npm','cocoapods'].includes(value.ecosystem)));
  }
  assert.deepEqual(readdirSync(work),before);
 }}finally{removeFixture(work,{recursive:true});}
});
test('平台、源码内工作根和链接工作根在任何写入前拒绝',async()=>{
 const work=sandbox();try{
  await assert.rejects(async()=>requirements('unknown',work),/平台/);
  assert.throws(()=>checkWork(root),/本产品target/);
  mkdirSync(join(work,'actual'));symlinkSync(join(work,'actual'),join(work,'linked'));
  assert.throws(()=>checkWork(join(work,'linked')),/固定目录/);
 }finally{removeFixture(work,{recursive:true});}
});
test('资源回执隔离产品、平台、工作根，直接交付工具路径且禁止注入',()=>{
 const work=sandbox();try{
  const receipt=fixture(work),platform=receipt.platform;
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,product_id:'another'}),/身份/);
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,offline:false}),/身份/);
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,tools:{}}),/工具/);
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,environment:{NODE_OPTIONS:'--inspect'}}),/注入/);
  const id=Object.keys(receipt.tools)[0];assert.doesNotThrow(()=>resourceEnvironment(platform,work,{...receipt,tools:{...receipt.tools,[id]:{...receipt.tools[id],version:'informational'}}}));
  const env=resourceEnvironment(platform,work,receipt,{HOME:'/home',TOKEN:'private',INJECTED_CONTEXT:'/private'});
  assert.equal(env.TOKEN,undefined);assert.equal(env.INJECTED_CONTEXT,undefined);assert.equal(env.CARGO_NET_OFFLINE,'true');
  assert.equal(env[contract.product_id.toUpperCase()+'_WORK_DIR'],work);
 }finally{removeFixture(work,{recursive:true});}
});
test('原始锁需要的依赖必须显式交付，不能使用用户默认缓存',()=>{
 const work=sandbox();try{
  const receipt=fixture(work),own=receipt.dependencies.own;
  for(const key of Object.keys(own)){const missing={...own};delete missing[key];
   assert.throws(()=>resourceEnvironment(receipt.platform,work,{...receipt,dependencies:{own:missing}}),/依赖回执/);}
  const key=Object.keys(own)[0];if(key){
   const linked=join(work,'linked');symlinkSync(own[key],linked);
   assert.throws(()=>resourceEnvironment(receipt.platform,work,{...receipt,dependencies:{own:{...own,[key]:linked}}}),/依赖回执/);
  }
 }finally{removeFixture(work,{recursive:true});}
});
test('工程复制在同轮解析包并隔离写入，内部链接重新指向副本',()=>{
 const work=sandbox();try{
  const source=join(work,'input'),output=join(work,'view');mkdirSync(source);
  mkdirSync(join(source,'scripts'));writeFixture(join(source,'scripts/build.mjs'),readFileSync(fileURLToPath(import.meta.url)));
  writeFixture(join(source,'package.json'),'{"name":"input"}');
  writeFixture(join(source,'code.js'),'source');symlinkSync('code.js',join(source,'linked.js'));
  mkdirSync(join(source,'node_modules'));writeFixture(join(source,'node_modules/old'),'generated');
  createView(source,output);writeFixture(join(output,'package.json'),'{"name":"generated"}');
  assert.equal(readFileSync(join(source,'package.json'),'utf8'),'{"name":"input"}');
  assert.equal(realpathSync(join(output,'linked.js')),join(output,'code.js'));
  assert.equal(existsSync(join(output,'node_modules')),false);
  assert.throws(()=>createView(source,output),/已存在/);
 }finally{removeFixture(work,{recursive:true});}
});
test('工程输出的父链接和输入外部链接均拒绝，不能写入第三方目录',()=>{
 const work=sandbox();try{
  const source=join(work,'source'),external=join(work,'external');mkdirSync(source);mkdirSync(external);
  writeFixture(join(source,'code'),'source');symlinkSync(external,join(work,'linked'));
  assert.throws(()=>createView(source,join(work,'linked/view')),/链接/);assert.deepEqual(readdirSync(external),[]);
  symlinkSync('/etc/passwd',join(source,'outside'));
  assert.throws(()=>createView(source,join(work,'bad-view')),/越界/);
 }finally{removeFixture(work,{recursive:true});}
});


// 真实命令行只读自身入口；清除私有环境与工具搜索路径，不能从控制台补齐执行条件。
test('独立命令行从自身声明输出JSON，未知平台失败且不写工作根',async()=>{
 const work=sandbox();try{
  for(const platform of Object.keys(contract.platforms)){
   const before=readdirSync(work),result=spawnSync(process.execPath,[join(root,'scripts/build.mjs'),'requirements',platform,'--work',work],{env:{HOME:work,LANG:'C',LC_ALL:'C'},encoding:'utf8'});
   const apple=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;
   if(apple&&existsSync(join(base,apple,'Podfile'))&&!existsSync(join(base,apple,'Podfile.lock'))){assert.notEqual(result.status,0);assert.match(result.stderr,/CocoaPods原始锁缺失/);}
   else{assert.equal(result.status,0,result.stderr);const value=JSON.parse(result.stdout);assert.equal(value.product_id,contract.product_id);assert.equal(value.platform,platform);}
   assert.deepEqual(readdirSync(work),before);
  }
  const invalid=spawnSync(process.execPath,[join(root,'scripts/build.mjs'),'requirements','unknown','--work',work],{env:{HOME:work},encoding:'utf8'});
  assert.notEqual(invalid.status,0);assert.match(invalid.stderr,/平台/);
 }finally{removeFixture(work,{recursive:true});}
});

// 完整入口控制边界：替身只替换耗时阶段，不调用真实编译或用户安全存储。
test('产品独立execute完成全部自有阶段后才返回唯一结果',async()=>{
 const {execute,outputDigest}=await import('./build.mjs');const work=sandbox(),platform=Object.keys(contract.platforms)[0],declared=contract.platforms[platform],calls=[];
 try{
  const result={schema:1,product_id:contract.product_id,platform,work,completion:declared.completion,run_id:'123456789',files:[]};
  const stages={requirements:async()=>{calls.push('requirements');},resources:async()=>{calls.push('resources');return {};},prepare:async()=>{calls.push('prepare');},build:async()=>{
   calls.push('build');for(const name of declared.files){const path=join(work,name);mkdirSync(dirname(path),{recursive:true});writeFixture(path,'isolated-candidate-fixture');result.files.push({path,sha256:outputDigest(path)});}return result;
  }};
  assert.deepEqual(await execute(platform,work,{run_id:'123456789'},{stages}),result);
  assert.deepEqual(calls,['requirements','resources','prepare','requirements','resources','build']);
  assert.deepEqual(readdirSync(work),[], '独立执行结束必须彻底清空现场');
  result.files=[]; calls.length=0;
  assert.deepEqual(await execute(platform,work,{run_id:'123456789'},{stages}),result);
  assert.deepEqual(readdirSync(work),[], '下一轮结束仍须清空现场');
 }finally{removeFixture(work,{recursive:true});}
});
test('失败、取消、并发和伪造终态不能复用工作根或留下成功回执',async()=>{
 const {execute}=await import('./build.mjs'),platform=Object.keys(contract.platforms)[0];
 for(const failure of ['resources','prepare','build','identity','cancel']){
  const work=sandbox(),abort=new AbortController(),calls=[];
  try{
   const stages={requirements:()=>{},resources:async()=>{calls.push('resources');if(failure==='resources')throw Error('fixture failure');return {};},prepare:async()=>{calls.push('prepare');if(failure==='prepare')throw Error('fixture failure');if(failure==='cancel')abort.abort();},build:async()=>{calls.push('build');if(failure==='build')throw Error('fixture failure');return {schema:1,product_id:'forged'};}};
   await assert.rejects(execute(platform,work,{}, {stages,signal:abort.signal}));
   assert.equal(existsSync(join(work,'build-result.json')),false);assert.equal(existsSync(join(work,'.product-build.lock')),false);
   if(['resources','prepare','cancel'].includes(failure))assert.equal(calls.includes('build'),false);
  }finally{removeFixture(work,{recursive:true});}
 }
 const work=sandbox();try{writeFixture(join(work,'.product-build.lock'),'owned');await assert.rejects(execute(platform,work,{}));assert.equal(readFileSync(join(work,'.product-build.lock'),'utf8'),'owned');}finally{rmSync(join(work,'.product-build.lock'),{force:true});removeFixture(work,{recursive:true});}
});

test('产品取消等待工具进程组退出，不提前交付结果',async()=>{
 const {runBuildProcess}=await import('./build.mjs'),work=sandbox(),abort=new AbortController();let polling,deadline;
 try{
  const pidFile=join(work,'descendant.pid');
  const script="const fs=require('node:fs'),{spawn}=require('node:child_process');const child=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{stdio:'ignore'});fs.writeFileSync(process.argv[1],String(child.pid));setInterval(()=>{},1000);";
  const execution=runBuildProcess(process.execPath,['-e',script,pidFile],process.env,work,{capture:true,signal:abort.signal,timeout:5000});
  polling=setInterval(()=>{if(existsSync(pidFile))abort.abort();},20);deadline=setTimeout(()=>abort.abort(),2000);
  await assert.rejects(execution,/取消/);assert.ok(existsSync(pidFile));const pid=Number(readFileSync(pidFile,'utf8'));
  assert.throws(()=>process.kill(pid,0),error=>error.code==='ESRCH');
 }finally{clearInterval(polling);clearTimeout(deadline);removeFixture(work,{recursive:true});}
});

// 覆盖独立入口、单/多平台物理边界和源码输入排除，统一测试阶段才执行。
test('本仓target由当前平台声明决定，外部或链接工作根不能越界',()=>{
 for(const platform of Object.keys(contract.platforms)){
  const expected=join(root,'target');
  assert.equal(productTarget(platform),expected);
 }
 assert.throws(()=>productTarget('undeclared-platform'));
 assert.throws(()=>checkWork(join(root,'..','foreign-work')),/target/);
 assert.throws(()=>checkWork(join(root,'target')),/target/);
 const work=sandbox();try{assert.equal(checkWork(work),work);assert.throws(()=>checkWork(join(work,'nested')),/固定目录/);}finally{removeFixture(work,{recursive:true,force:true});}
});


// 复制本产品真实入口到自有测试现场；只替换资源供给边界，反向导入和CLI子进程真实执行。
test('CLI异步资源可反向导入唯一校验，正常参数和离线失败均准确收口',()=>{
 const area=sandbox();
 try{
  const source=join(area,'source'),scripts=join(source,'scripts'),file=join(scripts,'build.mjs');
  const platform=Object.keys(contract.platforms)[0];
  const work=join(source,'target','build');
  mkdirSync(scripts,{recursive:true});mkdirSync(work,{recursive:true});
  writeFixture(file,readFileSync(join(root,'scripts/build.mjs')));
  for(const name of ['target.mjs'])writeFixture(join(scripts,name),readFileSync(join(root,'scripts',name)));
  writeFixture(join(scripts,'flows.json'),JSON.stringify(contract));
  const provider=[
   "import {writeFileSync} from 'node:fs';",
   "import {join} from 'node:path';",
   "const refuse = false;",
   "export async function bootstrapNode(work,options){",
   " const owner=await import('./build.mjs');owner.checkWork(work);",
   " writeFileSync(join(work,'bootstrap.json'),JSON.stringify({offline:options.offline,work}));",
   " if(refuse&&options.offline)throw Error('合成离线缺少锁定资源');",
   " return {path:process.execPath};",
   "}",
   "export async function resources(platform,work,request,options){",
   " const owner=await import('./build.mjs');owner.checkWork(work);owner.platformContract(platform);",
   " if(refuse&&options.offline)throw Error('合成离线缺少锁定资源');",
   " return {schema:1,product_id:owner.contract.product_id,platform,work,offline:options.offline,request};",
   "}",
  ].join('\n');
  writeFixture(join(scripts,'resources.mjs'),provider);
  const env={HOME:area,LANG:'C',PATH:''},marker=join(work,'bootstrap.json');
  const options={cwd:source,env,input:'{}',encoding:'utf8',timeout:5000,maxBuffer:1024*1024};
  const check=(result,status)=>{
   assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status,status);
   assert.doesNotMatch(result.stderr,/unsettled top-level await/u);
  };
  // 普通模块导入不启动CLI；结果来自当前入口完整正文，不截取/重写其控制结构。
  const imported=spawnSync(process.execPath,['--input-type=module','--eval',
   "import {pathToFileURL} from 'node:url';await import(pathToFileURL("+JSON.stringify(file)+"));process.stdout.write('module-ready\\n');"],options);
  check(imported,0);assert.equal(imported.stdout,'module-ready\n');assert.deepEqual(readdirSync(work),[]);
  const input=JSON.stringify({schema:1,product_id:contract.product_id,platform,work});
  for(const offline of [false,true]){
   const result=spawnSync(process.execPath,[file,'resources',platform,'--work',work,...(offline?['--offline']:[])],{...options,input});
   check(result,0);
   assert.deepEqual(JSON.parse(result.stdout),{schema:1,product_id:contract.product_id,platform,work,offline,request:JSON.parse(input)});
  }
  // execute先真实完成反向导入和Node选择，再由原请求校验拒绝，不能以假Build成功代替。
  const invalid=spawnSync(process.execPath,[file,'execute',platform,'--work',work,'--offline'],{...options,input:'{"schema":99}'});
  check(invalid,1);assert.equal(invalid.stdout,'');assert.match(invalid.stderr,/公开Build请求身份或字段无效/u);
  assert.equal(existsSync(marker),false,'失败的真实入口必须清除引导材料');
  for(const extra of [['--offline','--offline'],['--unknown']]){
   const result=spawnSync(process.execPath,[file,'execute',platform,'--work',work,...extra],options);
   check(result,1);assert.equal(result.stdout,'');assert.match(result.stderr,/固定入口参数无效/u);assert.equal(existsSync(marker),false);
  }
  const malformed=spawnSync(process.execPath,[file,'resources',platform,'--work',work],{...options,input:'{'});
  check(malformed,1);assert.equal(malformed.stdout,'');assert.match(malformed.stderr,/SyntaxError/u);
  const unknown=spawnSync(process.execPath,[file,'resources','unknown','--work',work],options);
  check(unknown,1);assert.match(unknown.stderr,/平台未声明/u);
  writeFixture(join(scripts,'resources.mjs'),provider.replace('const refuse = false;','const refuse = true;'));
  for(const command of ['execute','resources']){
   const result=spawnSync(process.execPath,[file,command,platform,'--work',work,'--offline'],options);
   check(result,1);assert.equal(result.stdout,'');assert.match(result.stderr,/合成离线缺少锁定资源/u);
  }
  assert.equal(existsSync(join(work,'.product-build.lock')),false);
  assert.equal(existsSync(join(work,'build-result.json')),false);
 }finally{rmSync(area,{recursive:true,force:true});}
});

// 实际配置物化验证源不变及失败关闭，不以静态字符串替代Flutter的配置发现边界。
test('分析配置在派生工程根物化，缺件链接重复及覆盖均拒绝',()=>{
 const work=sandbox();try{
  const source=join(work,'source'),project=join(work,'view');mkdirSync(source);mkdirSync(project);mkdirSync(join(source,'scripts'));
  const file=join(source,'scripts/build.mjs'),output=join(project,'analysis_options.yaml');
  assert.throws(()=>materializeAnalysisOptions(source,project),/唯一普通源文件/);assert.equal(existsSync(output),false);
  const config=BUILD_SHELL_SOURCES.analysis,sourceBytes=readFileSync(fileURLToPath(import.meta.url));writeFixture(file,sourceBytes);
  assert.throws(()=>materializeAnalysisOptions(source,source),/派生工程/);
  assert.equal(materializeAnalysisOptions(source,project),output);assert.equal(readFileSync(output,'utf8'),config);assert.equal(existsSync(join(source,'analysis_options.yaml')),false);
  writeFixture(output,'existing');assert.throws(()=>materializeAnalysisOptions(source,project),/EEXIST/);assert.equal(readFileSync(output,'utf8'),'existing');
  rmSync(output);rmSync(file);symlinkSync(join(source,'scripts/missing'),file);assert.throws(()=>materializeAnalysisOptions(source,project),/唯一普通源文件/);assert.equal(existsSync(output),false);
  rmSync(file);writeFixture(file,sourceBytes);writeFixture(join(source,'analysis_options.yaml'),'duplicate');assert.throws(()=>materializeAnalysisOptions(source,project),/重复分析配置/);assert.equal(existsSync(output),false);
 }finally{removeFixture(work,{recursive:true,force:true});}
});

// 完整宿主通道由调用方核验结果并收尾；独立执行仍必须立即清空。
test('宿主完整Build在调用方消费前保留成功或失败现场，独立入口仍清空',async()=>{
 const {execute,outputDigest,clearWork}=await import('./build.mjs'),platform=Object.keys(contract.platforms)[0],declared=contract.platforms[platform];
 for(const [host,failure] of [['3',false],['3',true],['4',false],[undefined,false]]){
  const work=sandbox();try{
   let result;
   const stages={requirements:()=>{},resources:async()=>({}),prepare:async()=>{writeFixture(join(work,'partial'),'本轮现场');if(failure)throw Error('宿主失败夹具');},build:async()=>{
    result={schema:1,product_id:contract.product_id,platform,work,completion:declared.completion,run_id:'123456789',files:declared.files.map(name=>{const path=join(work,name);mkdirSync(dirname(path),{recursive:true});writeFixture(path,'当前产物');return {path,sha256:outputDigest(path)};})};return result;
   }};
   const pending=execute(platform,work,{run_id:'123456789'},{stages,environment:host?{PRODUCT_HOST_FD:host}:{}});
   if(failure)await assert.rejects(pending,/宿主失败夹具/);else assert.deepEqual(await pending,result);
   assert.equal(existsSync(join(work,'.product-build.lock')),false);
   if(host==='3'){
    assert.equal(existsSync(join(work,'partial')),true);
    if(!failure){assert.equal(existsSync(join(work,'build-result.json')),true);for(const file of result.files)assert.equal(outputDigest(file.path),file.sha256);}
    clearWork(work);
   }
   assert.deepEqual(readdirSync(work),[]);
  }finally{removeFixture(work,{recursive:true,force:true});}
 }
});

test('自有源码目录满足三级、单词命名和两个直接子项',()=>{
 const visit=(directory='',depth=0)=>{for(const entry of readdirSync(join(root,directory),{withFileTypes:true})){
  if(['.git','target'].includes(entry.name))continue;const path=directory?directory+'/'+entry.name:entry.name;
  if(entry.isDirectory()){assert.ok(depth+1<=3,path);assert.ok(entry.name==='.github'||/^[a-z]+$/u.test(entry.name),path);assert.ok(readdirSync(join(root,path)).length>=2,path);visit(path,depth+1);}else assert.ok(entry.isFile(),path);
 }};visit();
});

}
