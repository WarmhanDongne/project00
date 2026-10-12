import assert from 'node:assert/strict';

// Local RTDB test double: real nested paths, key/due queries, and cold-cache aborts.
export class CleanupDatabase {
  data = {};
  beforeTransaction = null;
  rerunTransaction = null;
  afterTransaction = null;
  failures = new Set();
  reads = [];
  limits = [];
  active = 0;
  maxActive = 0;

  value(path) {
    let result = this.data;
    for (const part of path.split('/').filter(Boolean)) result = result?.[part];
    return structuredClone(result ?? null);
  }
  put(path, value) {
    const parts = path.split('/').filter(Boolean);
    let parent = this.data;
    for (const part of parts.slice(0, -1)) parent = parent[part] ??= {};
    if (value == null) delete parent[parts.at(-1)];
    else parent[parts.at(-1)] = structuredClone(value);
  }
  snapshot(value, path) {
    const database = this;
    return {key: path.split('/').at(-1), ref: database.ref(path), val: () => structuredClone(value),
      exists: () => value != null, child: key => database.snapshot(value?.[key] ?? null, path + '/' + key),
      forEach(callback) {
        for (const [key, child] of Object.entries(value ?? {})) {
          callback(database.snapshot(child, path + '/' + key));
        }
      }};
  }
  ref(path) {
    const database = this;
    let listeners = 0;
    let start, end, limit, order;
    return {
      async get() {
        database.reads.push(path);
        let value = database.value(path);
        if (order || start !== undefined || end !== undefined || limit !== undefined) {
          let entries = Object.entries(value ?? {}).sort(([a, av], [b, bv]) => {
            if (order && order !== '$key') return av[order] - bv[order] || a.localeCompare(b);
            return a.localeCompare(b);
          });
          if (start !== undefined) entries = entries.filter(([key]) => key >= start);
          if (end !== undefined) entries = entries.filter(([, child]) => child[order] <= end);
          if (limit !== undefined) entries = entries.slice(0, limit);
          value = Object.fromEntries(entries);
        }
        return database.snapshot(value, path);
      },
      on(_event, callback) { listeners++; callback(database.snapshot(database.value(path), path)); },
      off() { listeners--; },
      async set(value) { database.put(path, value); },
      async transaction(update) {
        database.active++;
        database.maxActive = Math.max(database.maxActive, database.active);
        try {
          await Promise.resolve();
          if (database.failures.delete(path)) throw new Error('injected failure');
          await database.beforeTransaction?.(path);
          let next = update(listeners ? database.value(path) : null);
          if (next === undefined) return {committed: false, snapshot: database.snapshot(database.value(path), path)};
          if (!listeners && database.value(path) !== null) next = update(database.value(path));
          if (database.rerunTransaction) {
            const rerun = database.rerunTransaction;
            database.rerunTransaction = null;
            await rerun(path);
            next = update(database.value(path));
          }
          if (next === undefined) return {committed: false, snapshot: database.snapshot(database.value(path), path)};
          database.put(path, next);
          await database.afterTransaction?.(path);
          return {committed: true, snapshot: database.snapshot(next, path)};
        } finally { database.active--; }
      },
      orderByKey() { order = '$key'; return this; },
      orderByChild(child) { order = child; return this; },
      startAt(value) { assert.notEqual(value, ''); start = value; return this; },
      endAt(value) { end = value; return this; },
      limitToFirst(value) { database.limits.push({path, value}); limit = value; return this; },
    };
  }
}
