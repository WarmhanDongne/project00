// Isolated client SDK process: never initialize the Admin SDK here.
const {initStandalone} = require('../../functions/node_modules/@firebase/database-compat/standalone');
let db;
process.on('message', async ({id, action, payload}) => {
  try {
    let result = null;
    if (action === 'init') {
      const token = payload.token;
      const app = {name: payload.name, options: {projectId: 'demo-mosigame-e13',
        databaseURL: 'http://127.0.0.1:9000?ns=demo-mosigame-e13-default-rtdb'},
      INTERNAL: {getToken: async () => ({accessToken: token}),
        addAuthTokenListener: listener => listener(token), removeAuthTokenListener() {}}};
      db = initStandalone(app, app.options.databaseURL, 'e13-locked-sdk', false).instance;
      db.useEmulator('127.0.0.1', 9000);
      await db.ref('.info/connected').once('value');
    } else if (action === 'get') result = (await db.ref(payload.path).get()).val();
    else if (action === 'set') await db.ref(payload.path).set(payload.value);
    else if (action === 'disconnect') await db.ref(payload.path).onDisconnect().set(payload.value);
    else if (action === 'watch') {
      db.ref(payload.path).on('value', snapshot => {
        process.send({event: id, value: snapshot.val()});
      }, () => process.send({event: id, error: 'PERMISSION_DENIED'}));
    } else if (action === 'offline') db.goOffline();
    else if (action === 'online') db.goOnline();
    else throw new Error('Unsupported client action');
    process.send({id, result});
  } catch (error) {
    // Do not forward SDK errors which can embed tokens, IDs or private snapshots.
    const permissionDenied = /permission[ _-]denied/i.test(String(error.code ?? error.message));
    process.send({id, error: permissionDenied ? 'PERMISSION_DENIED' : String(error.code ?? 'SDK_ERROR')});
  }
});
