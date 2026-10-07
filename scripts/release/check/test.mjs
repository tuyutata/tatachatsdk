import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, existsSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { testRoot as tmpdir } from '../../build.mjs';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

test('tatachatsdk.sdk.release的check远端Job物理独立', () => {
  const source = readFileSync(new URL('./execute.mjs', import.meta.url), 'utf8');
  assert.ok(source.includes('{"pipeline":"tatachatsdk.sdk.release","job":"check"}'));
  assert.match(source, /function runExactWorkflowStep\(index\)/u);
  assert.match(source, /function requireExactRemoteJobEnvironment\(\)/u);
});

// 真实执行产品入口的只读拒绝分支，不联网、不编译、不读取任何发布凭据。
test('独立 SDK Job 拒绝旧聚合仓、其它产品和缺少仓库身份', () => {
  const script = fileURLToPath(new URL('./execute.mjs', import.meta.url));
  for (const repository of ['unregistered-owner/unregistered-product', 'crcfrcn/unregistered-product', 'tuyutata/tatachatserver', 'crcfrcn/citizensdk', '']) {
    const result = spawnSync(process.execPath, [script, 'workflow-step', '999'], {
      encoding: 'utf8', env: { ...process.env, GITHUB_REPOSITORY: repository },
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /准确远端Job仓库身份无效/u);
  }
});

test('Release 候选只接受准确独立 SDK 仓及完整版本输入', () => {
  const script = fileURLToPath(new URL('./execute.mjs', import.meta.url));
  const env = { ...process.env, GITHUB_REPOSITORY: 'tuyutata/tatachatsdk',
    SOURCE_SHA: '0123456789abcdef0123456789abcdef01234567', CI_RUN_ID: '1',
    SOFTWARE_VERSION: '1.0.0', VERSION_TAG: 'tatachatsdk-sdk-v1.0.0' };
  const valid = spawnSync(process.execPath, [script, 'validate-inputs'], { encoding: 'utf8', env });
  assert.equal(valid.status, 0, valid.stderr);
  const invalid = spawnSync(process.execPath, [script, 'validate-inputs'], {
    encoding: 'utf8', env: { ...env, VERSION_TAG: 'tatachatsdk-sdk-v1.0.1' },
  });
  assert.notEqual(invalid.status, 0);
  assert.match(invalid.stderr, /准确Release候选无效/u);
  const boundary = spawnSync(process.execPath, [script, 'workflow-step', '999'], { encoding: 'utf8', env });
  assert.notEqual(boundary.status, 0);
  assert.match(boundary.stderr, /准确远端Job阶段无效/u);
});
