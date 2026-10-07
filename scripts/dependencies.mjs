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
  writeFileSync,
} from 'node:fs';
import { chmod } from 'node:fs/promises';
import { isAbsolute, join, resolve } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scripts = fileURLToPath(new URL('.', import.meta.url));
const product = realpathSync(join(scripts, '..'));
const contract = JSON.parse(readFileSync(join(scripts, 'dependencies.json'), 'utf8'));
// 离线只读取已交付原件；非法开关必须在创建工作目录前拒绝。
const offlineValue = process.env.TATACHATSDK_PROTOCOL_OFFLINE;
const offline = offlineValue === '1';
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
  if ((target === product || target.startsWith(product + '/')) && !target.startsWith(join(product, 'target') + '/')) fail('TataChatSDK工具只能在源码树的target内生成');
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
  if (offline) {
    if (!existsSync(archive)) fail('TataChatSDK离线工具原件缺失');
    const status = lstatSync(archive);
    if (!status.isFile() || status.isSymbolicLink()) {
      fail('TataChatSDK离线工具原件必须为普通文件');
    }
    if (sha256(archive) !== entry.sha256) fail('TataChatSDK离线工具原件摘要不符');
    return;
  }
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
  await verifiedArchive(entry, archive, ['github.com', 'release-assets.githubusercontent.com']);
  rmSync(payload, { recursive: true, force: true });
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
  // 固定消费者只引用官方插件；Pub离线解析后直接编译同一验真源码，不使用全局激活。
  const consumer = join(work, 'consumer');
  rmSync(consumer, { recursive: true, force: true });
  mkdirSync(consumer, { mode: 0o700 });
  writeFileSync(join(consumer, 'pubspec.yaml'),
    'name: protoc_plugin_runner\npublish_to: none\nenvironment:\n  sdk: ^3.7.0\ndependencies:\n  protoc_plugin: ' + pluginVersion + '\n',
    { flag: 'wx', mode: 0o600 });
  for (const locked of [false, true]) {
    const resolved = spawnSync('dart',
      ['pub', 'get', ...(offline ? ['--offline'] : []), ...(locked ? ['--enforce-lockfile'] : [])],
      { encoding: 'utf8', cwd: consumer, env: environment });
    if (resolved.error || resolved.status !== 0) fail('TataChatSDK protoc_plugin固定依赖准备失败');
  }
  const packageConfig = join(consumer, '.dart_tool', 'package_config.json');
  const configuration = JSON.parse(readFileSync(packageConfig, 'utf8'));
  const pluginPackages = configuration.packages?.filter(value => value.name === 'protoc_plugin');
  const preparedSource = join(pubCache, 'hosted', 'pub.dev', 'protoc_plugin-' + pluginVersion);
  if (configuration.configVersion !== 2 || pluginPackages?.length !== 1
      || fileURLToPath(new URL(pluginPackages[0].rootUri, pathToFileURL(packageConfig))) !== preparedSource
      || !existsSync(preparedSource) || !lstatSync(preparedSource).isDirectory()
      || realpathSync(preparedSource) !== preparedSource
      || JSON.stringify(fileInventory(preparedSource)) !== JSON.stringify(fileInventory(verifiedSource))) {
    fail('TataChatSDK protoc_plugin准备源码与官方归档不一致');
  }
  // 显式使用本轮Pub配置，输出官方插件的宿主可执行文件，不包装Dart命令。
  const executable = join(work, process.platform === 'win32' ? 'protoc-gen-dart.exe' : 'protoc-gen-dart');
  rmSync(executable, { force: true });
  const compiled = spawnSync('dart', ['compile', 'exe',
    join(preparedSource, 'bin', 'protoc_plugin.dart'), '--packages=' + packageConfig, '-o', executable],
    { encoding: 'utf8', cwd: consumer, env: environment });
  if (compiled.error || compiled.status !== 0) fail('TataChatSDK protoc_plugin官方源码编译失败');
  if (!existsSync(executable) || !lstatSync(executable).isFile()
      || lstatSync(executable).isSymbolicLink() || realpathSync(executable) !== executable) {
    fail('TataChatSDK protoc_plugin可执行文件无效');
  }
  if (process.platform !== 'win32') await chmod(executable, 0o700);
  return executable;
}

async function main() {
  if (offlineValue !== undefined && offlineValue !== '1') {
    fail('TataChatSDK协议生成离线参数仅接受1');
  }
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
