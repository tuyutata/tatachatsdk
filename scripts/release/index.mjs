#!/usr/bin/env node
// RELEASE_BUILD: full; CARGO_INCREMENTAL=0; 单平台目录不重复包装 sdk。

import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';

const root = resolve(process.env.TATACHATSDK_REPOSITORY_ROOT || process.cwd());
const tagPrefix = 'tatachatsdk-sdk-v';
const releaseTitle = '塔塔聊天SDK · Release · SDK';
const releaseAssets = ['tatachatsdk.tgz'];
const expectedRoutes = [
  'tatachatsdk.sdk.ci',
  'tatachatsdk.sdk.release',
];
const expectedFiles = [
  'pubspec.yaml',
  'pubspec.lock',
  'native/Cargo.toml',
  'native/Cargo.lock',
  'scripts/dependencies.mjs',
  'scripts/build.mjs',
  'scripts/release.mjs',
  'scripts/resources.mjs',
  'native/tatachat_sdk.h',
];

function fail(message) {
  throw new Error(message);
}

function read(path) {
  const absolute = resolve(root, path);
  // 先显式判断存在性，避免把 Node 文件系统选项误识别成第一方契约字段。
  if (!existsSync(absolute)) fail(`缺少普通依赖文件：${path}`);
  const status = lstatSync(absolute);
  if (!status.isFile() || status.isSymbolicLink()) fail(`缺少普通依赖文件：${path}`);
  return readFileSync(absolute, 'utf8');
}

function exactArray(actual, expected, label) {
  if (!Array.isArray(actual)
      || JSON.stringify([...actual].sort()) !== JSON.stringify([...expected].sort())) {
    fail(`${label}登记不准确`);
  }
}

