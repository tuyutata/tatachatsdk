// 按官方要求或推荐实现；必需的工具依赖有就复用，没有就下载；使用最简单的实现方式；本脚本只允许放编译构建代码和注释，禁止增加无关内容，禁止增加复杂的校验阻断。
// config.mjs：只负责配置声明；build.mjs：只负责编译构建实现和必要注释；*.yml：负责全部GitHub流程，包括版本、作业编排、发布及历史清理。
import {spawn} from 'node:child_process';
import {mkdirSync,mkdtempSync,existsSync,readFileSync,writeFileSync,copyFileSync,cpSync,rmSync,realpathSync,lstatSync,readdirSync,rmdirSync,renameSync} from 'node:fs';
import {join,dirname,resolve,basename,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {homedir} from 'node:os';

export function sdkName(version){
 if(typeof version!=='string'||version.length>64||!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/u.test(version))throw Error('SDK版本无效');
 return '塔塔聊天·SDK·v'+version;
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
   if(failure||code!==0||termination||signal.aborted){const error=failure||Error(`${basename(command)}执行失败（${code??termination}）：${diagnostic.slice(-1000)}`);if(capture)error.testOutput=text;return fail(error);}
   ok(text.trim());
  });
 });
}
function buildEnvironment(work,cache){
 return {RUSTUP_TOOLCHAIN:tools.rust,CARGO_TARGET_DIR:process.env.CARGO_TARGET_DIR||cache.cargo,CARGO_INCREMENTAL:'1',TMPDIR:join(work,'tmp')+sep,
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
const analysisOptions='include: package:flutter_lints/flutter.yaml\nanalyzer:\n  exclude:\n    - storage/lib/chat_isar.g.dart\n    - build/**\n    - android/**\n    - ios/**\n  language:\n    strict-casts: true\n    strict-inference: true\n    strict-raw-types: true\nlinter:\n  rules:\n    - avoid_print\n    - directives_ordering\n    - unawaited_futures\n    - use_super_parameters\n';
export function analysisOptionsBytes(){return Buffer.from(analysisOptions);}
const layout=[['android/TataChatSdkPlugin.java','android/src/main/java/chat/tata/sdk/TataChatSdkPlugin.java'],['android/AndroidManifest.xml','android/src/main/AndroidManifest.xml']];
function platformInput(source,flat,standard){
 const found=[flat,standard].filter(path=>existsSync(join(source,path)));if(found.length!==1)throw Error('SDK平台输入缺失或重复');return found[0];
}
// 正式源只读收集根层真实包声明，不启动Dart/Pub，不生成工具状态。
export function workspacePackages(source){
 const paths=[source,...readdirSync(source,{withFileTypes:true}).filter(item=>item.isDirectory()&&item.name!=='target'&&existsSync(join(source,item.name,'pubspec.yaml'))).map(item=>join(source,item.name))];
 const packages=paths.map(path=>{
  if(realpathSync(path)!==path)throw Error('SDK包目录经过链接');
  const name=/^name:\s*([a-z][a-z0-9_]*)\s*$/mu.exec(readFileSync(join(path,'pubspec.yaml'),'utf8'))?.[1];
  if(!name)throw Error('SDK包声明缺少有效名称');return {name,path};
 });
 if(new Set(packages.map(item=>item.name)).size!==packages.length)throw Error('SDK包名重复');
 return packages;
}
// 只在已经装配的独占工程调用官方workspace命令，核对真实成员和声明归属。
async function verifyWorkspace(project,env){
 const dart=join(process.env.FLUTTER_ROOT||join(root,'target/cache/flutter'),'bin/cache/dart-sdk/bin/dart');
 const actual=JSON.parse(await run(dart,['pub','workspace','list','--json'],{cwd:project,env,capture:true})).packages;
 const expected=workspacePackages(project);
 if(actual.length!==expected.length||expected.some(item=>!actual.some(value=>value.name===item.name&&resolve(value.path)===item.path)))throw Error('SDK workspace声明与实际包目录不一致');
 return expected;
}
// 源码验收包含隐藏目录；只排除本产品根层target和Git元数据。
export function assertNoDartTool(source){
 function visit(folder){
  for(const item of readdirSync(folder,{withFileTypes:true})){
   if(item.name==='.dart_tool')throw Error('源码或交付残留.dart_tool：'+join(folder,item.name));
   if(folder===source&&['target','.git'].includes(item.name))continue;
   if(item.isDirectory())visit(join(folder,item.name));
  }
 }
 visit(source);return source;
}
// 官方工具的状态只允许出现在临时工程，交付前按准确目录移除。
export function removeGeneratedTools(project){
 function visit(folder){
  for(const item of readdirSync(folder,{withFileTypes:true})){
   const path=join(folder,item.name);
   if(item.name==='.dart_tool')rmSync(path,{recursive:true,force:true});
   else if(item.isDirectory())visit(path);
  }
 }
 visit(project);assertNoDartTool(project);
}
// 同一个公开布局接口装配源码与完整交付包，不保留旧路径转发。
export function createFlutterSourceView(source,output){
 if(realpathSync(source)!==source||resolve(output)!==output||source===output||output.startsWith(source+sep)&&!output.startsWith(join(source,'target')+sep))throw Error('SDK工程目录无效');
 const members=workspacePackages(source).filter(item=>item.path!==source);
 if(existsSync(join(source,'test')))throw Error('正式源根目录禁止test');
 if(existsSync(output))throw Error('SDK工程目标已存在');mkdirSync(output,{recursive:true});
 for(const name of ['lib','native','ios','android','scripts','pubspec.yaml','pubspec.lock','README.md','LICENSE',...members.map(item=>item.path.slice(source.length+1))]){
  cpSync(join(source,name),join(output,name),{recursive:true,filter:path=>!['target','.git','.dart_tool','build','.gradle'].includes(basename(path))});
 }
 for(const [flat,to]of layout){const from=platformInput(source,flat,to);if(from===to)continue;mkdirSync(dirname(join(output,to)),{recursive:true});copyFileSync(join(output,from),join(output,to));rmSync(join(output,from));}
 writeFileSync(join(output,'analysis_options.yaml'),analysisOptionsBytes());return output;
}
export function assertFlutterSourceView(source,output){
 if(realpathSync(source)!==source||realpathSync(output)!==output||source===output)throw Error('SDK工程目录无效');
 for(const [flat,to]of layout){const from=platformInput(source,flat,to);if(existsSync(join(output,flat))||!readFileSync(join(source,from)).equals(readFileSync(join(output,to))))throw Error('SDK Flutter布局与本仓输入不一致');}
 const members=workspacePackages(source).filter(item=>item.path!==source);
 for(const name of ['pubspec.yaml','pubspec.lock','native/tatachat_sdk.h',...members.map(item=>join(item.path.slice(source.length+1),'pubspec.yaml'))])if(!readFileSync(join(source,name)).equals(readFileSync(join(output,name))))throw Error('SDK工程声明漂移');
 for(const item of members)if(!existsSync(join(output,item.path.slice(source.length+1),'lib')))throw Error('SDK交付缺少成员源码');
 if(existsSync(join(output,'test')))throw Error('SDK交付根目录禁止test');
 if(!existsSync(join(output,'lib/test/build.test.mjs')))throw Error('SDK交付缺少lib测试入口');
 if(!existsSync(join(output,'assets/stickers')))throw Error('SDK交付缺少贴纸资源');
 if(!readFileSync(join(output,'analysis_options.yaml')).equals(analysisOptionsBytes()))throw Error('SDK分析配置漂移');return output;
}
// 正式源与交付保留lib/test；仅独占验证工程映射到Flutter标准测试位置。
export function prepareTestLayout(project){
 if(realpathSync(project)===realpathSync(root))throw Error('禁止在正式源调整工具测试布局');
 const source=join(project,'lib/test'),output=join(project,'test');
 const entries=readdirSync(source,{withFileTypes:true}).filter(item=>item.isDirectory()||item.name.endsWith('.dart')).map(item=>item.name);mkdirSync(output,{recursive:true});
 for(const name of entries)if(existsSync(join(output,name)))throw Error('测试布局存在重复输入');
 for(const name of entries)renameSync(join(source,name),join(output,name));
 return output;
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
async function nativeTarget(target,work,env,version,device=false){
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
  // 当前真机安装只构建真机切片；正式SDK仍交付原有完整XCFramework。
  for(const [triple,sdk,key]of [['aarch64-apple-ios','iphoneos','CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS'],['aarch64-apple-ios-sim','iphonesimulator','CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS']].filter((_,index)=>!device||index===0)){
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
 assertNoDartTool(root);
 const work=taskDirectory('test'),cache=claimCache(work);mkdirSync(join(work,'tmp'));
 const env=buildEnvironment(work,cache);let safe=true;
 try{
  const flutter=await flutterCheck(env),project=sourceView(work);
  await run(process.execPath,['--test',join(project,'lib/test/build.test.mjs'),join(project,'lib/test/runner.test.mjs')],{cwd:project,env});
  const testPath=prepareTestLayout(project);
  await run('cargo',['test','--locked','--manifest-path',manifest],{env});
  const output=await nativeTarget('macos',work,env,'1.0.0');
  await run(flutter,['pub','get','--enforce-lockfile',...(process.env.PUB_OFFLINE==='true'?['--offline']:[])],{cwd:project,env});
  const config=JSON.parse(readFileSync(join(project,'.dart_tool/package_config.json'),'utf8'));
  const entry=config.packages.find(value=>value.name==='isar_community_flutter_libs');if(!entry)throw Error('Pub原锁缺少Isar原生包');
  const packageRoot=fileURLToPath(new URL(entry.rootUri,new URL('file://'+join(project,'.dart_tool/package_config.json'))));
  const isar=join(work,'libisar.dylib');copyFileSync(join(packageRoot,'macos/libisar.dylib'),isar);
  const testEnv={...env,FLUTTER_ROOT:dirname(dirname(flutter)),FLUTTER_TEST:'true',TATACHATSDK_TEST_WORK_ROOT:work,TATACHATSDK_TEST_NATIVE_LIBRARY:join(output,'libtatachat_sdk.dylib'),ISAR_CORE_LIB_PATH:isar};
  const packages=await verifyWorkspace(project,testEnv);
  await run(flutter,['analyze','--fatal-infos'],{cwd:project,env:testEnv});
  const {runWorkspaceTests}=await import('../lib/test/run.mjs');
  await runWorkspaceTests({project,flutter,env:testEnv,run,packages:packages.map(item=>item.path===project?{...item,testPath}:item)});
 }catch(error){safe=!error.keepWork;throw error;}finally{if(safe){cache.release();rmSync(work,{recursive:true,force:true});assertNoDartTool(root);}}
}
export function setPackageVersion(project,version){
 sdkName(version);
 for(const [file,pattern,text]of [
  ...workspacePackages(project).map(item=>[join(item.path.slice(project.length+1),'pubspec.yaml'),/^version: .+$/mu,'version: '+version]),
  ['ios/tatachat_sdk.podspec',/spec\.version = '[^']*'/u,"spec.version = '"+version+"'"],
  ['android/build.gradle.kts',/^version = "[^"]*"$/mu,'version = "'+version+'"'],
 ]){const path=join(project,file),before=readFileSync(path,'utf8');if(!pattern.test(before))throw Error('SDK版本声明缺失：'+file);writeFileSync(path,before.replace(pattern,text));}
}
export async function buildSDK({target,version=process.env.SDK_VERSION||/^version: (\S+)$/mu.exec(readFileSync(join(root,'pubspec.yaml'),'utf8'))?.[1],device=false}={}){
 assertNoDartTool(root);sdkName(version);const work=taskDirectory('build'),cache=claimCache(work);mkdirSync(join(work,'tmp'));let completed=false,safe=true;
 try{
  const env=buildEnvironment(work,cache);for(const value of target?[target]:['android','ios','macos'])await nativeTarget(value,work,env,version,device);
  if(target){completed=true;return {work,output:join(work,'native',target)};}
  const project=sourceView(work);
  rmSync(join(project,'ios/TataChatSDK.xcframework'),{recursive:true,force:true});
  cpSync(join(work,'native/ios/TataChatSDK.xcframework'),join(project,'ios/TataChatSDK.xcframework'),{recursive:true});
  cpSync(join(work,'native/android'),join(project,'android/src/main/jniLibs'),{recursive:true});
  copyFileSync(join(work,'native/macos/libtatachat_sdk.dylib'),join(project,'native/libtatachat_sdk.dylib'));
  await verifyWorkspace(project,env);
  setPackageVersion(project,version);
  removeGeneratedTools(project);
  for(const entry of readdirSync(work))if(entry!=='project')rmSync(join(work,entry),{recursive:true,force:true});
  assertNoDartTool(root);completed=true;return {work,output:project};
 }catch(error){safe=!error.keepWork;throw error;}finally{if(safe){cache.release();if(!completed)rmSync(work,{recursive:true,force:true});}}
}
export async function protocol(){
 const protoc=process.env.PROTOC,plugin=process.env.PROTOC_GEN_DART;
 if(!protoc?.startsWith('/')||!plugin?.startsWith('/'))throw Error('协议生成须显式提供官方protoc及Dart插件绝对路径');
 if(await run(protoc,['--version'],{capture:true})!=='libprotoc '+tools.protoc)throw Error('protoc版本不符');
 const work=taskDirectory('build'),output=join(work,'protocol');mkdirSync(output);
 try{await run(protoc,['--proto_path='+join(root,'protocol/proto'),'--dart_out='+output,'--plugin=protoc-gen-dart='+plugin,...['basic_content','media_content','message','attachment','chat_frame'].map(name=>join(root,'protocol/proto',name+'.proto'))]);return {work,output};}
 catch(error){if(!error.keepWork)rmSync(work,{recursive:true,force:true});throw error;}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)&&!process.env.NODE_TEST_CONTEXT){
 for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>controller.abort());
 try{
  const [command,...args]=process.argv.slice(2);
  if(process.versions.node!==tools.node)throw Error('Node版本与本产品声明不一致');
  if(command==='test')await testSDK();
  else if(command==='protocol')console.log(JSON.stringify(await protocol()));
  else if(command==='native')console.log(JSON.stringify(await buildSDK({target:args[0],device:args.includes('--device')})));
  else if(!command){const result=await buildSDK();console.log(JSON.stringify(result));}
  else throw Error('用法：node scripts/build.mjs [test|native android/ios/macos|protocol]');
 }catch(error){console.error(error.message);process.exitCode=1;}
}
