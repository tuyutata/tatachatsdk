#!/usr/bin/env node

import { constants as fsConstants } from 'node:fs';
import {
  access,
  chmod,
  copyFile,
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  realpath,
  symlink,
  rm,
  writeFile,
} from 'node:fs/promises';
import { gzipSync, gunzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { basename, dirname, isAbsolute, join, posix, relative, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';

const PRODUCT_ID = 'tatachatsdk';
const PACKAGE_NAME = 'tatachat_sdk';
const ARCHIVE_NAME = 'tatachatsdk.tgz';
const MANIFEST_NAME = 'release-manifest.json';
const CHECKSUMS_NAME = 'SHA256SUMS';
const RELEASE_ASSETS = [ARCHIVE_NAME];
const SOURCE_ENTRIES = [
  'CHANGELOG.md',
  'LICENSE',
  'analysis_options.yaml',
  'pubspec.yaml',
  'pubspec.lock',
  'tatachat_sdk.h',
  'ios',
  'lib',
  'native',
  'stickers',
];
const GENERATED_COMPONENTS = new Set([
  '.dart_tool',
  '.git',
  '.idea',
  '.DS_Store',
  'build',
  'target',
]);
const PLATFORM_ARTIFACTS = [
  {
    platform: 'android',
    architecture: 'arm64-v8a',
    source: 'android/libtatachat_sdk.so',
    path: 'prebuilt/android-arm64/libtatachat_sdk.so',
  },
  {
    platform: 'ios',
    architecture: 'arm64',
    source: 'ios/TataChatSDK.xcframework',
    path: 'prebuilt/ios-arm64/TataChatSDK.xcframework',
    requiredFiles: [
      'Info.plist',
      'ios-arm64/TataChatSDK.framework/TataChatSDK',
      'ios-arm64/TataChatSDK.framework/Info.plist',
    ],
  },
  {
    platform: 'macos',
    architecture: 'arm64',
    source: 'macos/libtatachat_sdk.dylib',
    path: 'prebuilt/macos/libtatachat_sdk.dylib',
  },
];

function fail(message) {
  throw new Error(message);
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function assertExactKeys(value, keys, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} 必须是对象`);
  }
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    fail(`${label} 字段不符合正式契约`);
  }
}

function normalizeRelativePath(value) {
  const normalized = value.split(sep).join('/');
  if (
    normalized.length === 0 ||
    normalized.startsWith('/') ||
    normalized.includes('\\') ||
    normalized.split('/').some((component) => component === '' || component === '.' || component === '..')
  ) {
    fail(`非法相对路径：${value}`);
  }
  return normalized;
}


// 仓库仅保存扁平入口；Flutter要求的包路径只在调用方本轮工程中装配。
const FLUTTER_INPUTS = new Map([
  ['android/TataChatSdkPlugin.java', 'android/src/main/java/chat/tata/sdk/TataChatSdkPlugin.java'],
  ['android/AndroidManifest.xml', 'android/src/main/AndroidManifest.xml'],
]);
const FLUTTER_GENERATED = new Set([
  '.git', '.dart_tool', '.gradle', '.kotlin', '.pub-cache', '.symlinks', 'Pods',
  'build', 'target', 'node_modules', 'TataChatSDK.xcframework',
]);

async function flutterViewRoots(source, output) {
  for (const value of [source, output]) {
    if (typeof value !== 'string' || !isAbsolute(value) || resolve(value) !== value
        || dirname(value) === value) fail('Flutter工程必须使用规范绝对路径');
    let current = value;
    while (true) {
      const info = await lstat(current).catch(error => {
        if (error.code === 'ENOENT') return null;
        throw error;
      });
      if (info && (!info.isDirectory() || info.isSymbolicLink())) {
        fail('Flutter工程祖先必须为普通目录');
      }
      if (dirname(current) === current) break;
      current = dirname(current);
    }
  }
  const inside = (root, candidate) => {
    const part = relative(root, candidate);
    return part === '' || (!isAbsolute(part) && part !== '..' && !part.startsWith('..' + sep));
  };
  if (inside(source, output) || inside(output, source)) fail('Flutter工程与源码必须分离');
  if (await realpath(source) !== source) fail('Flutter源码根不规范');
}

async function flutterViewInputs(source) {
  const files = [];
  async function collect(directory = '') {
    for (const name of (await readdir(join(source, directory))).sort()) {
      if (FLUTTER_GENERATED.has(name)) continue;
      const file = directory ? directory + '/' + name : name;
      const info = await lstat(join(source, file));
      if (info.isSymbolicLink()) fail('Flutter源码禁止链接：' + file);
      if (info.isDirectory()) await collect(file);
      else if (info.isFile()) files.push(file);
      else fail('Flutter源码类型无效：' + file);
    }
  }
  await collect();
  for (const file of ['pubspec.yaml', 'pubspec.lock', 'android/build.gradle.kts', ...FLUTTER_INPUTS.keys()]) {
    if (!files.includes(file)) fail('Flutter入口缺少普通源文件：' + file);
  }
  for (const file of FLUTTER_INPUTS.values()) {
    if (files.includes(file)) fail('Flutter源码存在重复平台入口');
  }
  const manifest = await readFile(join(source, 'pubspec.yaml'), 'utf8');
  const plugin = await readFile(join(source, 'android/TataChatSdkPlugin.java'), 'utf8');
  if (!/^name: tatachat_sdk\r?$/mu.test(manifest)
      || !/      android:\r?\n        package: chat\.tata\.sdk\r?\n        pluginClass: TataChatSdkPlugin\r?\n/u.test(manifest)
      || !/^package chat\.tata\.sdk;\r?$/mu.test(plugin)
      || !/\bclass TataChatSdkPlugin\b/u.test(plugin)) fail('Flutter插件身份与声明不一致');
  return files;
}

/** 先完整校验再装配，Pub声明独立可写，平台入口保持唯一源码绑定。 */
export async function createFlutterSourceView(source, output) {
  await flutterViewRoots(source, output);
  const files = await flutterViewInputs(source);
  const existing = await lstat(output).catch(error => {
    if (error.code === 'ENOENT') return null;
    throw error;
  });
  if (existing) fail('Flutter工程已存在，禁止叠加');
  await mkdir(output, { recursive: true, mode: 0o700 });
  for (const file of files) {
    const destination = join(output, FLUTTER_INPUTS.get(file) ?? file);
    await mkdir(dirname(destination), { recursive: true, mode: 0o700 });
    if (file === 'pubspec.yaml' || file === 'pubspec.lock') {
      await copyFile(join(source, file), destination, fsConstants.COPYFILE_EXCL);
    } else {
      await symlink(join(source, file), destination);
    }
  }
  return output;
}

/** 复用前验证平台入口和Pub声明；拒绝来源漂移、链接目录或第二份入口。 */
export async function assertFlutterSourceView(source, output) {
  await flutterViewRoots(source, output);
  await flutterViewInputs(source);
  for (const [input, mapped] of FLUTTER_INPUTS) {
    const entry = join(output, mapped);
    await flutterViewRoots(source, dirname(entry));
    if (!(await lstat(entry)).isSymbolicLink()
        || await realpath(entry) !== join(source, input)
        || await lstat(join(output, input)).then(() => true, error => {
          if (error.code === 'ENOENT') return false;
          throw error;
        })) fail('Flutter平台入口来源绑定无效');
  }
  for (const name of ['pubspec.yaml', 'pubspec.lock']) {
    const file = join(output, name);
    const info = await lstat(file);
    if (!info.isFile() || info.isSymbolicLink()
        || !(await readFile(file)).equals(await readFile(join(source, name)))) {
      fail('Flutter工程Pub声明或锁文件漂移');
    }
  }
  return output;
}

async function copySourceTree(source, destination, relativePath) {
  const sourcePath = join(source, relativePath);
  const stat = await lstat(sourcePath).catch(() => null);
  if (!stat) fail(`TataChatSDK 发布源缺少：${relativePath}`);
  if (stat.isSymbolicLink()) fail(`TataChatSDK 发布源禁止符号链接：${relativePath}`);

  if (stat.isDirectory()) {
    await mkdir(join(destination, relativePath), { recursive: true });
    const entries = (await readdir(sourcePath, { withFileTypes: true }))
      .sort((left, right) => left.name.localeCompare(right.name));
    for (const entry of entries) {
      if (GENERATED_COMPONENTS.has(entry.name)) continue;
      await copySourceTree(source, destination, join(relativePath, entry.name));
    }
    return;
  }

  if (!stat.isFile()) fail(`TataChatSDK 发布源只允许普通文件：${relativePath}`);
  const target = join(destination, relativePath);
  await mkdir(dirname(target), { recursive: true });
  await copyFile(sourcePath, target);
  await chmod(target, stat.mode & 0o111 ? 0o755 : 0o644);
}

async function copyNativeArtifact(source, destination, label) {
  const stat = await lstat(source).catch(() => null);
  if (!stat || stat.isSymbolicLink()) fail(`${label} 缺失或是符号链接：${source}`);
  if (stat.isFile()) {
    if (stat.size === 0) fail(`${label} 为空：${source}`);
    await mkdir(dirname(destination), { recursive: true });
    await copyFile(source, destination);
    await chmod(destination, stat.mode & 0o111 ? 0o755 : 0o644);
    return 1;
  }
  if (!stat.isDirectory()) fail(`${label} 只允许普通文件或目录：${source}`);

  await mkdir(destination, { recursive: true });
  const entries = (await readdir(source, { withFileTypes: true }))
    .sort((left, right) => left.name.localeCompare(right.name));
  let files = 0;
  for (const entry of entries) {
    files += await copyNativeArtifact(
      join(source, entry.name),
      join(destination, entry.name),
      label,
    );
  }
  if (files === 0) fail(`${label} 目录为空：${source}`);
  return files;
}

async function listTree(root, current = '') {
  const absolute = current ? join(root, current) : root;
  const entries = (await readdir(absolute, { withFileTypes: true }))
    .sort((left, right) => left.name.localeCompare(right.name));
  const result = [];
  for (const entry of entries) {
    const child = current ? join(current, entry.name) : entry.name;
    const stat = await lstat(join(root, child));
    if (stat.isSymbolicLink()) fail(`正式包禁止符号链接：${child}`);
    if (stat.isDirectory()) {
      result.push({ path: normalizeRelativePath(child), directory: true, mode: 0o755 });
      result.push(...await listTree(root, child));
    } else if (stat.isFile()) {
      result.push({
        path: normalizeRelativePath(child),
        directory: false,
        mode: stat.mode & 0o111 ? 0o755 : 0o644,
        bytes: await readFile(join(root, child)),
      });
    } else {
      fail(`正式包只允许普通文件和目录：${child}`);
    }
  }
  return result;
}

function writeString(buffer, offset, length, value) {
  const encoded = Buffer.from(value, 'utf8');
  if (encoded.length > length) fail(`tar 字段过长：${value}`);
  encoded.copy(buffer, offset);
}

function writeOctal(buffer, offset, length, value) {
  const encoded = Math.trunc(value).toString(8).padStart(length - 1, '0');
  if (encoded.length > length - 1) fail('tar 数值字段溢出');
  writeString(buffer, offset, length, `${encoded}\0`);
}

function splitTarPath(path) {
  if (Buffer.byteLength(path) <= 100) return { name: path, prefix: '' };
  for (let index = path.length - 1; index > 0; index -= 1) {
    if (path[index] !== '/') continue;
    const prefix = path.slice(0, index);
    const name = path.slice(index + 1);
    if (Buffer.byteLength(name) <= 100 && Buffer.byteLength(prefix) <= 155) {
      return { name, prefix };
    }
  }
  fail(`tar 路径过长：${path}`);
}

function tarHeader(path, size, mode, directory) {
  const header = Buffer.alloc(512, 0);
  const parts = splitTarPath(path);
  writeString(header, 0, 100, parts.name);
  writeOctal(header, 100, 8, mode);
  writeOctal(header, 108, 8, 0);
  writeOctal(header, 116, 8, 0);
  writeOctal(header, 124, 12, size);
  writeOctal(header, 136, 12, 0);
  header.fill(0x20, 148, 156);
  header[156] = directory ? 0x35 : 0x30;
  writeString(header, 257, 6, 'ustar\0');
  writeString(header, 263, 2, '00');
  writeString(header, 345, 155, parts.prefix);
  const checksum = header.reduce((sum, byte) => sum + byte, 0);
  const encoded = checksum.toString(8).padStart(6, '0');
  writeString(header, 148, 8, `${encoded}\0 `);
  return header;
}

async function createArchive(packageRoot) {
  // 中文注释：目录按路径排序、权限归一且时间戳固定为零，确保同一输入只生成同一份正式归档。
  const tree = await listTree(packageRoot);
  const chunks = [tarHeader('tatachatsdk/', 0, 0o755, true)];
  for (const entry of tree) {
    const archivePath = `tatachatsdk/${entry.path}${entry.directory ? '/' : ''}`;
    chunks.push(tarHeader(archivePath, entry.directory ? 0 : entry.bytes.length, entry.mode, entry.directory));
    if (!entry.directory) {
      chunks.push(entry.bytes);
      const padding = (512 - (entry.bytes.length % 512)) % 512;
      if (padding > 0) chunks.push(Buffer.alloc(padding, 0));
    }
  }
  chunks.push(Buffer.alloc(1024, 0));
  return gzipSync(Buffer.concat(chunks), { level: 9, mtime: 0 });
}

function parseOctal(buffer, offset, length, label) {
  const text = buffer.subarray(offset, offset + length).toString('ascii').replace(/\0.*$/s, '').trim();
  if (!/^[0-7]*$/.test(text)) fail(`tar ${label} 不是八进制数`);
  return text ? Number.parseInt(text, 8) : 0;
}

function readTarString(buffer, offset, length) {
  return buffer.subarray(offset, offset + length).toString('utf8').replace(/\0.*$/s, '');
}

function validateArchivePath(path, directory) {
  if (!path.startsWith('tatachatsdk/')) fail(`tar 路径不属于 TataChatSDK：${path}`);
  const logical = directory && path.endsWith('/') ? path.slice(0, -1) : path;
  normalizeRelativePath(logical);
  return logical;
}

export function parseTar(archiveBytes) {
  const tar = gunzipSync(archiveBytes);
  const entries = new Map();
  let offset = 0;
  while (offset + 512 <= tar.length) {
    const header = tar.subarray(offset, offset + 512);
    if (header.every((byte) => byte === 0)) break;
    const expectedChecksum = parseOctal(header, 148, 8, '校验和');
    const checksumHeader = Buffer.from(header);
    checksumHeader.fill(0x20, 148, 156);
    const actualChecksum = checksumHeader.reduce((sum, byte) => sum + byte, 0);
    if (expectedChecksum !== actualChecksum) fail('tar 头校验和错误');

    const name = readTarString(header, 0, 100);
    const prefix = readTarString(header, 345, 155);
    const path = prefix ? `${prefix}/${name}` : name;
    const type = String.fromCharCode(header[156] || 0x30);
    if (type !== '0' && type !== '5') fail(`tar 禁止的条目类型：${type}`);
    const directory = type === '5';
    const logicalPath = validateArchivePath(path, directory);
    const size = parseOctal(header, 124, 12, '文件大小');
    if (directory && size !== 0) fail(`tar 目录包含数据：${logicalPath}`);
    const dataStart = offset + 512;
    const dataEnd = dataStart + size;
    if (dataEnd > tar.length) fail(`tar 条目被截断：${logicalPath}`);
    if (entries.has(logicalPath)) fail(`tar 条目重复：${logicalPath}`);
    entries.set(logicalPath, {
      directory,
      bytes: directory ? null : Buffer.from(tar.subarray(dataStart, dataEnd)),
    });
    offset = dataStart + Math.ceil(size / 512) * 512;
  }
  return entries;
}

function expectedPlatforms() {
  return PLATFORM_ARTIFACTS.map(({ platform, architecture, path }) => ({
    architecture,
    artifact: path,
    platform,
  }));
}

function validatePlatformArtifacts(archiveEntries) {
  for (const artifact of PLATFORM_ARTIFACTS) {
    const root = `tatachatsdk/${artifact.path}`;
    if (artifact.requiredFiles) {
      for (const relativePath of artifact.requiredFiles) {
        const entry = archiveEntries.get(`${root}/${relativePath}`);
        if (!entry || entry.directory) fail(`TataChatSDK ${artifact.platform} 原生资产结构不完整`);
      }
    } else {
      const entry = archiveEntries.get(root);
      if (!entry || entry.directory) fail(`TataChatSDK ${artifact.platform} 原生资产缺失`);
    }
  }
}

function validateManifest(manifest, expectedGitSha, expectedSoftwareVersion, archiveEntries) {
  assertExactKeys(
    manifest,
    ['files', 'git_commit_sha', 'package_name', 'platforms', 'product_id', 'software_version'],
    'TataChatSDK Release manifest',
  );
  if (manifest.product_id !== PRODUCT_ID) fail('TataChatSDK Release product_id 错误');
  if (manifest.package_name !== PACKAGE_NAME) fail('TataChatSDK Release package_name 错误');
  if (!/^[0-9a-f]{40}$/.test(manifest.git_commit_sha)) fail('TataChatSDK Release git_commit_sha 非法');
  if (expectedGitSha && manifest.git_commit_sha !== expectedGitSha) fail('TataChatSDK Release 源提交不一致');
  if (typeof manifest.software_version !== 'string' || manifest.software_version.length === 0) {
    fail('TataChatSDK Release software_version 非法');
  }
  if (expectedSoftwareVersion && manifest.software_version !== expectedSoftwareVersion) {
    fail('TataChatSDK Release 软件版本不一致');
  }
  if (JSON.stringify(manifest.platforms) !== JSON.stringify(expectedPlatforms())) {
    fail('TataChatSDK Release 平台闭包错误');
  }
  validatePlatformArtifacts(archiveEntries);
  if (!Array.isArray(manifest.files)) fail('TataChatSDK Release files 必须是数组');

  const archiveFiles = [...archiveEntries.entries()]
    .filter(([path, entry]) => !entry.directory
      && ![`tatachatsdk/${MANIFEST_NAME}`, `tatachatsdk/${CHECKSUMS_NAME}`].includes(path))
    .map(([path, entry]) => ({ path: path.slice('tatachatsdk/'.length), bytes: entry.bytes }))
    .sort((left, right) => left.path.localeCompare(right.path));
  const expectedFileRecords = archiveFiles.map(({ path, bytes }) => ({
    path,
    sha256: sha256(bytes),
    size: bytes.length,
  }));
  for (const record of manifest.files) {
    assertExactKeys(record, ['path', 'sha256', 'size'], `TataChatSDK Release 文件记录 ${record?.path ?? ''}`);
  }
  if (JSON.stringify(manifest.files) !== JSON.stringify(expectedFileRecords)) {
    fail('TataChatSDK Release 文件清单与归档内容不一致');
  }
}

function verifyInternalChecksums(archiveEntries, bytes) {
  const lines = bytes.toString('utf8').trimEnd().split('\n');
  const result = new Map();
  for (const line of lines) {
    const match = line.match(/^([0-9a-f]{64})  ([A-Za-z0-9._/-]+)$/);
    if (!match || result.has(match[2])) fail('SHA256SUMS 格式或资产名称错误');
    result.set(match[2], match[1]);
  }
  const expected = [...archiveEntries.entries()]
    .filter(([path, entry]) => !entry.directory && path !== `tatachatsdk/${CHECKSUMS_NAME}`)
    .map(([path, entry]) => [path.slice('tatachatsdk/'.length), sha256(entry.bytes)])
    .sort(([left], [right]) => left.localeCompare(right));
  if (JSON.stringify([...result.entries()].sort(([left], [right]) => left.localeCompare(right)))
      !== JSON.stringify(expected)) fail('SHA256SUMS 与单包内部文件闭集不一致');
}

export async function verifyReleaseAssets(directory, options = {}) {
  const names = (await readdir(directory)).sort();
  if (JSON.stringify(names) !== JSON.stringify([...RELEASE_ASSETS].sort())) {
    fail('TataChatSDK 正式 Release 必须且只能包含一个包');
  }
  const archiveBytes = await readFile(join(directory, ARCHIVE_NAME));
  const entries = parseTar(archiveBytes);
  const internalManifest = entries.get(`tatachatsdk/${MANIFEST_NAME}`);
  if (!internalManifest || internalManifest.directory) fail('归档缺少 TataChatSDK Release manifest');
  const internalChecksums = entries.get(`tatachatsdk/${CHECKSUMS_NAME}`);
  if (!internalChecksums || internalChecksums.directory) fail('归档缺少 TataChatSDK SHA256SUMS');
  verifyInternalChecksums(entries, internalChecksums.bytes);
  const manifest = JSON.parse(internalManifest.bytes.toString('utf8'));
  validateManifest(manifest, options.expectedGitSha, options.softwareVersion, entries);
  return manifest;
}

export async function buildRelease({ source, native, output, archive, gitSha, softwareVersion }) {
  if (!/^[0-9a-f]{40}$/.test(gitSha)) fail('构建 TataChatSDK Release 必须提供 40 位小写源提交 SHA');
  if (!softwareVersion || typeof softwareVersion !== 'string') fail('构建 TataChatSDK Release 必须提供软件版本');
  if (basename(archive) !== ARCHIVE_NAME) fail(`TataChatSDK Release 归档名必须是 ${ARCHIVE_NAME}`);
  for (const entry of SOURCE_ENTRIES) await access(join(source, entry), fsConstants.R_OK);

  const temporary = await mkdtemp(join(tmpdir(), 'tatachatsdk-release-'));
  const packageRoot = join(temporary, 'tatachatsdk');
  try {
    await mkdir(packageRoot, { recursive: true });
    for (const entry of SOURCE_ENTRIES) await copySourceTree(source, packageRoot, entry);
    // 包介绍只属于输出载荷；产品技术文档不复制进公开源码仓。
    await writeFile(join(packageRoot, 'README.md'),
      `# TataChatSDK\n\nIndependent end-to-end encrypted chat SDK.\n\n`
      + `Package: ${PACKAGE_NAME}\nVersion: ${softwareVersion}\nSource commit: ${gitSha}\n\n`
      + 'Source: https://github.com/tuyutata/tatachatsdk\n', 'utf8');
    for (const artifact of PLATFORM_ARTIFACTS) {
      const input = join(native, artifact.source);
      const destination = join(packageRoot, artifact.path);
      await copyNativeArtifact(input, destination, `TataChatSDK ${artifact.platform} 原生资产`);
    }

    // 中文注释：manifest 只登记业务载荷；内部校验清单再覆盖载荷和 manifest，避免任何自引用字段。
    const files = (await listTree(packageRoot))
      .filter((entry) => !entry.directory)
      .map((entry) => ({ path: entry.path, sha256: sha256(entry.bytes), size: entry.bytes.length }))
      .sort((left, right) => left.path.localeCompare(right.path));
    const manifest = {
      files,
      git_commit_sha: gitSha,
      package_name: PACKAGE_NAME,
      platforms: expectedPlatforms(),
      product_id: PRODUCT_ID,
      software_version: softwareVersion,
    };
    const manifestBytes = Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
    await writeFile(join(packageRoot, MANIFEST_NAME), manifestBytes);
    const checksumRows = [
      ...files.map(({ path, sha256: digest }) => [path, digest]),
      [MANIFEST_NAME, sha256(manifestBytes)],
    ].sort(([left], [right]) => left.localeCompare(right));
    await writeFile(
      join(packageRoot, CHECKSUMS_NAME),
      Buffer.from(`${checksumRows.map(([path, digest]) => `${digest}  ${path}`).join('\n')}\n`, 'utf8'),
    );
    const archiveBytes = await createArchive(packageRoot);

    await rm(output, { recursive: true, force: true });
    await mkdir(output, { recursive: true });
    const finalArchive = join(output, ARCHIVE_NAME);
    await writeFile(finalArchive, archiveBytes);
    if (resolve(archive) !== resolve(finalArchive)) {
      await mkdir(dirname(archive), { recursive: true });
      await copyFile(finalArchive, archive);
    }
    await verifyReleaseAssets(output, { expectedGitSha: gitSha, softwareVersion });
    return manifest;
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

function parseArguments(argv) {
  const options = new Map();
  let command = 'build';
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--verify') command = 'verify';
    else if (value === '--verify-assets') command = 'verify-assets';
    else if (value.startsWith('--')) {
      const next = argv[index + 1];
      if (!next || next.startsWith('--')) fail(`参数缺少值：${value}`);
      options.set(value.slice(2), next);
      index += 1;
    } else if (command === 'verify' && !options.has('directory')) options.set('directory', value);
    else if (command === 'verify-assets' && !options.has('directory')) options.set('directory', value);
    else fail(`未知参数：${value}`);
  }
  return { command, options };
}

async function main() {
  if (['flutter-source-view', 'verify-flutter-source-view'].includes(process.argv[2])) {
    if (process.argv.length !== 5) fail('用法：release.mjs <flutter-source-view|verify-flutter-source-view> SOURCE OUTPUT');
    const action = process.argv[2] === 'flutter-source-view' ? createFlutterSourceView : assertFlutterSourceView;
    process.stdout.write(await action(process.argv[3], process.argv[4]) + '\n');
    return;
  }
  const { command, options } = parseArguments(process.argv.slice(2));
  if (command === 'verify' || command === 'verify-assets') {
    const directory = options.get('directory');
    if (!directory) fail('验真必须提供 Release 资产目录');
    await verifyReleaseAssets(directory, {
      expectedGitSha: options.get('expected-git-sha'),
      softwareVersion: options.get('software-version'),
    });
    process.stdout.write('TataChatSDK Release assets verified\n');
    return;
  }
  const required = ['source', 'native', 'output', 'archive', 'git-sha', 'software-version'];
  for (const key of required) if (!options.has(key)) fail(`构建缺少参数：--${key}`);
  await buildRelease({
    source: options.get('source'),
    native: options.get('native'),
    output: options.get('output'),
    archive: options.get('archive'),
    gitSha: options.get('git-sha'),
    softwareVersion: options.get('software-version'),
  });
  process.stdout.write('TataChatSDK Release assets built and verified\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
