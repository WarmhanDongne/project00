import {existsSync} from 'node:fs';
import {seedLocalFixtures} from './local-fixtures.mjs';

await seedLocalFixtures();
console.log('LOCAL READY — Emulator UI: http://127.0.0.1:4000');
console.log('Test users: tablet@mosigame.test, phone1@mosigame.test … phone4@mosigame.test');
console.log('Synthetic-only password: LocalMosigame123!');
console.log('Run: flutter run --dart-define=MOSIGAME_BACKEND=local');
console.log('Stop with Ctrl+C; local data is exported under build/local-firebase/data.');
const keepAlive = setInterval(() => {
  if (existsSync('stop')) clearInterval(keepAlive);
}, 300);
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => clearInterval(keepAlive));
