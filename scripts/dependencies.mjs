#!/usr/bin/env node
// TataChatSDK只在调用方源码外目录准备自己声明的协议生成工具，不读取其它产品或控制程序。
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import {
  createWriteStream,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  renameSync,
  rmSync,
} from 'node:fs';
import { chmod } from 'node:fs/promises';
import { isAbsolute, join, resolve } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';

const scripts = fileURLToPath(new URL('.', import.meta.url));
const product = realpathSync(join(scripts, '..'));
const contract = JSON.parse(readFileSync(join(scripts, 'dependencies.json'), 'utf8'));
const protocVersion = '35.0';
const protocSource = 'https://github.com/protocolbuffers/protobuf/releases/tag/v35.0';
const pluginVersion = '25.0.0';
const pluginSource = 'https://pub.dev/packages/protoc_plugin/versions/25.0.0';
const pluginArchiveURL = 'https://pub.dev/api/archives/protoc_plugin-25.0.0.tar.gz';
const pluginArchiveSHA256 = 'd1ea363e9118f954d9d482c2f7281c5ff5149b059e68672d1faa564d49091f05';
const protocArchives = Object.freeze({
  macos: 'protoc-35.0-osx-aarch_64.zip',
  'linux-arm': 'protoc-35.0-linux-aarch_64.zip',
  'linux-amd': 'protoc-35.0-linux-x86_64.zip',
  windows: 'protoc-35.0-win64.zip',
});

function fail(message) { throw new Error(message); }

function safeWork(value) {
  if (!isAbsolute(value)) fail('TataChatSDK工具工作目录必须是绝对路径');
  const target = resolve(value);
  if (target === product || target.startsWith(product + '/')) fail('TataChatSDK工具不得写入源码目录');
  mkdirSync(target, { recursive: true, mode: 0o700 });
  const actual = realpathSync(target);
  if (actual !== target) fail('TataChatSDK工具工作目录禁止符号链接');
  return actual;
}

async function download(url, output, hosts) {
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:' || !hosts.includes(parsed.hostname)
      || parsed.username || parsed.password) fail('TataChatSDK工具来源无效');
  let last;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const partial = `${output}.partial-${process.pid}-${attempt}`;
    try {
      const response = await fetch(url, {
        redirect: 'follow',
        signal: AbortSignal.timeout(300_000),
      });
      const final = new URL(response.url);
      if (!response.ok || !response.body) fail(`TataChatSDK工具下载失败：${response.status}`);
      if (final.protocol !== 'https:' || !hosts.includes(final.hostname)
          || final.username || final.password) fail('TataChatSDK工具重定向来源无效');
      await pipeline(response.body, createWriteStream(partial, { flags: 'wx', mode: 0o600 }));
      renameSync(partial, output);
      return;
    } catch (error) {
      rmSync(partial, { force: true });
      last = error;
    }
  }
  throw last;
}

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function fileInventory(root) {
  const files = new Map();
  function walk(directory, prefix) {
    for (const entry of readdirSync(directory, { withFileTypes: true })
      .sort((left, right) => left.name.localeCompare(right.name))) {
      const path = join(directory, entry.name);
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      const status = lstatSync(path);
      if (status.isSymbolicLink()) fail('TataChatSDK protoc_plugin源码禁止符号链接');
      if (status.isDirectory()) walk(path, relative);
      else if (status.isFile()) files.set(relative, sha256(path));
      else fail('TataChatSDK protoc_plugin源码文件类型无效');
    }
  }
  walk(root, '');
  return [...files.entries()];
}

async function verifiedArchive(entry, archive, hosts) {
  if (existsSync(archive) && sha256(archive) !== entry.sha256) rmSync(archive, { force: true });
  if (!existsSync(archive)) await download(entry.url, archive, hosts);
  if (sha256(archive) !== entry.sha256) {
    rmSync(archive, { force: true });
    fail('TataChatSDK工具摘要不符');
  }
}