function checkPinnedActions(relativePath, source) {
  const actions = [...source.matchAll(/^\s*uses:\s*([^\s#]+).*$/gm)].map((match) => match[1]);
  if (actions.length === 0) fail(relativePath + ' 没有登记 GitHub Action');
  for (const action of actions) {
    // 本仓受控 Action 必须来自当前检出提交；只有本地相对调用可以不带提交后缀。
    if (action.startsWith('./')) continue;
    if (!/^[0-9a-f]{40}$/.test(String(action.split('@')[1] || ''))) {
      fail(relativePath + ' 的第三方 GitHub Action 未固定到 40 位提交：' + action);
    }
  }
}

function checkDependencies(scopeName) {
  if (scopeName !== 'tatachatsdk') fail('TataChatSDK 动作只接受 tatachatsdk 依赖作用域');
  const contract = JSON.parse(read('scripts/dependencies.json'));
  if (contract.schema !== 1) fail('TataChatSDK 依赖契约无效');
  exactArray(contract.routes, expectedRoutes, 'TataChatSDK 路由');
  exactArray(contract.required_files, expectedFiles, 'TataChatSDK 必需文件');
  if (!contract.dart_applications?.includes('.')
      || !contract.cargo_projects?.includes('native')
      || !contract.audited_scopes?.includes('tatachatsdk')) {
    fail('TataChatSDK 依赖项目登记不完整');
  }
  for (const relativePath of expectedFiles) read(relativePath);
  const pubspec = read('pubspec.yaml');
  if (!/^name:\s*tatachat_sdk\s*$/m.test(pubspec)
      || !/^version:\s*\d+\.\d{1,2}\.\d{1,2}(?:\+\d+)?\s*$/m.test(pubspec)) {
    fail('TataChatSDK pubspec 身份或软件版本无效');
  }
  const cargo = read('native/Cargo.toml');
  if (!/^name\s*=\s*"tatachat_sdk_native"\s*$/m.test(cargo)
      || !/^name\s*=\s*"tatachat_sdk"\s*$/m.test(cargo)) {
    fail('TataChatSDK Rust package 或 library 身份无效');
  }
  checkPinnedActions('.github/workflows/tatachatsdk-sdk-ci.yml', read('.github/workflows/tatachatsdk-sdk-ci.yml'));
}

function auditDependencies(scopeName) {
  checkDependencies(scopeName);
  const result = spawnSync('cargo', ['audit', '--file', 'Cargo.lock'], {
    cwd: resolve(root, 'native'), stdio: 'inherit', env: process.env,
  });
  if (result.error) fail(`无法启动 cargo audit：${result.error.message}`);
  if (result.status !== 0) fail(`TataChatSDK Rust 依赖安全审计失败：${result.status}`);
}

function parseOptions(argumentsList) {
  const values = Object.create(null);
  for (let index = 0; index < argumentsList.length; index += 1) {
    const key = argumentsList[index];
    if (!key.startsWith('--')) fail(`未知参数：${key}`);
    if (key === '--assets') {
      const assets = [];
      while (argumentsList[index + 1] && !argumentsList[index + 1].startsWith('--')) {
        assets.push(argumentsList[index + 1]);
        index += 1;
      }
      values.assets = assets;
      continue;
    }
    const value = argumentsList[index + 1];
    if (!value || value.startsWith('--')) fail(`参数缺少值：${key}`);
    values[key.slice(2)] = value;
    index += 1;
  }
  return values;
}

function requireOption(values, key) {
  const value = values[key];
  if (typeof value !== 'string' || value.length === 0) fail(`缺少参数：--${key}`);
  return value;
}

function runGh(argumentsList, { allowFailure = false } = {}) {
  const result = spawnSync('gh', argumentsList, {
    cwd: root, encoding: 'utf8', env: process.env, maxBuffer: 32 * 1024 * 1024,
  });
  if (result.error) fail(`无法启动 gh：${result.error.message}`);
  if (result.status !== 0 && !allowFailure) {
    fail(`GitHub API 失败：${String(result.stderr || result.stdout).trim()}`);
  }
  return result;
}

function ghJSON(argumentsList) {
  const result = runGh(argumentsList);
  try {
    return JSON.parse(result.stdout);
  } catch {
    fail('GitHub API 返回的不是有效 JSON');
  }
}

function semver(value, label) {
  const match = String(value || '').match(/^(0|[1-9][0-9]*)\.(\d{1,2})\.(\d{1,2})$/);
  if (!match) fail(`${label}必须是三段软件版本且后两段不超过两位`);
  const parts = match.slice(1).map(Number);
  if (parts[1] > 99 || parts[2] > 99) fail(`${label}后两段不能超过 99`);
  return parts;
}

function compareVersion(left, right) {
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return 0;
}

function nextVersion(parts) {
  let [major, minor, patch] = parts;
  patch += 1;
  if (patch > 99) { patch = 0; minor += 1; }
  if (minor > 99) { minor = 0; major += 1; }
  return `${major}.${minor}.${patch}`;
}

function nextSemanticRelease(values) {
  if (requireOption(values, 'prefix') !== tagPrefix) fail('TataChatSDK Tag 前缀错误');
  const seedText = requireOption(values, 'seed');
  const seed = semver(seedText, 'TataChatSDK 种子版本');
  const pages = ghJSON(['api', '--paginate', '--slurp', 'repos/{owner}/{repo}/releases?per_page=100']);
  const releases = Array.isArray(pages) ? pages.flat() : [];
  const versions = releases
    .filter((release) => release?.draft === false && release?.prerelease === false)
    .map((release) => String(release?.tag_name || '').match(/^tatachatsdk-sdk-v(\d+\.\d{1,2}\.\d{1,2})$/)?.[1])
    .filter(Boolean)
    .map((value) => semver(value, 'GitHub TataChatSDK Release 版本'))
    .sort(compareVersion);
  if (versions.length === 0 || compareVersion(seed, versions.at(-1)) > 0) {
    process.stdout.write(seedText);
    return;
  }
  process.stdout.write(nextVersion(versions.at(-1)));
}

function githubFile(path, sourceSHA) {
  const value = ghJSON(['api', `repos/{owner}/{repo}/contents/${path}?ref=${sourceSHA}`]);
  if (value?.encoding !== 'base64' || typeof value.content !== 'string') {
    fail(`GitHub 源文件响应无效：${path}`);
  }
  return Buffer.from(value.content.replace(/\s/g, ''), 'base64').toString('utf8');
}

function verifyReleaseSource(values) {
  const ciRunID = Number(requireOption(values, 'ci-run-id'));
  const versionTag = requireOption(values, 'version-tag');
  const sourceSHA = requireOption(values, 'source-sha');
  const softwareVersion = requireOption(values, 'software-version');
  if (!Number.isSafeInteger(ciRunID) || ciRunID <= 0) fail('TataChatSDK CI run_id 无效');
  if (!/^[0-9a-f]{40}$/.test(sourceSHA)) fail('TataChatSDK source_sha 无效');
  semver(softwareVersion, 'TataChatSDK Release 版本');
  if (versionTag !== `${tagPrefix}${softwareVersion}`
      || requireOption(values, 'prefix') !== tagPrefix
      || requireOption(values, 'product-id') !== 'tatachatsdk'
      || requireOption(values, 'target') !== 'sdk'
      || requireOption(values, 'workflow') !== 'tatachatsdk.sdk.ci') {
    fail('TataChatSDK Release 产品、平台、Workflow 或 Tag 身份无效');
  }
  const run = ghJSON(['api', `repos/{owner}/{repo}/actions/runs/${ciRunID}`]);
  if (run?.id !== ciRunID || run?.status !== 'completed' || run?.conclusion !== 'success'
      || run?.event !== 'workflow_dispatch' || run?.head_branch !== 'main'
      || run?.head_sha !== sourceSHA || String(run?.display_title || '') !== '塔塔聊天SDK · SDK · CI'
      || !/(?:^|\/)\.github\/workflows\/tatachatsdk-sdk-ci\.yml(?:@|$)/.test(String(run?.path || ''))
      || run?.head_repository?.full_name !== 'tuyutata/tatachatsdk') {
    fail('TataChatSDK Release 所绑定 CI 不是准确成功终态');
  }
  const pubspec = githubFile('pubspec.yaml', sourceSHA);
  const version = pubspec.match(/^version:\s*(\d+\.\d{1,2}\.\d{1,2})(?:\+\d+)?\s*$/m)?.[1];
  if (version !== softwareVersion) fail('TataChatSDK Release 版本与成功 CI 源码不一致');
}

function exactMarker(body, name, pattern) {
  const matches = [...String(body || '').matchAll(new RegExp(`${name}:(${pattern})(?=\\s|$)`, 'g'))];
  if (matches.length !== 1) fail(`TataChatSDK Release ${name} 标记无效`);
  return matches[0][1];
}

function tagCommitSHA(tag) {
  let object = ghJSON(['api', `repos/{owner}/{repo}/git/ref/tags/${encodeURIComponent(tag)}`])?.object;
  if (object?.type === 'tag') object = ghJSON(['api', `repos/{owner}/{repo}/git/tags/${object.sha}`])?.object;
  if (object?.type !== 'commit' || !/^[0-9a-f]{40}$/.test(String(object?.sha || ''))) {
    fail('TataChatSDK Release Tag 未绑定准确提交');
  }
  return object.sha;
}

function verifyLocalAssets(paths, tag, sourceSHA) {
  const byName = Object.create(null);
  for (const path of paths) {
    if (!existsSync(path)) fail(`TataChatSDK 正式资产无效：${path}`);
    const status = lstatSync(path);
    if (!status.isFile() || status.isSymbolicLink() || status.size <= 0) fail(`TataChatSDK 正式资产无效：${path}`);
    const name = basename(path);
    if (byName[name]) fail(`TataChatSDK 正式资产重名：${name}`);
    byName[name] = { path, bytes: readFileSync(path) };
  }
  exactArray(Object.keys(byName), releaseAssets, 'TataChatSDK 正式资产');
  const archive = byName['tatachatsdk.tgz'];
  const version = tag.slice(tagPrefix.length);
  const verification = spawnSync(process.execPath, [
    resolve(root, 'scripts/release.mjs'), '--verify-assets', dirname(archive.path),
    '--expected-git-sha', sourceSHA, '--software-version', version,
  ], { cwd: root, encoding: 'utf8', env: process.env });
  if (verification.status !== 0) {
    fail(`TataChatSDK 单包验真失败：${String(verification.stderr || verification.stdout).trim()}`);
  }
  const manifestResult = spawnSync('tar', [
    '-xOzf', archive.path, 'tatachatsdk/release-manifest.json',
  ], { cwd: root, encoding: 'utf8', env: process.env });
  if (manifestResult.status !== 0) fail('TataChatSDK 单包缺少内部 manifest');
  const manifest = JSON.parse(manifestResult.stdout);
  if (manifest?.product_id !== 'tatachatsdk' || manifest?.package_name !== 'tatachat_sdk'
      || manifest?.git_commit_sha !== sourceSHA || manifest?.software_version !== version
      || !Array.isArray(manifest.platforms) || manifest.platforms.length !== 3
      || !Array.isArray(manifest.files) || manifest.files.length === 0) {
    fail('TataChatSDK 正式 manifest 内容无效');
  }
}

function verifyRemoteRelease(tag, sourceSHA, expectedBody) {
  const release = ghJSON(['api', `repos/{owner}/{repo}/releases/tags/${encodeURIComponent(tag)}`]);
  if (!Number.isSafeInteger(release?.id) || release.id <= 0 || release.tag_name !== tag
      || release.name !== releaseTitle || release.draft !== false || release.prerelease !== false
      || String(release.body || '') !== expectedBody || !Array.isArray(release.assets)
      || release.assets.length !== 1
      || release.assets.some((asset) => asset?.state !== 'uploaded'
        || !Number.isSafeInteger(asset?.id) || asset.id <= 0
        || !Number.isSafeInteger(asset?.size) || asset.size <= 0)) {
    fail('TataChatSDK 正式 Release 回读身份或上传状态无效');
  }
  exactArray(release.assets.map((asset) => asset.name), releaseAssets, 'TataChatSDK 远端正式资产');
  if (exactMarker(release.body, 'TATACHATSDK_RELEASE_SOURCE_SHA', '[0-9a-f]{40}') !== sourceSHA) {
    fail('TataChatSDK 正式 Release 源码标记不一致');
  }
  exactMarker(release.body, 'TATACHATSDK_RELEASE_CI_RUN_ID', '[1-9][0-9]*');
  exactMarker(release.body, 'TATACHATSDK_RELEASE_RUN_ID', '[1-9][0-9]*');
  if (tagCommitSHA(tag) !== sourceSHA) fail('TataChatSDK 正式 Release Tag 源码不一致');
}

function createGitHubRelease(values) {
  const tag = requireOption(values, 'tag');
  const sourceSHA = requireOption(values, 'source-sha');
  const title = requireOption(values, 'title');
  const notes = requireOption(values, 'notes');
  if (title !== releaseTitle || values.latest !== 'false' || !/^[0-9a-f]{40}$/.test(sourceSHA)
      || !/^tatachatsdk-sdk-v\d+\.\d{1,2}\.\d{1,2}$/.test(tag)) {
    fail('TataChatSDK 正式 Release 参数无效');
  }
  exactMarker(notes, 'TATACHATSDK_RELEASE_CI_RUN_ID', '[1-9][0-9]*');
  exactMarker(notes, 'TATACHATSDK_RELEASE_RUN_ID', '[1-9][0-9]*');
  if (notes.includes('TATACHATSDK_RELEASE_SOURCE_SHA:')) fail('TataChatSDK source 标记只能由 Release 工具写入');
  const assets = Array.isArray(values.assets) ? values.assets : [];
  verifyLocalAssets(assets, tag, sourceSHA);
  const body = `${notes.trimEnd()}\nTATACHATSDK_RELEASE_SOURCE_SHA:${sourceSHA}`;
  runGh([
    'release', 'create', tag, '--target', sourceSHA, '--title', title,
    '--notes', body, '--latest=false', ...assets,
  ]);
  try {
    verifyRemoteRelease(tag, sourceSHA, body);
  } catch (error) {
    runGh(['release', 'delete', tag, '--yes', '--cleanup-tag'], { allowFailure: true });
    throw error;
  }
}

function main() {
  const [command, subcommand, ...argumentsList] = process.argv.slice(2);
  const values = parseOptions(argumentsList);
  if (command === 'dependencies' && subcommand === 'check') checkDependencies(values.scope);
  else if (command === 'dependencies' && subcommand === 'audit') auditDependencies(values.scope);
  else if (command === 'version-tag' && subcommand === 'next-semantic-release') nextSemanticRelease(values);
  else if (command === 'version-tag' && subcommand === 'verify-release-source') verifyReleaseSource(values);
  else if (command === 'github-release' && subcommand === undefined) createGitHubRelease(values);
  else fail('不支持的 TataChatSDK Release 命令');
}

import {fileURLToPath}from'node:url';
const directInvocation=Boolean(!process.execArgv.some(value=>/^(?:-e|--eval(?:=|$)|--input-type(?:=|$))/u.test(value)) && process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url));
const testInvocation=directInvocation && (process.argv[2]==='test'||process.env.NODE_TEST_CONTEXT==='child-v8'&&process.argv.length===2);
if(directInvocation&&!testInvocation){
try {
  main();
} catch (error) {
  process.stderr.write(`TataChatSDK Release 检查失败：${error.message}\n`);
  process.exitCode = 1;
}

}

// 正式实现结束；以下回归仅在本文件作为测试入口时注册。
if (testInvocation) {
const {default:test}=await import('node:test');const {default:assert}=await import('node:assert/strict');
test('发布调度拒绝未知动作及缺少来源参数',()=>{const before=process.argv;try{for(const args of [['unknown'],['version-tag','verify-release-source']]){process.argv=[process.execPath,fileURLToPath(import.meta.url),...args];assert.throws(()=>main());}}finally{process.argv=before;}});
}
