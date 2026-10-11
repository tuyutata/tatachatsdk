#!/usr/bin/env node
import {readFileSync as tataGateRead, realpathSync as tataGateReal} from 'node:fs';
import {execFileSync as tataGateExec} from 'node:child_process';
export const tataGateOwner = "tuyutata/tatachatsdk";
import { lstatSync, readFileSync, readdirSync, realpathSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { extname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const productRoot = realpathSync(fileURLToPath(new URL('../../', import.meta.url)));
const declarationPath = join(productRoot, '.github/tatagate/tatagate.json');
const fail = message => { throw new Error('本仓塔塔门禁：' + message); };
const sha = /^[0-9a-f]{40}$/u;
const obsolete = new RegExp('scripts/' +
  '(?:' + ['flow.mjs', 'flows.json', 'resources.mjs', 'target.mjs',
    'dependencies.mjs', 'dependencies.json', 'release.mjs', 'build-native.sh']
    .map(value => value.replaceAll('.', '[.]')).join('|') + ')', 'u');

function ordinary(path) {
  const info = lstatSync(path);
  if (!info.isFile() || info.isSymbolicLink() || realpathSync(path) !== path || info.size === 0) {
    fail('检查输入不是非空普通文件：' + path);
  }
  return path;
}

function ownedPath(root, path) {
  if (typeof path !== 'string' || !path || isAbsolute(path) || path.includes('\\')
      || path.split('/').some(part => !part || part === '.' || part === '..')) {
    fail('登记路径无效');
  }
  const result = resolve(root, path), part = relative(root, result);
  if (!part || part === '..' || part.startsWith('..' + sep) || isAbsolute(part)) fail('登记路径越界');
  return ordinary(result);
}

function exactDirectory(root, path, names) {
  const directory = resolve(root, path), info = lstatSync(directory);
  if (!info.isDirectory() || info.isSymbolicLink() || realpathSync(directory) !== directory) {
    fail('目录不是本仓真实目录：' + path);
  }
  const found = readdirSync(directory).sort();
  if (JSON.stringify(found) !== JSON.stringify([...names].sort())) fail('目录文件闭集不符：' + path);
  for (const name of names) ordinary(join(directory, name));
}

function git(root, args, { statuses = [0] } = {}) {
  const allowed = new Set(['rev-parse', 'remote', 'merge-base', 'diff', 'ls-files']);
  if (!allowed.has(args[0])) fail('拒绝非只读Git命令');
  const gitBin = process.env.PRODUCT_GIT_BIN || '/usr/bin/git';
  if (typeof gitBin !== 'string' || !isAbsolute(gitBin)) fail('只读Git入口无效');
  const gitInfo = lstatSync(gitBin);
  if (!gitInfo.isFile() || gitInfo.isSymbolicLink()
      || !(gitInfo.mode & 0o111) || realpathSync(gitBin) !== gitBin) fail('只读Git入口无效');
  const commandArgs = args[0] === 'diff' ? ['diff', '--no-ext-diff', ...args.slice(1)] : args;
  const result = spawnSync(gitBin, ['--no-optional-locks', '-c', 'core.fsmonitor=false', '-C', root, ...commandArgs], {
    encoding: 'utf8', timeout: 30000, maxBuffer: 32 * 1024 * 1024,
    env: { ...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null',
      GIT_TERMINAL_PROMPT: '0' },
  });
  if (result.error || !statuses.includes(result.status) || result.signal) fail('只读Git检查失败');
  return result;
}

export function gateContract() {
  const value = JSON.parse(readFileSync(ordinary(declarationPath), 'utf8'));
  if (value.schema !== 1 || value.repository !== 'tatachatsdk'
      || value.github_repository !== 'tuyutata/tatachatsdk'
      || Object.hasOwn(value, 'tools')
      || JSON.stringify(value.workflows) !== JSON.stringify(['release-sdk.yml'])
      || JSON.stringify(value.node_tests) !== JSON.stringify([
        'scripts/build.mjs', 'scripts/publish.mjs', '.github/workflows/release-sdk.mjs'
      ]) || !Array.isArray(value.functions) || value.functions.length === 0) {
    fail('门禁登记身份或入口无效');
  }
  return value;
}

export function validateRepositoryIdentity(root) {
  if (root !== productRoot || realpathSync(root) !== root) fail('只接受本产品真实根');
  const origin = git(root, ['remote', 'get-url', 'origin']).stdout.trim();
  if (origin !== 'https://github.com/tuyutata/tatachatsdk.git') fail('所属HTTPS仓库身份无效');
  if (!tataGateBranch(root)) {
    fail('只接受本仓main');
  }
  return true;
}

export function validateRange({ root, baseSHA, headSHA }) {
  if (!sha.test(baseSHA || '') || !sha.test(headSHA || '')) fail('提交范围坐标无效');
  if (git(root, ['rev-parse', 'HEAD']).stdout.trim() !== headSHA) fail('门禁提交不是当前HEAD');
  if (git(root, ['merge-base', '--is-ancestor', baseSHA, headSHA], { statuses: [0, 1] }).status !== 0) {
    fail('基线不是本次提交祖先');
  }
  return true;
}

function trackedFiles(root) {
  return git(root, ['ls-files', '-z']).stdout.split('\0').filter(Boolean);
}

export function validateNodeInventory(paths, registered) {
  if (!Array.isArray(paths) || !Array.isArray(registered)
      || new Set(registered).size !== registered.length) fail('Node测试登记重复或无效');
  for (const path of registered) {
    if (!paths.includes(path)) fail('Node测试登记遗漏实际源码：' + path);
    const source = readFileSync(ownedPath(productRoot, path), 'utf8');
    if (!/\btest\s*\(/u.test(source)) fail('登记的Node文件缺少真实测试：' + path);
  }
  return [...registered].sort();
}

export function validateWorkflowSource(source, filename) {
  if (filename !== 'release-sdk.yml' || !source.includes('name: tatachatsdk.sdk')
      || !source.includes('workflow_dispatch:') || /^\s*(?:push|pull_request|workflow_run):/mu.test(source)
      || !source.includes('cancel-in-progress: false') || !source.includes('queue: max')
      || !source.includes('always()') || !source.includes('.github/workflows/release-sdk.mjs')) {
    fail('所属自动化身份或只读登记无效');
  }
  return filename;
}

export function validatePlatformNaming(root) {
  const values = gateContract().platform_forbidden_values;
  if (!Array.isArray(values) || values.length === 0 || values.some(value => typeof value !== 'string' || !value)) {
    fail('平台禁用名称声明无效');
  }
  for (const path of trackedFiles(root)) {
    if (values.some(value => path.includes(value))) fail('源码路径保留禁用平台名：' + path);
  }
  return true;
}

export function lexicalParts(path, source) {
  const extension=extname(path).toLowerCase(), javascript=['.js','.jsx','.mjs','.ts','.tsx'].includes(extension);
  const comments=[], code=source.split('');let index=0;
  const blank=(begin,end)=>{for(let at=begin;at<end;at++)if(source[at]!=='\n'&&source[at]!=='\r')code[at]=' ';};
  const quote=(delimiter,triple=false,interpolated=false)=>{
    const size=triple?3:1;blank(index,index+size);index+=size;
    while(index<source.length){
      if(source[index]==='\\'){blank(index,index+2);index+=2;continue;}
      if(interpolated&&source.startsWith('${',index)){blank(index,index+2);index+=2;scan(true);continue;}
      if(source.startsWith(delimiter.repeat(size),index)){blank(index,index+size);index+=size;return;}
      blank(index,index+1);index++;
    }
  };
  const scan=(interpolation=false)=>{
    let previous='',word='',depth=1;
    while(index<source.length){
      const value=source[index];
      if(/\s/u.test(value)){index++;continue;}
      if(interpolation&&value==='}'){if(--depth===0){blank(index,index+1);index++;return;}index++;previous='}';continue;}
      if(interpolation&&value==='{')depth++;
      const lineComment=(['.py','.sh'].includes(extension)&&value==='#'&&!source.startsWith('#!',index))
        ||extension==='.sql'&&source.startsWith('--',index)
        ||!['.py','.sh','.sql'].includes(extension)&&source.startsWith('//',index);
      if(lineComment){const begin=index,end=source.indexOf('\n',index);index=end<0?source.length:end;comments.push(source.slice(begin,index));blank(begin,index);continue;}
      if(!['.py','.sh'].includes(extension)&&source.startsWith('/*',index)){
        const begin=index;let nested=1;index+=2;
        while(index<source.length&&nested){if(extension==='.rs'&&source.startsWith('/*',index)){nested++;index+=2;}else if(source.startsWith('*/',index)){nested--;index+=2;}else index++;}
        comments.push(source.slice(begin,index));blank(begin,index);continue;
      }
      if(extension==='.rs'){
        const raw=/^(?:b)?r(#+)?"/u.exec(source.slice(index));
        if(raw){const begin=index,close='"'+(raw[1]||''),end=source.indexOf(close,index+raw[0].length);index=end<0?source.length:end+close.length;blank(begin,index);previous='literal';continue;}
        if(value==="'"&&!/^'(?:\\(?:u\{[0-9a-fA-F]+\}|x[0-9a-fA-F]{2}|.)|[^'\\\n])'/u.test(source.slice(index))){index++;previous=value;continue;}
      }
      if(value==='"'||value==="'"||value==='`'){
        quote(value,['.dart','.py'].includes(extension)&&source.startsWith(value.repeat(3),index),javascript&&value==='`'||extension==='.dart'&&source[index-1]!=='r');previous='literal';word='';continue;
      }
      if(javascript&&value==='/'&&(!previous||/[=(:,!\[{};?]/u.test(previous)||['return','throw','yield','case'].includes(word))){
        const begin=index++;let bracket=false;
        while(index<source.length){const current=source[index++];if(current==='\\'){index++;continue;}if(current==='[')bracket=true;else if(current===']')bracket=false;else if(current==='/'&&!bracket)break;else if(current==='\n')break;}
        while(/[a-z]/iu.test(source[index]||''))index++;blank(begin,index);previous='literal';word='';continue;
      }
      if(/[A-Za-z_$]/u.test(value)){const begin=index++;while(/[A-Za-z0-9_$]/u.test(source[index]||''))index++;word=source.slice(begin,index);previous='word';continue;}
      previous=value;word='';index++;
    }
  };
  scan();return {comments:comments.join('\n'),code:code.join('')};
}

export function hasSecretMaterial(source) {
  if (typeof source !== 'string') fail('机密扫描输入必须是文本');
  const token = /AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|sk_live_[A-Za-z0-9]{16,}/u;
  if (token.test(source)) return true;
  for (const match of source.matchAll(/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s+([A-Za-z0-9+/=\s]+)/gu)) {
    if (match[1].replace(/\s/gu, '').length >= 32) return true;
  }
  return false;
}

function inspectSource(root, paths) {
  const exclusions = [/^lib\/protocol\/.*\.pb/u, /^stickers\//u];
  for (const path of paths) {
    if (exclusions.some(pattern => pattern.test(path)) || !/\.(?:mjs|js|dart|rs|md|json|yml|yaml|sh)$/u.test(path)) continue;
    const file = ownedPath(root, path), bytes = readFileSync(file);
    if (bytes.length > 2 * 1024 * 1024) fail('源码检查输入超限：' + path);
    const source = bytes.toString('utf8');
    if (hasSecretMaterial(source)) fail('源码包含机密材料，仅报告路径：' + path);
    if (path !== '.github/tatagate/tatagate.mjs' && obsolete.test(source)) {
      fail('源码保留已删除入口：' + path);
    }
    if (!path.startsWith('test/') && !path.startsWith('lib/protocol/')
        && /(?:TODO|FIXME|HACK|XXX)\b/u.test(lexicalParts(path, source).comments)) {
      fail('第一方实现保留临时注释：' + path);
    }
  }
}

function validateFunctionInventory(root, paths, functions) {
  const seen = new Set();
  for (const item of functions) {
    if (!item || typeof item.function !== 'string' || typeof item.path !== 'string'
        || !['cargo', 'flutter', 'node'].includes(item.runner)
        || seen.has(item.path) || !paths.includes(item.path)) fail('功能来源登记遗漏或重复');
    seen.add(item.path);
    const source = readFileSync(ownedPath(root, item.path), 'utf8');
    if (item.runner === 'cargo' && (!Array.isArray(item.cases) || !item.cases.length
        || item.cases.some(name => typeof name !== 'string' || !source.includes(name)))) {
      fail('Rust用例登记与源码不符');
    }
  }
  return seen.size;
}

export function validateGateRequestWork(root, work) {
  const expected = join(root, 'target/test');
  if (work !== expected) fail('只读门禁工作参数不是本产品固定路径');
  return expected;
}

export function repositoryGateMain(args) {
  tataGateValidateWorkflow(tataGateRead(productRoot+'/.github/workflows/tatagate.yml','utf8'));
  const [mode, root, baseSHA, headSHA, work] = args;
  if (!['physical', 'local'].includes(mode) || root !== productRoot
      || mode === 'physical' && args.length !== 2
      || mode === 'local' && args.length !== 5) fail('只读门禁入口参数无效');
  validateRepositoryIdentity(root);
  exactDirectory(root, 'scripts', ['build.mjs', 'publish.mjs']);
  exactDirectory(root, '.github/workflows', ['release-sdk.yml', 'release-sdk.mjs', 'tatagate.yml']);
  exactDirectory(root, '.github/tatagate', ['tatagate.json', 'tatagate.mjs']);
  const declaration = gateContract();
  validateWorkflowSource(readFileSync(ownedPath(root, '.github/workflows/release-sdk.yml'), 'utf8'), 'release-sdk.yml');
  ownedPath(root, 'TataChatSDK.md');
  if (mode === 'local') {
    validateGateRequestWork(root, work);
    validateRange({root, baseSHA, headSHA});
    if (git(root, ['diff', '--quiet'], {statuses:[0,1]}).status !== 0
        || git(root, ['diff', '--cached', '--quiet'], {statuses:[0,1]}).status !== 0
        || git(root, ['ls-files', '--others', '--exclude-standard']).stdout.trim()) {
      fail('只接受干净的已保存提交');
    }
    const paths = trackedFiles(root);
    validateNodeInventory(paths, declaration.node_tests);
    validateFunctionInventory(root, paths, declaration.functions);
    validatePlatformNaming(root);
    inspectSource(root, paths);
  }
  return Object.freeze({repository:declaration.repository, mode, head_sha:mode==='local'?headSHA:null});
}

if (!['github','cleanup'].includes(process.argv[2]) && !(process.env.NODE_TEST_CONTEXT && process.argv.length===2) && process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.stdout.write(JSON.stringify(repositoryGateMain(process.argv.slice(2))) + '\n'); }
  catch (error) {
    console.error(error?.message?.startsWith('本仓塔塔门禁：') ? error.message : '本仓塔塔门禁：只读检查失败');
    process.exitCode = 1;
  }
}

// GitHub入口和清理只处理本仓tatagate.yml；产品检查仍由本仓原有实现执行。
export function tataGateBranch(repositoryRoot) {
  if (process.env.GITHUB_ACTIONS === 'true') { tataGateContext(repositoryRoot); return true; }
  return tataGateExec(process.env.PRODUCT_GIT_BIN || '/usr/bin/git', ['-C',repositoryRoot,'branch','--show-current'], {encoding:'utf8'}).trim() === 'main';
}
export function tataGateContext(repositoryRoot, input=process.env, event=JSON.parse(tataGateRead(input.GITHUB_EVENT_PATH,'utf8'))) {
  if (input.GITHUB_ACTIONS !== 'true' || input.GITHUB_EVENT_NAME !== 'push'
    || input.GITHUB_REPOSITORY !== tataGateOwner || input.GITHUB_REF !== 'refs/heads/main'
    || input.GITHUB_WORKSPACE !== repositoryRoot || tataGateReal(repositoryRoot) !== repositoryRoot
    || event.repository?.full_name !== tataGateOwner || event.ref !== input.GITHUB_REF
    || event.deleted === true || event.after !== input.GITHUB_SHA
    || !/^[a-f0-9]{40}$/u.test(event.after || '') || !/^[a-f0-9]{40}$/u.test(event.before || '')
    || event.before === event.after || input.GITHUB_WORKFLOW_REF!==tataGateOwner+'/.github/workflows/tatagate.yml@refs/heads/main') {
    throw Error('本仓塔塔门禁GitHub事件身份无效');
  }
  const git=input.PRODUCT_GIT_BIN || '/usr/bin/git';
  const read=args=>tataGateExec(git,['-c','core.hooksPath=/dev/null','-C',repositoryRoot,...args],{encoding:'utf8'}).trim();
  if (read(['rev-parse','HEAD']) !== event.after || read(['rev-parse','--show-toplevel']) !== repositoryRoot
    || read(['remote','get-url','--all','origin']) !== 'https://github.com/'+tataGateOwner+'.git') {
    throw Error('本仓塔塔门禁GitHub提交或来源无效');
  }
  if(read(['status','--porcelain=v1','--untracked-files=all']))throw Error('本仓塔塔门禁GitHub检出存在未提交改动');
  if(input.GITHUB_JOB==='gate'&&event.before!=='0'.repeat(40)){
    try{tataGateExec(git,['-C',repositoryRoot,'merge-base','--is-ancestor',event.before,event.after],{encoding:'utf8',stdio:'pipe'});}catch{throw Error('本仓塔塔门禁GitHub提交范围不是快进祖先');}
  }
  return {...event,before:event.before === '0'.repeat(40) ? '4b825dc642cb6eb9a060e54bf8d69288fbee4904' : event.before};
}
export function tataGateValidateWorkflow(source) {
  const jobs=source?.slice(source.indexOf('\njobs:\n')).match(/^  [a-z][a-z0-9_]*:$/gmu);
  const entry=new URL(import.meta.url).pathname.split('/').at(-1);
  const gate=source?.split('  gate:\n')[1]?.split('\n  cleanup:')[0];
  if(!gate||/^    continue-on-error:/mu.test(gate)||!source.includes('permissions:\n  contents: read\n'))throw Error('本仓塔塔门禁检查权限或结果处理无效');
  if(JSON.stringify(jobs)!==JSON.stringify(['  gate:','  cleanup:'])||!source.includes('run: node .github/tatagate/'+entry+' github\n')||!source.includes('run: node .github/tatagate/'+entry+' cleanup\n'))throw Error('本仓塔塔门禁Job或执行入口无效');
  if (typeof source !== 'string' || !source.startsWith('name: '+tataGateOwner.split('/')[1]+'.tatagate\n')
    || !/^  push:\n    branches: \[main\]$/mu.test(source)
    || /^\s*(?:workflow_run|workflow_dispatch|schedule|pull_request):/mu.test(source)
    || !source.includes('group: "${{ github.repository }}-tatagate"')
    || !/^  cancel-in-progress: false$/mu.test(source) || !/^  queue: max$/mu.test(source)
    || !/^  gate:$/mu.test(source) || !/^  cleanup:$/mu.test(source)
    || !/^    needs: \[gate\]$/mu.test(source) || !source.includes('if: ${{ always() }}')
    || !/^    continue-on-error: true$/mu.test(source)
    || !source.includes('TATAGATE_RESULT: "${{ needs.gate.result }}"')
    || !source.includes('persist-credentials: false')
    || !source.includes(' github\n') || !source.includes(' cleanup\n')) throw Error('本仓塔塔门禁Workflow合同无效');
  return true;
}
function tataGateWorkflowRun(run) {
  return Number.isSafeInteger(run?.id) && run.id>0 && Number.isSafeInteger(run.run_number) && run.run_number>0
    && Number.isSafeInteger(run.run_attempt) && run.run_attempt>0
    && run.path === '.github/workflows/tatagate.yml' && run.event === 'push' && run.head_branch === 'main'
    && run.repository?.full_name === tataGateOwner && /^[a-f0-9]{40}$/u.test(run.head_sha || '')
    && Number.isFinite(Date.parse(run.created_at));
}
export function tataGateCleanupPlan(rows,current,result) {
  if (!['success','failed'].includes(result) || !tataGateWorkflowRun(current) || !Array.isArray(rows)) throw Error('本仓塔塔门禁清理身份无效');
  return rows.filter(run=>tataGateWorkflowRun(run) && run.status==='completed' && typeof run.conclusion==='string'
    && run.id!==current.id && run.run_number<current.run_number
    && (run.conclusion==='success'?'success':'failed')===result).sort((a,b)=>a.run_number-b.run_number);
}
async function tataGateAPI(path,{method='GET',fetchImpl=fetch,token=process.env.GH_TOKEN}={}) {
  if (typeof token!=='string' || !token || typeof path!=='string' || path.includes('..') || path.startsWith('/') || /[\r\n]/u.test(path)) throw Error('本仓塔塔门禁API参数无效');
  let response;
  try {response=await fetchImpl('https://api.github.com/repos/'+tataGateOwner+'/'+path,{method,redirect:'error',
    headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2026-03-10','User-Agent':'TataGate'},
    signal:AbortSignal.timeout(30000)});}catch{throw Error('本仓塔塔门禁API连接未确认');}
  if(response.status===404 && method==='GET')return null;
  if(!response.ok)throw Error('本仓塔塔门禁API失败：HTTP '+response.status);
  if(response.status===204)return null;
  let size=0;const parts=[];
  if(!response.body)throw Error('本仓塔塔门禁API回执缺失');
  for await(const chunk of response.body){size+=chunk.length;if(size>8*1024**2)throw Error('本仓塔塔门禁API回执超限');parts.push(chunk);}
  try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(parts)));}catch{throw Error('本仓塔塔门禁API回执无效');}
}
async function tataGateHistory(current,api) {
  const read=async(start,end)=>{
    const query='actions/workflows/tatagate.yml/runs?event=push&branch=main&status=completed&created='+encodeURIComponent(new Date(start).toISOString().slice(0,19)+'Z..'+new Date(end).toISOString().slice(0,19)+'Z');
    const first=await api(query+'&per_page=100&page=1');
    if(!Number.isSafeInteger(first?.total_count)||!Array.isArray(first.workflow_runs))throw Error('本仓塔塔门禁历史清单无效');
    if(first.total_count>1000){const middle=Math.floor((start+end)/2000)*1000;if(middle<=start||middle>=end)throw Error('本仓塔塔门禁历史超过同秒上限');return [...await read(start,middle),...await read(middle+1000,end)];}
    const rows=[...first.workflow_runs];
    for(let page=2;rows.length<first.total_count;page++){const value=await api(query+'&per_page=100&page='+page);if(!Array.isArray(value?.workflow_runs)||!value.workflow_runs.length)throw Error('本仓塔塔门禁历史分页不完整');rows.push(...value.workflow_runs);}
    return rows;
  };
  const rows=await read(Date.UTC(2008,0,1),Math.floor(Date.parse(current.created_at)/1000)*1000);
  return [...new Map(rows.map(run=>[run.id,run])).values()];
}
export async function tataGateCleanup(result,identity,api=tataGateAPI) {
  const current=await api('actions/runs/'+identity.id);
  if(identity.attempt!==undefined&&current?.run_attempt!==identity.attempt)throw Error('本仓塔塔门禁当前Attempt不符');
  if(!tataGateWorkflowRun(current)||current.id!==identity.id||current.head_sha!==identity.sha)throw Error('本仓塔塔门禁当前Run回读无效');
  const plan=tataGateCleanupPlan(await tataGateHistory(current,api),current,result),removed=[];
  for(const candidate of plan){
    const path='actions/runs/'+candidate.id;
    const latest=await api('actions/runs/'+current.id);
    if(!latest||latest.head_sha!==current.head_sha||latest.run_attempt!==current.run_attempt)throw Error('本仓塔塔门禁当前Run已变化');
    const again=await api(path);
    if(again===null){removed.push(candidate.id);continue;}
    if(again.run_attempt!==candidate.run_attempt||again.conclusion!==candidate.conclusion
      ||tataGateCleanupPlan([again],current,result).length!==1)throw Error('本仓塔塔门禁旧Run已变化，停止清理');
    try{await api(path,{method:'DELETE'});}catch(error){if(await api(path)!==null)throw error;}
    if(await api(path)!==null)throw Error('本仓塔塔门禁旧Run删除回查失败');
    removed.push(candidate.id);
  }
  return removed;
}
export async function tataGateCommand(mode) {
  const {fileURLToPath}=await import('node:url'),{resolve}=await import('node:path');
  const repositoryRoot=resolve(fileURLToPath(new URL('../..',import.meta.url)));
  const event=tataGateContext(repositoryRoot);
  tataGateValidateWorkflow(tataGateRead(repositoryRoot+'/.github/workflows/tatagate.yml','utf8'));
  if(mode==='github'){if(process.env.GITHUB_JOB!=='gate')throw Error('本仓塔塔门禁Job身份无效');const receipt=await tataGateRunOwn(repositoryRoot,event);console.log(JSON.stringify({repository:tataGateOwner,source_sha:event.after,receipt}));return receipt;}
  if(process.env.GITHUB_JOB!=='cleanup')throw Error('本仓塔塔门禁清理Job身份无效');
  const result=process.env.TATAGATE_RESULT;
  if(!['success','failure','cancelled','skipped'].includes(result))throw Error('本仓塔塔门禁前置结果无效');
  const id=Number(process.env.GITHUB_RUN_ID);
  if(!Number.isSafeInteger(id)||id<=0)throw Error('本仓塔塔门禁Run编号无效');
  const jobs=await tataGateAPI('actions/runs/'+id+'/jobs?filter=latest&per_page=100');
  const gate=jobs?.jobs?.find(job=>job.name==='gate');
  if(gate?.status!=='completed'||typeof gate.conclusion!=='string'||(gate.conclusion==='success')!==(result==='success'))throw Error('本仓塔塔门禁前置结果与GitHub不一致');
  const removed=await tataGateCleanup(result==='success'?'success':'failed',{id,sha:event.after,attempt:Number(process.env.GITHUB_RUN_ATTEMPT)});
  const summary='塔塔门禁'+(result==='success'?'成功':'失败')+'；同类旧Run已清理：'+(removed.join('、')||'无')+'。\n';
  if(process.env.GITHUB_STEP_SUMMARY){const {appendFileSync}=await import('node:fs');appendFileSync(process.env.GITHUB_STEP_SUMMARY,summary);}
  console.log(summary.trim());
}
if(process.argv[1] && ['github','cleanup'].includes(process.argv[2]) && process.argv.length===3
  && new URL('file:'+process.argv[1]).href===import.meta.url){
  try{await tataGateCommand(process.argv[2]);}catch(error){console.error(error.message?.startsWith('本仓')?error.message:'本仓塔塔门禁执行失败');process.exitCode=1;}
}

async function tataGateRunOwn(repositoryRoot,event) {
  const receipt=await repositoryGateMain(['local',repositoryRoot,event.before,event.after,repositoryRoot+'/target/test']);
  const {spawnSync}=await import('node:child_process');
  const environment={...process.env};delete environment.NODE_TEST_CONTEXT;
  const result=spawnSync(process.execPath,['--test','--test-reporter=tap',import.meta.filename],{cwd:repositoryRoot,env:environment,encoding:'utf8',maxBuffer:8*1024**2});
  process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');
  if(result.error||result.signal||result.status!==0||!/^# tests [1-9][0-9]*$/mu.test(result.stdout||'')||!['fail','cancelled','skipped','todo'].every(name=>new RegExp('^# '+name+' 0$','mu').test(result.stdout||'')))throw Error('本仓塔塔门禁回归没有完整通过');
  return receipt;
}

// BEGIN INLINE TESTS
if(process.env.NODE_TEST_CONTEXT && process.argv.length===2 && process.argv[1]===import.meta.filename){
  const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict');
  test('塔塔门禁Workflow只允许本仓push，门禁和清理同处唯一文件',()=>{
    const source=tataGateRead(new URL('../workflows/tatagate.yml',import.meta.url),'utf8');
    assert.equal(tataGateValidateWorkflow(source),true);
    for(const invalid of [source.replace('branches: [main]','branches: [other]'),source.replace('needs: [gate]','needs: [other]'),source.replace('continue-on-error: true','continue-on-error: false')])assert.throws(()=>tataGateValidateWorkflow(invalid));
  });
  test('塔塔门禁成功清旧成功、失败清旧失败，活动、未来和其它流程均保留',()=>{
    const row=(id,conclusion='success',status='completed')=>({id,run_number:id,run_attempt:1,path:'.github/workflows/tatagate.yml',event:'push',head_branch:'main',head_sha:'a'.repeat(40),repository:{full_name:tataGateOwner},created_at:'2026-01-01T00:00:00Z',status,conclusion});
    const current=row(9,null,'in_progress'),rows=[row(1),row(2,'failure'),row(3,null,'in_progress'),row(10),{...row(4),path:'.github/workflows/release-sdk.yml'},{...row(5),repository:{full_name:'example/other'}}];
    assert.deepEqual(tataGateCleanupPlan(rows,current,'success').map(x=>x.id),[1]);
    assert.deepEqual(tataGateCleanupPlan(rows,current,'failed').map(x=>x.id),[2]);
  });
  test('塔塔门禁删除逐项回查，清理失败和重跑变化均不能伪报完成',async()=>{
    const current={id:9,run_number:9,run_attempt:1,path:'.github/workflows/tatagate.yml',event:'push',head_branch:'main',head_sha:'a'.repeat(40),repository:{full_name:tataGateOwner},created_at:'2026-01-02T00:00:00Z',status:'in_progress',conclusion:null};
    const old={...current,id:1,run_number:1,status:'completed',conclusion:'success',created_at:'2026-01-01T00:00:00Z'};
    for(const mode of ['success','readback','rerun']){
      let deleted=false;const api=async(path,options={})=>{
        if(path==='actions/runs/9')return current;
        if(path.startsWith('actions/workflows/'))return {total_count:1,workflow_runs:[old]};
        if(options.method==='DELETE'){deleted=true;return null;}
        if(path==='actions/runs/1')return mode==='rerun'?{...old,run_attempt:2}:deleted&&mode==='success'?null:old;
        throw Error('错误清理路径');
      };
      if(mode==='success')assert.deepEqual(await tataGateCleanup('success',{id:9,sha:current.head_sha},api),[1]);
      else await assert.rejects(tataGateCleanup('success',{id:9,sha:current.head_sha},api),/回查失败|已变化/u);
      if(mode==='rerun')assert.equal(deleted,false);
    }
  });
  test('GitHub门禁接受准确提交的detached检出，错仓、错SHA和错误Workflow拒绝',async()=>{
    const {mkdtempSync,mkdirSync,writeFileSync,rmSync,realpathSync}=await import('node:fs');
    const {tmpdir}=await import('node:os'),{join}=await import('node:path');
    const directory=mkdtempSync(join(realpathSync(tmpdir()),'tata-gate-context-'));
    try{
      const git=process.env.PRODUCT_GIT_BIN||'/usr/bin/git';
      const invoke=args=>tataGateExec(git,['-c','core.hooksPath=/dev/null','-c','user.name=Tata Gate Fixture','-c','user.email=fixture@example.invalid','-C',directory,...args],{encoding:'utf8'}).trim();
      invoke(['init','--quiet','--initial-branch=main']);invoke(['remote','add','origin','https://github.com/'+tataGateOwner+'.git']);
      writeFileSync(join(directory,'file'),'first');invoke(['add','file']);invoke(['commit','--quiet','-m','first']);const before=invoke(['rev-parse','HEAD']);
      writeFileSync(join(directory,'file'),'second');invoke(['add','file']);invoke(['commit','--quiet','-m','second']);const after=invoke(['rev-parse','HEAD']);
      invoke(['checkout','--quiet','--detach',after]);
      const input={GITHUB_ACTIONS:'true',GITHUB_JOB:'gate',GITHUB_EVENT_NAME:'push',GITHUB_REPOSITORY:tataGateOwner,GITHUB_REF:'refs/heads/main',GITHUB_WORKSPACE:directory,GITHUB_SHA:after,
        GITHUB_WORKFLOW_REF:tataGateOwner+'/.github/workflows/tatagate.yml@refs/heads/main',PRODUCT_GIT_BIN:git};
      const event={repository:{full_name:tataGateOwner},ref:'refs/heads/main',before,after};
      assert.equal(tataGateContext(directory,input,event).after,after);
      assert.throws(()=>tataGateContext(directory,input,{...event,before:'a'.repeat(40)}),/祖先/u);
      writeFileSync(join(directory,'late'),'new change');assert.throws(()=>tataGateContext(directory,input,event),/未提交改动/u);rmSync(join(directory,'late'));
      for(const changed of [{...input,GITHUB_SHA:before},{...input,GITHUB_REPOSITORY:'example/other'},{...input,GITHUB_WORKFLOW_REF:tataGateOwner+'/.github/workflows/release-sdk.yml@refs/heads/main'}])assert.throws(()=>tataGateContext(directory,changed,event));
    }finally{rmSync(directory,{recursive:true,force:true});}
  });

}
// END INLINE TESTS
