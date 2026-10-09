import assert from 'node:assert/strict';
import {spawn, spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {copyFile, mkdir, readFile, symlink, writeFile} from 'node:fs/promises';
import {createServer} from 'node:net';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
process.chdir(root);
const project = 'demo-mosigame-e13';
const ports = [4400, 4500, 5001, 8080, 9000, 9099, 9150];
const env = {...process.env, GCLOUD_PROJECT: project, GOOGLE_CLOUD_PROJECT: project,
  JAVA_TOOL_OPTIONS: '-Xms64m -Xmx512m', CI: 'true', FIREBASE_CLI_DISABLE_UPDATE_CHECK: 'true'};
for (const key of ['GOOGLE_APPLICATION_CREDENTIALS', 'FIREBASE_TOKEN', 'FIREBASE_CONFIG',
  'FIREBASE_DATABASE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST']) {
  delete env[key];
}

async function checkPorts() {
  for (const port of ports) {
    await new Promise((ok, fail) => {
      const server = createServer();
      server.once('error', () => fail(new Error(`E13 port ${port} is occupied`)));
      server.listen(port, '127.0.0.1', () => server.close(ok));
    });
  }
}

async function snapshot() {
  const files = spawnSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    {cwd: root, encoding: 'utf8', windowsHide: true});
  assert.equal(files.status, 0, 'Cannot capture the repository source snapshot');
  const paths = [...new Set(files.stdout.split('\0').filter(Boolean))].sort();
  const hash = createHash('sha256');
  for (const path of paths) {
    hash.update(path + '\0');
    hash.update(await readFile(resolve(root, path)));
  }
  const state = spawnSync('git', ['status', '--porcelain=v1', '--untracked-files=all'],
    {cwd: root, encoding: 'utf8', windowsHide: true});
  assert.equal(state.status, 0, 'Cannot capture the working-tree state');
  return {sha256: hash.digest('hex'), fileCount: paths.length, state: state.stdout};
}

async function execute(command, args, timeoutMs, cwd = root) {
  const child = spawn(command, args, {cwd, env, stdio: 'inherit',
    detached: process.platform !== 'win32', windowsHide: true});
  let timedOut = false;
  async function terminate() {
    timedOut = true;
    if (process.platform === 'win32') {
      await new Promise(ok => spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'],
        {windowsHide: true, stdio: 'ignore'}).once('close', ok));
    } else {
      try { process.kill(-child.pid, 'SIGTERM'); } catch {}
      const force = setTimeout(() => {
        try { process.kill(-child.pid, 'SIGKILL'); } catch {}
      }, 5000);
      force.unref();
    }
  }
  const timer = setTimeout(terminate, timeoutMs);
  const interrupt = () => void terminate();
  process.once('SIGINT', interrupt);
  process.once('SIGTERM', interrupt);
  try {
    const exit = await new Promise((ok, fail) => {
      child.once('error', fail);
      child.once('close', code => ok(code));
    });
    assert.equal(timedOut, false, 'E13 process exceeded its deadline or was interrupted');
    assert.equal(exit, 0, `E13 command failed (exit ${exit})`);
  } finally {
    clearTimeout(timer);
    process.removeListener('SIGINT', interrupt);
    process.removeListener('SIGTERM', interrupt);
  }
}

const before = await snapshot();
await checkPorts();
await execute(process.execPath, ['functions/node_modules/typescript/bin/tsc', '-p', 'functions'], 120000);
await mkdir('build/e13-runtime', {recursive: true});
const pkg = JSON.parse(await readFile('functions/package.json', 'utf8'));
await writeFile('build/e13-runtime/package.json', JSON.stringify({name: 'mosigame-e13-runtime',
  private: true, main: 'index.cjs', engines: pkg.engines, dependencies: pkg.dependencies}, null, 2));
await copyFile('tool/emulator/functions.cjs', 'build/e13-runtime/index.cjs');
try {
  await symlink(resolve(root, 'functions/node_modules'), 'build/e13-runtime/node_modules',
    process.platform === 'win32' ? 'junction' : 'dir');
} catch (error) { if (error.code !== 'EEXIST') throw error; }
await mkdir('build/e13', {recursive: true});
try {
  await execute(process.execPath, [resolve(root, 'functions/node_modules/firebase-tools/lib/bin/firebase.js'),
    'emulators:exec', '--project', project, '--config', resolve(root, 'firebase.e13.json'),
    '--only', 'auth,database,firestore,functions',
    'node --test --test-concurrency=1 ../../tool/emulator/backend.test.mjs'], 600000, resolve(root, 'build/e13'));
} finally {
  await checkPorts();
  const after = await snapshot();
  const unchanged = JSON.stringify(before) === JSON.stringify(after);
  await writeFile('build/e13/run-result.json', JSON.stringify({project,
    sourceMutation: unchanged ? 'PASS' : 'FAIL', portsReleased: true, before, after}, null, 2));
  assert.equal(unchanged, true, 'E13 execution changed repository source or Git state');
  console.log('E13 emulator port cleanup: PASS');
  console.log('E13 source snapshot comparison: PASS');
}
