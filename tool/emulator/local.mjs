import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {access, copyFile, mkdir, readFile, symlink, unlink, writeFile} from 'node:fs/promises';
import {writeFileSync} from 'node:fs';
import {createServer} from 'node:net';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
process.chdir(root);
const mode = process.argv[2];
assert.ok(['start', 'check'].includes(mode) && process.argv.length === 3,
  'Usage: node tool/emulator/local.mjs start|check');
assert.equal(process.versions.node.split('.')[0], '22', 'Select Node 22 first: nvm use');
const project = 'demo-mosigame-e13';
const env = {...process.env, GCLOUD_PROJECT: project, GOOGLE_CLOUD_PROJECT: project,
  PATH: `${dirname(process.execPath)}${process.platform === 'win32' ? ';' : ':'}${process.env.PATH}`,
  JAVA_TOOL_OPTIONS: '-Xms64m -Xmx512m', CI: 'true', FIREBASE_CLI_DISABLE_UPDATE_CHECK: 'true'};
for (const key of ['GOOGLE_APPLICATION_CREDENTIALS', 'FIREBASE_TOKEN', 'FIREBASE_CONFIG',
  'FIREBASE_DATABASE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST', 'STORAGE_EMULATOR_HOST', 'FIREBASE_EMULATOR_HUB']) delete env[key];
const ports = [4000, 4400, 4500, 5001, 8080, 9000, 9099, 9150, 9199];
async function checkPorts() {
  for (const port of ports) await new Promise((ok, fail) => {
    const server = createServer();
    server.once('error', error => fail(new Error(
      `Local emulator port ${port} is unavailable (${error.code ?? 'unknown'}). ` +
      'Stop the existing suite or allow local port binding.',
    )));
    server.listen(port, '127.0.0.1', () => server.close(ok));
  });
}

async function run(args, cwd, timeoutMs, graceful = false) {
  const child = spawn(process.execPath, args, {cwd, env, stdio: 'inherit',
    detached: process.platform !== 'win32', windowsHide: true});
  let interrupted = false, timedOut = false, force;
  const stop = () => {
    if (!child.pid) return;
    if (graceful) {
      // Let emulators:exec see its script finish, so export happens exactly once.
      writeFileSync(resolve(root, 'build/local-firebase/stop'), '');
    } else if (process.platform === 'win32') {
      spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], {stdio: 'ignore', windowsHide: true});
    } else {
      try { process.kill(-child.pid, 'SIGINT'); } catch {}
    }
    // Allow Firebase to export data, then terminate only this launcher's tree.
    force ??= setTimeout(() => {
      if (process.platform === 'win32') {
        spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'],
          {stdio: 'ignore', windowsHide: true});
      } else {
        try { process.kill(-child.pid, 'SIGKILL'); } catch {}
      }
    }, 15000);
  };
  const interrupt = () => { interrupted = true; stop(); };
  process.once('SIGINT', interrupt);
  process.once('SIGTERM', interrupt);
  const timer = timeoutMs ? setTimeout(() => { timedOut = true; stop(); }, timeoutMs) : undefined;
  try {
    const code = await new Promise((ok, fail) => {
      child.once('error', fail); child.once('close', ok);
    });
    assert.equal(timedOut, false, 'Local emulator command exceeded its deadline');
    if (interrupted) { process.exitCode = 130; return false; }
    assert.equal(code, 0, `Local emulator command failed (exit ${code})`);
    return true;
  } finally {
    clearTimeout(timer); clearTimeout(force);
    process.removeListener('SIGINT', interrupt); process.removeListener('SIGTERM', interrupt);
  }
}

await checkPorts();
if (!await run(['functions/node_modules/typescript/bin/tsc', '-p', 'functions'], root, 120000)) process.exit(130);
await mkdir('build/e13-runtime', {recursive: true});
await mkdir('build/e13', {recursive: true});
await mkdir('build/local-firebase', {recursive: true});
const pkg = JSON.parse(await readFile('functions/package.json', 'utf8'));
await writeFile('build/e13-runtime/package.json', JSON.stringify({name: 'mosigame-e13-runtime',
  private: true, main: 'index.cjs', engines: pkg.engines, dependencies: pkg.dependencies}, null, 2));
await copyFile('tool/emulator/functions.cjs', 'build/e13-runtime/index.cjs');
try { await symlink(resolve(root, 'functions/node_modules'), 'build/e13-runtime/node_modules',
  process.platform === 'win32' ? 'junction' : 'dir'); }
catch (error) { if (error.code !== 'EEXIST') throw error; }
await writeFile('build/e13/function-events.jsonl', '');
const args = [resolve(root, 'functions/node_modules/firebase-tools/lib/bin/firebase.js'),
  'emulators:exec', '--project', project, '--config', resolve(root, 'firebase.local.json'),
  '--only', 'auth,database,firestore,functions,storage'];
if (mode === 'start') {
  args.push('--ui');
  await unlink('build/local-firebase/stop').catch(error => { if (error.code !== 'ENOENT') throw error; });
  const data = resolve(root, 'build/local-firebase/data');
  try { await access(resolve(data, 'firebase-export-metadata.json')); args.push('--import', data); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  args.push(`--export-on-exit=${data}`);
}
args.push(mode === 'start' ? 'node ../../tool/emulator/local-session.mjs' :
  'node --test --test-concurrency=1 ../../tool/emulator/local-smoke.test.mjs');
try { await run(args, resolve(root, 'build/local-firebase'), mode === 'check' ? 600000 : undefined, mode === 'start'); }
finally { await checkPorts(); console.log('Local emulator ports released.'); }
