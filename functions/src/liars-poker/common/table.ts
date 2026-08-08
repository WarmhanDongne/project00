/* eslint-disable valid-jsdoc */

import {randomInt} from "crypto";

export type Table = "A" | "K" | "Q";

const tables: Table[] = [
  "A",
  "K",
  "Q",
];

/** 새 라운드의 기준 랭크를 무작위로 선택합니다. */
export function createTable(): Table {
  return tables[randomInt(tables.length)];
}