async function prepareProtoc(platform, workValue) {
  const archives = contract.tools?.protoc?.archives;
  const entry = archives?.[platform];
  const archiveName = protocArchives[platform];
  const expectedURL = archiveName
    ? `https://github.com/protocolbuffers/protobuf/releases/download/v${protocVersion}/${archiveName}`
    : null;
  const expectedExecutable = platform === 'windows' ? 'bin/protoc.exe' : 'bin/protoc';
  if (contract.tools?.protoc?.version !== protocVersion
      || contract.tools?.protoc?.source !== protocSource || !archives
      || Object.keys(archives).sort().join(',') !== Object.keys(protocArchives).sort().join(',')
      || !entry || entry.url !== expectedURL || entry.executable !== expectedExecutable
      || !/^[a-f0-9]{64}$/.test(entry.sha256)) fail('TataChatSDK protoc声明无效');
  const work = safeWork(workValue);
  const archive = join(work, archiveName);
  const payload = join(work, 'payload');
  rmSync(payload, { recursive: true, force: true });
  await verifiedArchive(entry, archive, ['github.com', 'release-assets.githubusercontent.com']);
  mkdirSync(payload, { mode: 0o700 });
  const unpacked = spawnSync('unzip', ['-q', archive, '-d', payload], { stdio: 'inherit' });
  if (unpacked.error || unpacked.status !== 0) {
    rmSync(payload, { recursive: true, force: true });
    fail('TataChatSDK protoc解包失败');
  }
  const executable = join(payload, entry.executable);
  if (!existsSync(executable) || !lstatSync(executable).isFile()) fail('TataChatSDK protoc可执行文件无效');
  await chmod(executable, 0o700);
  const version = spawnSync(executable, ['--version'], { encoding: 'utf8' });
  if (version.error || version.status !== 0 || version.stdout.trim() !== `libprotoc ${protocVersion}`) {
    rmSync(payload, { recursive: true, force: true });
    fail('TataChatSDK protoc版本验真失败');
  }
  return executable;
}

async function preparePlugin(platform, workValue) {
  const tool = contract.tools?.protoc_plugin;
  const entry = tool?.archive;
  if (platform !== 'sdk' || tool?.version !== pluginVersion || tool?.source !== pluginSource
      || entry?.url !== pluginArchiveURL || entry?.sha256 !== pluginArchiveSHA256
      || entry?.executable !== 'protoc-gen-dart') fail('TataChatSDK protoc_plugin声明无效');
  const work = safeWork(workValue);
  const archive = join(work, `protoc_plugin-${pluginVersion}.tar.gz`);
  await verifiedArchive(entry, archive, ['pub.dev', 'storage.googleapis.com']);
  const listing = spawnSync('tar', ['-tzf', archive], { encoding: 'utf8' });
  if (listing.error || listing.status !== 0) fail('TataChatSDK protoc_plugin归档无效');
  for (const path of listing.stdout.split(/\r?\n/u).filter(Boolean)) {
    if (path.startsWith('/') || path.split('/').includes('..') || path.includes('\\')) {
      fail('TataChatSDK protoc_plugin归档路径无效');
    }
  }
  const verifiedSource = join(work, 'verified-source');
  rmSync(verifiedSource, { recursive: true, force: true });
  mkdirSync(verifiedSource, { mode: 0o700 });
  const extracted = spawnSync('tar', ['-xzf', archive, '-C', verifiedSource], { encoding: 'utf8' });
  if (extracted.error || extracted.status !== 0) fail('TataChatSDK protoc_plugin解包失败');

  const pubCache = join(work, 'pub-cache');
  mkdirSync(pubCache, { recursive: true, mode: 0o700 });
  const environment = {
    ...process.env,
    PUB_CACHE: pubCache,
    PUB_HOSTED_URL: 'https://pub.dev',
  };
  const activated = spawnSync(
    'dart',
    ['pub', 'global', 'activate', 'protoc_plugin', pluginVersion, '--overwrite'],
    { encoding: 'utf8', env: environment },
  );
  if (activated.error || activated.status !== 0) fail('TataChatSDK protoc_plugin准备失败');
  const listed = spawnSync('dart', ['pub', 'global', 'list'], { encoding: 'utf8', env: environment });
  if (listed.error || listed.status !== 0
      || listed.stdout.split(/\r?\n/u).filter(Boolean).join('\n') !== `protoc_plugin ${pluginVersion}`) {
    fail('TataChatSDK protoc_plugin版本验真失败');
  }
  const activatedSource = join(pubCache, 'hosted', 'pub.dev', `protoc_plugin-${pluginVersion}`);
  if (!existsSync(activatedSource) || !lstatSync(activatedSource).isDirectory()
      || realpathSync(activatedSource) !== activatedSource
      || JSON.stringify(fileInventory(activatedSource)) !== JSON.stringify(fileInventory(verifiedSource))) {
    fail('TataChatSDK protoc_plugin激活源码与官方归档不一致');
  }
  const executable = join(pubCache, 'bin', process.platform === 'win32'
    ? 'protoc-gen-dart.bat' : 'protoc-gen-dart');
  if (!existsSync(executable) || !lstatSync(executable).isFile()
      || !realpathSync(executable).startsWith(work + '/')) {
    fail('TataChatSDK protoc_plugin可执行文件无效');
  }
  if (process.platform !== 'win32') await chmod(executable, 0o700);
  return executable;
}

async function main() {
  const [command, toolName, platform, workValue] = process.argv.slice(2);
  if (contract.schema !== 1 || command !== 'prepare' || !workValue
      || process.argv.length !== 6) fail('TataChatSDK工具参数无效');
  if (toolName === 'protoc') return prepareProtoc(platform, workValue);
  if (toolName === 'protoc_plugin') return preparePlugin(platform, workValue);
  fail('TataChatSDK工具名称无效');
}

main().then((executable) => process.stdout.write(executable)).catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
