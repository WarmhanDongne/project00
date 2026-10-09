/* eslint-disable require-jsdoc, valid-jsdoc */
import {AsyncLocalStorage} from "node:async_hooks";
import {createHmac, randomBytes, randomInt, randomUUID} from "node:crypto";

interface RandomScope {seed: Buffer; counter: number}
const scopes = new AsyncLocalStorage<RandomScope>();

/** Captured before the transaction and rewound for each callback. */
export function transactionRandomSeed(): Buffer {
  return randomBytes(32);
}
export function withTransactionRandom<T>(seed: Buffer, run: () => T): T {
  return scopes.run({seed, counter: 0}, run);
}
function scopedBytes(scope: RandomScope): Buffer {
  return createHmac("sha256", scope.seed)
    .update(String(scope.counter++)).digest();
}
export function gameRandomInt(maxExclusive: number): number {
  const scope = scopes.getStore();
  if (!scope) return randomInt(maxExclusive);
  if (!Number.isSafeInteger(maxExclusive) ||
      maxExclusive < 1 || maxExclusive > 0xffffffff) {
    throw new RangeError("Invalid random bound");
  }
  const limit = Math.floor(0x100000000 / maxExclusive) * maxExclusive;
  let value: number;
  do {
    value = scopedBytes(scope).readUInt32BE();
  } while (value >= limit);
  return value % maxExclusive;
}
export function gameRandomUUID(): string {
  const scope = scopes.getStore();
  if (!scope) return randomUUID();
  const bytes = scopedBytes(scope).subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return [hex.slice(0, 8), hex.slice(8, 12), hex.slice(12, 16),
    hex.slice(16, 20), hex.slice(20)].join("-");
}
