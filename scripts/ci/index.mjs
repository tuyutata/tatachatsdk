#!/usr/bin/env node
// CI_BUILD: incremental
// 单平台目录不重复包装 sdk。
// TataChatSDK CI 只校验本仓根的产品契约、源码闭集和固定依赖，不读取其他产品文件。

import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(process.env.TATACHATSDK_REPOSITORY_ROOT || process.cwd());
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
  'scripts/generate-protocol.sh',
  'scripts/release.mjs',
  'scripts/release.test.mjs',
];

function fail(message) {
  throw new Error(message);
}

function read(relativePath) {
  const absolute = resolve(root, relativePath);
  if (!existsSync(absolute)) fail(`缺少普通依赖文件：${relativePath}`);
  const status = lstatSync(absolute);
  if (!status.isFile() || status.isSymbolicLink()) fail(`缺少普通依赖文件：${relativePath}`);
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
  if (actions.length === 0) fail(`${relativePath} 没有登记 GitHub Action`);
  for (const action of actions) {
    // 本仓受控 Action 必须来自当前检出提交；只有本地相对调用可以不带提交后缀。
    if (action.startsWith('./')) continue;
    const revision = action.split('@')[1];
    if (!/^[0-9a-f]{40}$/.test(String(revision || ''))) {
      fail(`${relativePath} 的第三方 GitHub Action 未固定到 40 位提交：${action}`);
    }
  }
}

function checkDependencies(scopeName) {
  if (scopeName !== 'tatachatsdk') fail('TataChatSDK 动作只接受 tatachatsdk 依赖作用域');
  const contract = JSON.parse(read('scripts/dependencies.json'));
  if (contract.schema !== 1) fail('TataChatSDK 依赖契约无效');
  exactArray(contract.routes, expectedRoutes, 'TataChatSDK 路由');
  exactArray(contract.required_files, expectedFiles, 'TataChatSDK 必需文件');
  if (!contract.dart_applications?.includes('.')) fail('TataChatSDK 未登记 Dart 产品');
  if (!contract.cargo_projects?.includes('native')) fail('TataChatSDK 未登记 Rust 产品');
  if (!contract.audited_scopes?.includes('tatachatsdk')) fail('TataChatSDK 未登记安全审计作用域');
  for (const relativePath of expectedFiles) read(relativePath);

  const pubspec = read('pubspec.yaml');
  if (!/^name:\s*tatachat_sdk\s*$/m.test(pubspec)) fail('TataChatSDK pubspec 包名必须是 tatachat_sdk');
  if (!/^version:\s*\d+\.\d{1,2}\.\d{1,2}(?:\+\d+)?\s*$/m.test(pubspec)) {
    fail('TataChatSDK pubspec 软件版本无效');
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
    cwd: resolve(root, 'native'),
    stdio: 'inherit',
    env: process.env,
  });
  if (result.error) fail(`无法启动 cargo audit：${result.error.message}`);
  if (result.status !== 0) fail(`TataChatSDK Rust 依赖安全审计失败：${result.status}`);
}

const [command, subcommand, ...argumentsList] = process.argv.slice(2);
const scopeIndex = argumentsList.indexOf('--scope');
const scope = scopeIndex >= 0 ? argumentsList[scopeIndex + 1] : undefined;

try {
  if (command === 'dependencies' && subcommand === 'check') checkDependencies(scope);
  else if (command === 'dependencies' && subcommand === 'audit') auditDependencies(scope);
  else fail('不支持的 TataChatSDK CI 命令');
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exit(1);
}
