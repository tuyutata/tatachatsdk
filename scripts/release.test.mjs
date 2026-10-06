import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmod, lstat, mkdtemp, mkdir, readFile, realpath, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { gzipSync, gunzipSync } from 'node:zlib';

import { buildRelease, verifyReleaseAssets, createFlutterSourceView, assertFlutterSourceView } from './release.mjs';

const SHA = '0123456789abcdef0123456789abcdef01234567';

test('protocol generator uses only TataChatSDK exact tools', async () => {
  const dependencyPath = fileURLToPath(new URL('./dependencies.mjs', import.meta.url));
  const dependencySource = await readFile(dependencyPath, 'utf8');
  const generator = await readFile(new URL('./generate-protocol.sh', import.meta.url), 'utf8');
  const contract = JSON.parse(await readFile(new URL('./dependencies.json', import.meta.url), 'utf8'));
  assert.equal(contract.tools.protoc.version, '35.0');
  assert.equal(contract.tools.protoc.source,
    'https://github.com/protocolbuffers/protobuf/releases/tag/v35.0');
  assert.deepEqual(Object.keys(contract.tools.protoc.archives).sort(),
    ['linux-amd', 'linux-arm', 'macos', 'windows']);
  assert.equal(contract.tools.protoc_plugin.version, '25.0.0');
  assert.equal(contract.tools.protoc_plugin.source,
    'https://pub.dev/packages/protoc_plugin/versions/25.0.0');
  assert.deepEqual(contract.tools.protoc_plugin.archive, {
    url: 'https://pub.dev/api/archives/protoc_plugin-25.0.0.tar.gz',
    sha256: 'd1ea363e9118f954d9d482c2f7281c5ff5149b059e68672d1faa564d49091f05',
    executable: 'protoc-gen-dart',
  });
  assert.match(dependencySource, /PUB_CACHE: pubCache/u);
  assert.match(dependencySource, /'pub', 'get', \.\.\.\(offline/u);
  assert.match(dependencySource, /'--enforce-lockfile'/u);
  assert.match(dependencySource, /'compile', 'exe'/u);
  assert.match(dependencySource, /'--packages=' \+ packageConfig/u);
  assert.doesNotMatch(dependencySource, /'global', 'activate'/u);
  assert.match(dependencySource, /fileInventory\(preparedSource\)/u);
  assert.match(dependencySource, /offline \? \['--offline'\] : \[\]/u);
  assert.match(dependencySource, /protoc_plugin准备源码与官方归档不一致/u);
  assert.match(dependencySource, /`libprotoc \$\{protocVersion\}`/u);
  assert.match(generator, /dependencies[.]mjs" prepare protoc /u);
  assert.match(generator, /dependencies[.]mjs" prepare protoc_plugin sdk/u);
  assert.match(generator, /--plugin="protoc-gen-dart=\$plugin_executable"/u);
  const pathLookup = new RegExp(['command', '-v', 'protoc'].join(' '), 'u');
  assert.doesNotMatch(generator, pathLookup);
  assert.doesNotMatch(generator, /(^|\s)protoc\s+\\/mu);

  const invalid = spawnSync(process.execPath, [dependencyPath], { encoding: 'utf8' });
  assert.notEqual(invalid.status, 0);
  assert.match(invalid.stderr, /TataChatSDK工具参数无效/u);
  const sourceWork = spawnSync(process.execPath,
    [dependencyPath, 'prepare', 'protoc', 'macos', fileURLToPath(new URL('../', import.meta.url))],
    { encoding: 'utf8' });
  assert.notEqual(sourceWork.status, 0);
  assert.match(sourceWork.stderr, /不得写入源码目录/u);
});

test('protocol tool preparer rejects a symlink work directory', async () => {
  const dependencyPath = fileURLToPath(new URL('./dependencies.mjs', import.meta.url));
  const root = await mkdtemp(join(tmpdir(), 'tatachatsdk-protocol-tool-test-'));
  const actual = join(root, 'actual');
  const linked = join(root, 'linked');
  try {
    await mkdir(actual);
    await symlink(actual, linked, 'dir');
    const result = spawnSync(process.execPath,
      [dependencyPath, 'prepare', 'protoc_plugin', 'sdk', linked], { encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /工具工作目录禁止符号链接/u);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});


// 离线拒绝用例阻断网络和工具进程；若错误路径触发它们，真实准备入口必须使断言失败。
const offlineGuard = 'data:text/javascript,' + encodeURIComponent([
  "import childProcess from 'node:child_process';",
  "import { syncBuiltinESMExports } from 'node:module';",
  "globalThis.fetch = () => { process.stderr.write('UNEXPECTED_NETWORK\\n'); throw new Error('UNEXPECTED_NETWORK'); };",
  "childProcess.spawnSync = () => { process.stderr.write('UNEXPECTED_TOOL\\n'); throw new Error('UNEXPECTED_TOOL'); };",
  'syncBuiltinESMExports();',
].join('\n'));

function offlinePreparation(tool, platform, work, flag = '1') {
  const dependencyPath = fileURLToPath(new URL('./dependencies.mjs', import.meta.url));
  const result = spawnSync(process.execPath, [
    '--import', offlineGuard, dependencyPath, 'prepare', tool, platform, work,
  ], {
    encoding: 'utf8',
    timeout: 5_000,
    env: { ...process.env, TATACHATSDK_PROTOCOL_OFFLINE: flag },
  });
  assert.equal(result.error, undefined);
  assert.equal(result.signal, null);
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.doesNotMatch(result.stderr, /UNEXPECTED_NETWORK|UNEXPECTED_TOOL/u);
  return result;
}

test('协议准备器在创建目录前拒绝非法离线参数', async () => {
  const root = await mkdtemp(join(tmpdir(), 'tatachatsdk-offline-option-'));
  try {
    const work = join(root, 'work');
    for (const flag of ['', '0', 'true', '2']) {
      const result = offlinePreparation('protoc', 'macos', work, flag);
      assert.match(result.stderr, /离线参数仅接受1/u);
      await assert.rejects(lstat(work), { code: 'ENOENT' });
    }
  } finally { await rm(root, { recursive: true, force: true }); }
});

test('两项协议工具的离线缺失原件不会联网或启动工具', async () => {
  const root = await mkdtemp(join(tmpdir(), 'tatachatsdk-offline-missing-'));
  try {
    for (const [tool, platform] of [['protoc', 'macos'], ['protoc_plugin', 'sdk']]) {
      const work = join(root, tool);
      const result = offlinePreparation(tool, platform, work);
      assert.match(result.stderr, /离线工具原件缺失/u);
      await assert.rejects(lstat(join(work, 'payload')), { code: 'ENOENT' });
      await assert.rejects(lstat(join(work, 'verified-source')), { code: 'ENOENT' });
      await assert.rejects(lstat(join(work, 'pub-cache')), { code: 'ENOENT' });
    }
  } finally { await rm(root, { recursive: true, force: true }); }
});

test('离线损坏及非普通原件拒绝且保留既有原件和输出', async () => {
  const root = await mkdtemp(join(tmpdir(), 'tatachatsdk-offline-invalid-'));
  try {
    for (const [tool, platform, name] of [
      ['protoc', 'macos', 'protoc-35.0-osx-aarch_64.zip'],
      ['protoc_plugin', 'sdk', 'protoc_plugin-25.0.0.tar.gz'],
    ]) {
      const work = join(root, tool);
      const output = join(work, tool === 'protoc' ? 'payload' : 'verified-source');
      await mkdir(output, { recursive: true });
      const sentinel = join(output, 'sentinel');
      await writeFile(sentinel, '既有输出');
      const archive = join(work, name);
      await writeFile(archive, '损坏原件');
      assert.match(offlinePreparation(tool, platform, work).stderr, /离线工具原件摘要不符/u);
      assert.equal(await readFile(archive, 'utf8'), '损坏原件');
      assert.equal(await readFile(sentinel, 'utf8'), '既有输出');
      await rm(archive);
      const target = join(work, 'target');
      await writeFile(target, '外部目标');
      await symlink(target, archive);
      assert.match(offlinePreparation(tool, platform, work).stderr, /离线工具原件必须为普通文件/u);
      assert.equal((await lstat(archive)).isSymbolicLink(), true);
      assert.equal(await readFile(target, 'utf8'), '外部目标');
      await rm(archive);
      await mkdir(archive);
      assert.match(offlinePreparation(tool, platform, work).stderr, /离线工具原件必须为普通文件/u);
      assert.equal((await lstat(archive)).isDirectory(), true);
      assert.equal(await readFile(sentinel, 'utf8'), '既有输出');
    }
  } finally { await rm(root, { recursive: true, force: true }); }
});

test('native build and CocoaPods consume only TataChatSDK product directories', async () => {
  const native = await readFile(new URL('./build-native.sh', import.meta.url), 'utf8');
  const podspec = await readFile(new URL('../ios/tatachat_sdk.podspec', import.meta.url), 'utf8');
  for (const name of [
    'TATACHATSDK_WORK_DIR',
    'TATACHATSDK_NATIVE_ANDROID_DIR',
    'TATACHATSDK_NATIVE_IOS_DIR',
    'TATACHATSDK_NATIVE_MACOS_DIR',
  ]) assert.match(native, new RegExp(name));
  assert.match(native, /TataChatSDK可写目录必须是源码外绝对路径/u);
  assert.doesNotMatch(native, /PACKAGE_IOS_DIR|\/Users\//u);
  assert.match(podspec, /framework_path = 'TataChatSDK\.xcframework'/u);
  assert.match(podspec, /Dir\.exist\?\(File\.join\(__dir__, framework_path\)\)/u);
  assert.match(podspec, /spec\.vendored_frameworks = framework_path/u);
  assert.doesNotMatch(podspec, /TATACHATSDK_APPLE_FRAMEWORK_DIR|Pathname|relative_path_from|File\.symlink|\/Users\//u);
});

// 每个夹具都使用隔离临时目录，验证完成后必须连同伪造产物一起清理。
async function fixture() {
  const root = await mkdtemp(join(tmpdir(), 'tatachatsdk-release-test-'));
  const source = join(root, 'source');
  const native = join(root, 'native');
  const output = join(root, 'output');
  await mkdir(source, { recursive: true });
  for (const file of [
    'CHANGELOG.md',
    'LICENSE',
    'README.md',
    'analysis_options.yaml',
    'pubspec.yaml',
    'pubspec.lock',
    'tatachat_sdk.h',
  ]) {
    await writeFile(join(source, file), `${file}\n`);
  }
  for (const directory of ['ios', 'lib', 'native', 'stickers']) {
    await mkdir(join(source, directory), { recursive: true });
    await writeFile(join(source, directory, `${directory}.txt`), `${directory}\n`);
  }
  const artifacts = [
    ['android', 'libtatachat_sdk.so'],
    ['macos', 'libtatachat_sdk.dylib'],
  ];
  for (const [directory, name] of artifacts) {
    await mkdir(join(native, directory), { recursive: true });
    await writeFile(join(native, directory, name), `${directory}-binary`);
  }
  const iosFramework = join(
    native,
    'ios',
    'TataChatSDK.xcframework',
    'ios-arm64',
    'TataChatSDK.framework',
  );
  await mkdir(iosFramework, { recursive: true });
  await writeFile(join(native, 'ios', 'TataChatSDK.xcframework', 'Info.plist'), 'xcframework\n');
  await writeFile(join(iosFramework, 'Info.plist'), 'framework\n');
  await writeFile(join(iosFramework, 'TataChatSDK'), 'ios-dynamic-binary');
  await chmod(join(iosFramework, 'TataChatSDK'), 0o755);
  // 同一夹具必须包含Simulator切片。
  const simulator = join(native, 'ios', 'TataChatSDK.xcframework', 'ios-arm64-simulator', 'TataChatSDK.framework');
  await mkdir(simulator, { recursive: true });
  await writeFile(join(simulator, 'Info.plist'), 'simulator-framework\n');
  await writeFile(join(simulator, 'TataChatSDK'), 'simulator-dynamic-binary');
  await chmod(join(simulator, 'TataChatSDK'), 0o755);
  const build = () => buildRelease({
    source,
    native,
    output,
    archive: join(output, 'tatachatsdk.tgz'),
    gitSha: SHA,
    softwareVersion: '1.0.0',
  });
  return { root, source, native, output, build };
}

test('builds and verifies one deterministic TataChatSDK package', async () => {
  const item = await fixture();
  try {
    await item.build();
    const first = await readFile(join(item.output, 'tatachatsdk.tgz'));
    await item.build();
    const second = await readFile(join(item.output, 'tatachatsdk.tgz'));
    assert.deepEqual(first, second);
    const manifest = await verifyReleaseAssets(item.output, { expectedGitSha: SHA, softwareVersion: '1.0.0' });
    assert.equal(manifest.package_name, 'tatachat_sdk');
    assert.equal(manifest.product_id, 'tatachatsdk');
    assert.equal(manifest.platforms.length, 3);
    assert.equal(
      manifest.platforms.find(({ platform }) => platform === 'ios').artifact,
      'prebuilt/ios-arm64/TataChatSDK.xcframework',
    );
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});


// 平台布局属于SDK；测试实际装配和回读，不用字符串匹配替代来源隔离。
async function flutterViewFixture(t) {
  const root = await realpath(await mkdtemp(join(tmpdir(), 'tatachatsdk-view-')));
  t.after(() => rm(root, { recursive: true, force: true }));
  const source = join(root, 'source'), output = join(root, 'view');
  await mkdir(join(source, 'android'), { recursive: true });
  await writeFile(join(source, 'pubspec.yaml'),
    'name: tatachat_sdk\nflutter:\n  plugin:\n    platforms:\n      android:\n        package: chat.tata.sdk\n        pluginClass: TataChatSdkPlugin\n');
  await writeFile(join(source, 'pubspec.lock'), 'packages: {}\n');
  await writeFile(join(source, 'android/TataChatSdkPlugin.java'),
    'package chat.tata.sdk;\npublic class TataChatSdkPlugin {}\n');
  await writeFile(join(source, 'android/AndroidManifest.xml'), '<manifest/>\n');
  await writeFile(join(source, 'android/build.gradle.kts'), '// fixture\n');
  return { root, source, output };
}

test('Flutter视图装配唯一Android入口且Pub写入不改变源码', async t => {
  const { source, output } = await flutterViewFixture(t);
  await mkdir(join(source, 'build'));
  await writeFile(join(source, 'build/old'), 'ignored');
  await createFlutterSourceView(source, output);
  const plugin = join(output, 'android/src/main/java/chat/tata/sdk/TataChatSdkPlugin.java');
  assert.equal(await realpath(plugin), join(source, 'android/TataChatSdkPlugin.java'));
  assert.equal(await realpath(join(output, 'android/src/main/AndroidManifest.xml')),
    join(source, 'android/AndroidManifest.xml'));
  await assert.rejects(lstat(join(output, 'android/TataChatSdkPlugin.java')), { code: 'ENOENT' });
  await assert.rejects(lstat(join(output, 'build')), { code: 'ENOENT' });
  assert.equal(await assertFlutterSourceView(source, output), output);
  await assert.rejects(createFlutterSourceView(source, output), /已存在/u);
  const original = await readFile(join(source, 'pubspec.yaml'), 'utf8');
  await writeFile(join(output, 'pubspec.yaml'), 'name: changed\n');
  assert.equal(await readFile(join(source, 'pubspec.yaml'), 'utf8'), original);
  await assert.rejects(assertFlutterSourceView(source, output), /漂移/u);
});

test('Flutter视图拒绝回写源码、链接、身份不符和重复入口', async t => {
  const { root, source, output } = await flutterViewFixture(t);
  await assert.rejects(createFlutterSourceView(source, join(source, 'view')), /必须分离/u);
  await symlink(source, join(root, 'alias'), 'dir');
  await assert.rejects(createFlutterSourceView(join(root, 'alias'), output), /普通目录/u);
  await symlink(join(source, 'pubspec.yaml'), join(source, 'linked'));
  await assert.rejects(createFlutterSourceView(source, output), /禁止链接/u);
  await rm(join(source, 'linked'));
  const plugin = join(source, 'android/TataChatSdkPlugin.java');
  const bytes = await readFile(plugin);
  await writeFile(plugin, 'package wrong;\nclass TataChatSdkPlugin {}\n');
  await assert.rejects(createFlutterSourceView(source, output), /身份/u);
  await writeFile(plugin, bytes);
  const duplicate = join(source, 'android/src/main/java/chat/tata/sdk');
  await mkdir(duplicate, { recursive: true });
  await writeFile(join(duplicate, 'TataChatSdkPlugin.java'), bytes);
  await assert.rejects(createFlutterSourceView(source, output), /重复/u);
  await assert.rejects(lstat(output), { code: 'ENOENT' });
});

test('Flutter视图拒绝入口替换为副本并支持产品独立命令', async t => {
  const { source, output } = await flutterViewFixture(t);
  const script = fileURLToPath(new URL('./release.mjs', import.meta.url));
  const run = command => spawnSync(process.execPath, [script, command, source, output], { encoding: 'utf8' });
  const created = run('flutter-source-view');
  assert.equal(created.status, 0, created.stderr);
  assert.equal(run('verify-flutter-source-view').status, 0);
  const entry = join(output, 'android/src/main/java/chat/tata/sdk/TataChatSdkPlugin.java');
  const bytes = await readFile(entry);
  await rm(entry);
  await writeFile(entry, bytes);
  await assert.rejects(assertFlutterSourceView(source, output), /来源绑定/u);
});

test('rejects the wrong source SHA', async () => {
  const item = await fixture();
  try {
    await item.build();
    await assert.rejects(
      verifyReleaseAssets(item.output, { expectedGitSha: 'f'.repeat(40), softwareVersion: '1.0.0' }),
      /源提交不一致/,
    );
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects a missing native artifact', async () => {
  const item = await fixture();
  try {
    await rm(join(item.native, 'ios', 'TataChatSDK.xcframework'), { recursive: true });
    await assert.rejects(item.build(), /原生资产/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

// 任一切片必需文件缺失都必须拒绝打包。
for (const variant of ['ios-arm64', 'ios-arm64-simulator']) {
  for (const file of ['TataChatSDK', 'Info.plist']) {
    test('rejects missing iOS slice file: ' + variant + '/' + file, async () => {
      const item = await fixture();
      try {
        await rm(join(item.native, 'ios', 'TataChatSDK.xcframework', variant, 'TataChatSDK.framework', file));
        await assert.rejects(item.build(), /原生资产/);
      } finally {
        await rm(item.root, { recursive: true, force: true });
      }
    });
  }
}

test('rejects source symlinks', async () => {
  const item = await fixture();
  try {
    await symlink(join(item.source, 'README.md'), join(item.source, 'lib', 'linked.md'));
    await assert.rejects(item.build(), /禁止符号链接/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects symlinks inside the iOS XCFramework', async () => {
  const item = await fixture();
  try {
    const binary = join(
      item.native,
      'ios',
      'TataChatSDK.xcframework',
      'ios-arm64',
      'TataChatSDK.framework',
      'TataChatSDK',
    );
    await rm(binary);
    await symlink('/tmp/forbidden-chat-sdk', binary);
    await assert.rejects(item.build(), /符号链接/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects extra release assets and tampered internal checksums', async () => {
  const item = await fixture();
  try {
    await item.build();
    await writeFile(join(item.output, 'extra.bin'), 'extra');
    await assert.rejects(verifyReleaseAssets(item.output), /必须且只能包含一个包/);
    await rm(join(item.output, 'extra.bin'));
    const archivePath = join(item.output, 'tatachatsdk.tgz');
    const tar = gunzipSync(await readFile(archivePath));
    const checksumHeader = tar.indexOf(Buffer.from('tatachatsdk/SHA256SUMS'));
    assert.notEqual(checksumHeader, -1);
    const firstHashByte = checksumHeader + 512;
    tar[firstHashByte] = tar[firstHashByte] === 0x30 ? 0x31 : 0x30;
    await writeFile(archivePath, gzipSync(tar, { level: 9, mtime: 0 }));
    await assert.rejects(verifyReleaseAssets(item.output), /单包内部文件闭集不一致/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects a path-traversal tar entry', async () => {
  const item = await fixture();
  try {
    await item.build();
    const archivePath = join(item.output, 'tatachatsdk.tgz');
    const tar = gunzipSync(await readFile(archivePath));
    tar.fill(0, 0, 100);
    Buffer.from('../escape/').copy(tar, 0);
    tar.fill(0x20, 148, 156);
    const checksum = tar.subarray(0, 512).reduce((sum, byte) => sum + byte, 0);
    Buffer.from(`${checksum.toString(8).padStart(6, '0')}\0 `).copy(tar, 148);
    await writeFile(archivePath, gzipSync(tar, { level: 9, mtime: 0 }));
    await assert.rejects(verifyReleaseAssets(item.output), /非法相对路径|不属于 TataChatSDK/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

// 跨语言通道与方法从SDK实际调用端提取；测试不保存第二份通道合同。
test('聊天存储iOS安全通道由SDK自有插件完整接入', async () => {
  const dart = await readFile(new URL('../lib/src/storage/chat_isar.dart', import.meta.url), 'utf8');
  const native = await readFile(new URL('../ios/TataChatSdkPlugin.swift', import.meta.url), 'utf8');
  const channel = dart.match(/_securityChannel = MethodChannel\(\s*'([^']+)'/u)[1];
  const method = dart.match(/_securityChannel.invokeMethod<void>\('([^']+)'/u)[1];
  assert.ok(native.includes(`name: "${channel}", binaryMessenger:`));
  assert.ok(native.includes(`call.method == "${method}"`));
  assert.ok(!native.includes('citizenapp/security'));
});

// 真实源码没有 README 副本；打包只在临时包根生成介绍并把它纳入清单与校验。
test('正式包从现存源码生成介绍且不回写源码', async () => {
  const item = await fixture();
  try {
    await rm(join(item.source, 'README.md'));
    const manifest = await item.build();
    assert.equal(await readFile(join(item.source, 'pubspec.yaml'), 'utf8'), 'pubspec.yaml\n');
    await assert.rejects(readFile(join(item.source, 'README.md')), /ENOENT/u);
    assert.equal(manifest.files.filter(file => file.path === 'README.md').length, 1);
    const archive = join(item.output, 'tatachatsdk.tgz');
    const introduction = spawnSync('tar', ['-xOzf', archive, 'tatachatsdk/README.md'], { encoding: 'utf8' });
    assert.equal(introduction.status, 0, introduction.stderr);
    assert.match(introduction.stdout, /https:\/\/github[.]com\/tuyutata\/tatachatsdk/u);
    assert.ok(introduction.stdout.includes(SHA));
    assert.match(introduction.stdout, /Version: 1[.]0[.]0/u);
  } finally { await rm(item.root, { recursive: true, force: true }); }
});
