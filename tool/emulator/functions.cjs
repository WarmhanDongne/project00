// Test runtime entry; production firebase.json and functions/src are untouched.
const assert = require('node:assert/strict');
const project = 'demo-mosigame-e13';
assert.equal(process.env.FUNCTIONS_EMULATOR, 'true', 'E13 runtime requires the emulator');
assert.equal(process.env.GCLOUD_PROJECT, project, 'E13 runtime requires the demo project');
const config = JSON.parse(process.env.FIREBASE_CONFIG || '{}');
process.env.FIREBASE_CONFIG = JSON.stringify({...config, projectId: project,
  databaseURL: `https://${project}-default-rtdb.firebaseio.com`});
const candidate = require('../../functions/lib/index.js');
const databaseFunctions = Object.entries(candidate).filter(([, fn]) =>
  fn.__endpoint?.eventTrigger?.eventType?.includes('database'));
assert.equal(databaseFunctions.length, 5, 'Review the RTDB trigger manifest when it changes');
for (const [, fn] of databaseFunctions) {
  assert.deepEqual(fn.__endpoint.region, ['asia-southeast1']);
  fn.__endpoint.region = ['us-central1'];
  if (fn.__trigger) fn.__trigger.regions = ['us-central1'];
}
module.exports = candidate;
