#!/usr/bin/env node
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
  if (git(root, ['rev-parse', '--abbrev-ref', 'HEAD']).stdout.trim() !== 'main') {
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
  const [mode, root, baseSHA, headSHA, work] = args;
  if (!['physical', 'local'].includes(mode) || root !== productRoot
      || mode === 'physical' && args.length !== 2
      || mode === 'local' && args.length !== 5) fail('只读门禁入口参数无效');
  validateRepositoryIdentity(root);
  exactDirectory(root, 'scripts', ['build.mjs', 'publish.mjs']);
  exactDirectory(root, '.github/workflows', ['release-sdk.yml', 'release-sdk.mjs']);
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

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.stdout.write(JSON.stringify(repositoryGateMain(process.argv.slice(2))) + '\n'); }
  catch (error) {
    console.error(error?.message?.startsWith('本仓塔塔门禁：') ? error.message : '本仓塔塔门禁：只读检查失败');
    process.exitCode = 1;
  }
}
