/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import type {SessionRoom, RoomConnection} from "./session-contract.js";

/** Read only a server-selected identity, from the SAME transaction snapshot. */
export function currentPresence(room: SessionRoom, uid: string, role: "controller" | "player"): RoomConnection | undefined {
  const controller = role === "controller";
  if (controller && room.controllerUid !== uid) return;
  const player = room.players?.[uid];
  if (!controller && (player?.status !== "active" || (player.role ?? "player") !== "player")) return;
  const id = controller ? room.controllerCurrentConnectionId : player?.currentConnectionId;
  const seq = controller ? room.controllerConnectionSeq : player?.connectionSeq;
  const connection = id ? room.connections?.[uid]?.[id] : undefined;
  if (!connection || !room.roomInstanceId || connection.roomInstanceId !== room.roomInstanceId ||
    connection.connectionSeq !== seq || !Number.isSafeInteger(seq) ||
    (!controller && (!player?.membershipId || connection.membershipId !== player.membershipId)) ||
    typeof connection.connected !== "boolean" || typeof connection.lastSeen !== "number" || !Number.isFinite(connection.lastSeen)) return;
  return connection;
}

export function currentControllerSeen(room: SessionRoom): number | undefined {
  return currentPresence(room, room.controllerUid ?? "", "controller")?.lastSeen ??
    (room.presenceProtocol === 2 ? undefined : room.controllerPresence?.lastSeen);
}

/** Repair candidates only; the callback must re-evaluate in its current root CAS. */
export function unprojectedLosses(room: SessionRoom): Array<{uid: string; id: string}> {
  const losses: Array<{uid: string; id: string}> = [];
  if (room.status === "closed" || room.status === "terminal") return losses;
  const uid = room.controllerUid;
  const controller = uid ? currentPresence(room, uid, "controller") : undefined;
  if (uid && controller?.connected === false && (room.controllerConnected !== false ||
      room.controllerPresence?.connected !== false || room.controllerPresence?.lastSeen !== controller.lastSeen)) {
    losses.push({uid, id: room.controllerCurrentConnectionId!});
  }
  for (const [uid, player] of Object.entries(room.players ?? {})) {
    const current = currentPresence(room, uid, "player");
    if (current?.connected === false && (player.isConnected !== false || player.lastSeen !== current.lastSeen)) {
      losses.push({uid, id: player.currentConnectionId!});
    }
  }
  return losses;
}
