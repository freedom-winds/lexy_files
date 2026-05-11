"""WebSocket event handlers for same-account device-to-device file relay.

Architecture
------------
Each authenticated WebSocket connection registers the device in two SocketIO
rooms:

  user:{user_id}    – all devices belonging to the same account
  device:{db_id}    – a single device (for targeted messages)

Device presence is tracked in Redis under keys defined in
``app.utils.constants``.  Transfers are relayed in real-time; **no file data
is written to disk**.  Only the receiver's quota is charged (downstream
traffic).

Event reference
---------------
Server → Client
  transfer.request   – notify receiver a transfer is waiting for acceptance
  transfer.accepted  – notify sender the receiver accepted
  transfer.rejected  – notify sender the receiver rejected
  transfer.progress  – periodic progress update to both parties
  transfer.complete  – transfer finished successfully
  transfer.cancelled – transfer was cancelled by either party
  transfer.error     – unrecoverable transfer error
  device.online      – a sibling device came online
  device.offline     – a sibling device went offline

Client → Server
  device.heartbeat   – keep-alive; refreshes Redis TTL and last_seen_at
  transfer.accept    – receiver accepts a pending transfer
  transfer.reject    – receiver rejects a pending transfer
  transfer.data      – sender streams a file chunk
  transfer.complete  – sender signals the final chunk has been sent
  transfer.cancel    – either party cancels an in-progress transfer
  webrtc.offer       – relay SDP offer to target device for P2P setup
  webrtc.answer      – relay SDP answer back to offerer
  webrtc.ice_candidate – relay ICE candidate to target device
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from flask import request
from flask_jwt_extended import decode_token
from flask_jwt_extended.exceptions import JWTDecodeError
from flask_socketio import (
    Namespace,
    disconnect,
    emit,
    join_room,
    leave_room,
)
from jwt.exceptions import PyJWTError

from app.extensions import db, socketio
from app.models.device import Device
from app.models.transfer import Transfer
from app.models.user import User
from app.services.auth_service import AuthService
from app.services.quota_service import QuotaService
from app.utils.constants import DEVICE_ONLINE_TTL_SECONDS, REDIS_DEVICE_ONLINE_PREFIX
from app.utils.errors import QuotaExceededError

log = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────

# How many bytes_transferred must accumulate between progress broadcasts.
_PROGRESS_GRANULARITY = 256 * 1024  # 256 KB

# Active in-flight transfers: transfer_id → {"bytes": int, "last_progress": int}
_active_transfers: dict[int, dict[str, Any]] = {}


# ── Room helpers ──────────────────────────────────────────────────────────────

def _user_room(user_id: int) -> str:
    return f"user:{user_id}"


def _device_room(device_db_id: int) -> str:
    return f"device:{device_db_id}"


# ── Auth helper ───────────────────────────────────────────────────────────────

def _authenticate_connection() -> tuple[User, Device | None]:
    """Decode JWT from the ``token`` query-param; return (User, Device|None).

    ``device_id`` query-param (the string device_id, not DB PK) is optional;
    when supplied the device record is returned and marked online.

    Raises ``ConnectionRefusedError`` on any auth failure so that
    SocketIO rejects the handshake.
    """
    token = request.args.get("token", "").strip()
    if not token:
        raise ConnectionRefusedError("missing token")

    try:
        decoded = decode_token(token)
    except (JWTDecodeError, PyJWTError) as exc:
        raise ConnectionRefusedError(f"invalid token: {exc}") from exc

    user_id_str = decoded.get("sub")
    if not user_id_str:
        raise ConnectionRefusedError("token has no subject")

    try:
        user_id = int(user_id_str)
    except ValueError:
        raise ConnectionRefusedError("token subject is not an integer")

    user = db.session.get(User, user_id)
    if user is None:
        raise ConnectionRefusedError("user not found")
    if user.is_banned:
        raise ConnectionRefusedError("account is banned")

    device: Device | None = None
    device_id_str = request.args.get("device_id", "").strip()
    if device_id_str:
        device = Device.query.filter_by(device_id=device_id_str, user_id=user.id).first()
        if device is None:
            raise ConnectionRefusedError(
                f"device '{device_id_str}' not found or not owned by user"
            )

    return user, device


# ── Presence helpers ──────────────────────────────────────────────────────────

def _mark_device_online(user: User, device: Device, sid: str) -> None:
    """Update DB + Redis to show *device* is online; notify sibling devices."""
    device.mark_online()
    db.session.commit()

    redis = AuthService.get_redis()
    key = REDIS_DEVICE_ONLINE_PREFIX + str(device.id)
    redis.setex(key, DEVICE_ONLINE_TTL_SECONDS, sid)

    # Broadcast to every other device on the same account (not to the
    # connecting device itself – it already knows it's online).
    socketio.emit(
        "device.online",
        device.to_dict(),
        to=_user_room(user.id),
        skip_sid=sid,
    )
    log.debug("device %d (user %d) online, sid=%s", device.id, user.id, sid)


def _mark_device_offline(user: User, device: Device, sid: str) -> None:
    """Update DB + Redis to show *device* is offline; notify sibling devices."""
    device.mark_offline()
    db.session.commit()

    redis = AuthService.get_redis()
    key = REDIS_DEVICE_ONLINE_PREFIX + str(device.id)
    redis.delete(key)

    socketio.emit(
        "device.offline",
        device.to_dict(),
        to=_user_room(user.id),
        skip_sid=sid,
    )
    log.debug("device %d (user %d) offline, sid=%s", device.id, user.id, sid)


# ── Namespace ─────────────────────────────────────────────────────────────────

class TransferNamespace(Namespace):
    """SocketIO namespace ``/`` that handles all transfer relay events.

    Each socket connection stores its context in ``self._sessions``, a dict
    keyed by ``sid``.  Because eventlet is single-threaded we do not need
    explicit locking for this dict.
    """

    def __init__(self, namespace: str = "/") -> None:
        super().__init__(namespace)
        # sid → {"user_id": int, "device_id": int | None, "user": User, "device": Device | None}
        self._sessions: dict[str, dict[str, Any]] = {}

    # ── connect / disconnect ──────────────────────────────────────────────────

    def on_connect(self, auth: dict | None = None) -> None:
        """Authenticate and register the connecting socket."""
        sid = request.sid  # type: ignore[attr-defined]
        try:
            user, device = _authenticate_connection()
        except ConnectionRefusedError as exc:
            log.warning("WS connection refused sid=%s: %s", sid, exc)
            disconnect()
            return

        self._sessions[sid] = {
            "user_id": user.id,
            "device_id": device.id if device else None,
            "user": user,
            "device": device,
        }

        # Join account-wide and (if known) device-specific rooms.
        join_room(_user_room(user.id), sid=sid)
        if device:
            join_room(_device_room(device.id), sid=sid)
            _mark_device_online(user, device, sid)

        log.info(
            "WS connected user_id=%d device_id=%s sid=%s",
            user.id,
            device.id if device else None,
            sid,
        )

    def on_disconnect(self) -> None:
        """Clean up presence state and rooms when a socket disconnects."""
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.pop(sid, None)
        if session is None:
            return

        user: User = session["user"]
        device: Device | None = session["device"]

        if device:
            # Re-fetch inside this request context to avoid DetachedInstanceError.
            fresh_device = db.session.get(Device, device.id)
            if fresh_device is not None:
                _mark_device_offline(user, fresh_device, sid)
            leave_room(_device_room(device.id), sid=sid)

        leave_room(_user_room(user.id), sid=sid)
        log.info(
            "WS disconnected user_id=%d device_id=%s sid=%s",
            user.id,
            device.id if device else None,
            sid,
        )

    # ── device.heartbeat ─────────────────────────────────────────────────────

    def on_device_heartbeat(self, data: dict | None = None) -> None:
        """Refresh Redis TTL and update last_seen_at for the connected device.

        The client should send this event every ~60 seconds.
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            return

        device: Device | None = session["device"]
        if device is None:
            return

        fresh_device = db.session.get(Device, device.id)
        if fresh_device is None:
            return

        fresh_device.last_seen_at = datetime.now(timezone.utc)
        db.session.commit()

        redis = AuthService.get_redis()
        key = REDIS_DEVICE_ONLINE_PREFIX + str(fresh_device.id)
        redis.expire(key, DEVICE_ONLINE_TTL_SECONDS)

        emit("device.heartbeat.ack", {"device_id": fresh_device.id, "ts": fresh_device.last_seen_at.isoformat()})

    # ── transfer.accept ──────────────────────────────────────────────────────

    def on_transfer_accept(self, data: dict) -> None:
        """Receiver accepts a pending transfer.

        Expected payload: {"transfer_id": <int>}
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        user: User = session["user"]
        transfer_id = _extract_int(data, "transfer_id")
        if transfer_id is None:
            emit("error", {"code": "VALIDATION_ERROR", "message": "transfer_id is required."})
            return

        transfer = db.session.get(Transfer, transfer_id)
        if transfer is None:
            emit("error", {"code": "NOT_FOUND", "message": "Transfer not found."})
            return

        if transfer.receiver_id != user.id:
            emit("error", {"code": "FORBIDDEN", "message": "You are not the receiver."})
            return

        if transfer.status != "pending":
            emit("error", {"code": "TRANSFER_ERROR", "message": f"Transfer is already {transfer.status}."})
            return

        transfer.status = "accepted"
        db.session.commit()

        # Notify sender device.
        socketio.emit(
            "transfer.accepted",
            transfer.to_dict(),
            to=_device_room(transfer.sender_device_id) if transfer.sender_device_id else _user_room(transfer.sender_id),
        )

        emit("transfer.accepted", transfer.to_dict())
        log.info("transfer %d accepted by user %d", transfer.id, user.id)

    # ── transfer.reject ───────────────────────────────────────────────────────

    def on_transfer_reject(self, data: dict) -> None:
        """Receiver rejects a pending transfer.

        Expected payload: {"transfer_id": <int>}
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        user: User = session["user"]
        transfer_id = _extract_int(data, "transfer_id")
        if transfer_id is None:
            emit("error", {"code": "VALIDATION_ERROR", "message": "transfer_id is required."})
            return

        transfer = db.session.get(Transfer, transfer_id)
        if transfer is None:
            emit("error", {"code": "NOT_FOUND", "message": "Transfer not found."})
            return

        if transfer.receiver_id != user.id:
            emit("error", {"code": "FORBIDDEN", "message": "You are not the receiver."})
            return

        if transfer.status not in ("pending", "accepted"):
            emit(
                "error",
                {
                    "code": "TRANSFER_ERROR",
                    "message": f"Transfer cannot be rejected from status '{transfer.status}'.",
                },
            )
            return

        transfer.status = "rejected"
        db.session.commit()

        # Notify sender.
        socketio.emit(
            "transfer.rejected",
            transfer.to_dict(),
            to=_device_room(transfer.sender_device_id) if transfer.sender_device_id else _user_room(transfer.sender_id),
        )

        emit("transfer.rejected", transfer.to_dict())
        log.info("transfer %d rejected by user %d", transfer.id, user.id)

    # ── transfer.cancel ───────────────────────────────────────────────────────

    def on_transfer_cancel(self, data: dict) -> None:
        """Either party cancels an in-progress or pending transfer.

        Expected payload: {"transfer_id": <int>}
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        user: User = session["user"]
        transfer_id = _extract_int(data, "transfer_id")
        if transfer_id is None:
            emit("error", {"code": "VALIDATION_ERROR", "message": "transfer_id is required."})
            return

        transfer = db.session.get(Transfer, transfer_id)
        if transfer is None:
            emit("error", {"code": "NOT_FOUND", "message": "Transfer not found."})
            return

        if transfer.sender_id != user.id and transfer.receiver_id != user.id:
            emit("error", {"code": "FORBIDDEN", "message": "You are not party to this transfer."})
            return

        _TERMINAL = {"completed", "rejected", "cancelled", "failed"}
        if transfer.status in _TERMINAL:
            emit("error", {"code": "TRANSFER_ERROR", "message": f"Transfer is already {transfer.status}."})
            return

        transfer.status = "cancelled"
        db.session.commit()

        _active_transfers.pop(transfer.id, None)

        payload = transfer.to_dict()

        # Notify both parties.
        if transfer.sender_device_id:
            socketio.emit("transfer.cancelled", payload, to=_device_room(transfer.sender_device_id))
        else:
            socketio.emit("transfer.cancelled", payload, to=_user_room(transfer.sender_id))

        if transfer.receiver_device_id:
            socketio.emit("transfer.cancelled", payload, to=_device_room(transfer.receiver_device_id))
        elif transfer.receiver_id:
            socketio.emit("transfer.cancelled", payload, to=_user_room(transfer.receiver_id))

        log.info("transfer %d cancelled by user %d", transfer.id, user.id)

    # ── transfer.data ─────────────────────────────────────────────────────────

    def on_transfer_data(self, data: dict) -> None:
        """Relay a raw file chunk from sender to receiver.

        Expected payload::

            {
              "transfer_id": <int>,
              "chunk": <bytes | str>,   # raw bytes or base64-encoded string
              "offset": <int>           # byte offset for integrity checks
            }

        The server relays the chunk to the receiver verbatim (no disk write).
        Downstream bytes are counted against the *receiver's* quota.
        A ``transfer.progress`` event is emitted to both parties once every
        ``_PROGRESS_GRANULARITY`` bytes.
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        user: User = session["user"]
        transfer_id = _extract_int(data, "transfer_id")
        if transfer_id is None:
            emit("error", {"code": "VALIDATION_ERROR", "message": "transfer_id is required."})
            return

        chunk = data.get("chunk")
        if chunk is None:
            emit("error", {"code": "VALIDATION_ERROR", "message": "chunk is required."})
            return

        transfer = db.session.get(Transfer, transfer_id)
        if transfer is None:
            emit("error", {"code": "NOT_FOUND", "message": "Transfer not found."})
            return

        if transfer.sender_id != user.id:
            emit("error", {"code": "FORBIDDEN", "message": "Only the sender can push data."})
            return

        if transfer.status not in ("accepted", "in_progress"):
            emit(
                "error",
                {
                    "code": "TRANSFER_ERROR",
                    "message": f"Transfer is not in a streamable state (status={transfer.status}).",
                },
            )
            return

        # Transition to in_progress on first chunk.
        if transfer.status == "accepted":
            transfer.status = "in_progress"

        # Determine chunk size (bytes regardless of whether it arrived as
        # bytes or base64 string – we count what we relay).
        if isinstance(chunk, (bytes, bytearray)):
            chunk_bytes = len(chunk)
        elif isinstance(chunk, str):
            chunk_bytes = len(chunk.encode("utf-8"))
        else:
            chunk_bytes = len(chunk)

        # --- Quota check on receiver ---
        if transfer.receiver_id is not None:
            receiver = db.session.get(User, transfer.receiver_id)
            if receiver is not None:
                try:
                    QuotaService.check_download_allowed(receiver)
                except QuotaExceededError:
                    transfer.status = "failed"
                    db.session.commit()
                    _active_transfers.pop(transfer.id, None)
                    emit(
                        "transfer.error",
                        {
                            "transfer_id": transfer.id,
                            "code": "QUOTA_EXCEEDED",
                            "message": "Receiver's download quota is exhausted.",
                        },
                    )
                    socketio.emit(
                        "transfer.error",
                        {
                            "transfer_id": transfer.id,
                            "code": "QUOTA_EXCEEDED",
                            "message": "Your download quota is exhausted; transfer failed.",
                        },
                        to=(
                            _device_room(transfer.receiver_device_id)
                            if transfer.receiver_device_id
                            else _user_room(transfer.receiver_id)
                        ),
                    )
                    log.warning("transfer %d failed: receiver quota exceeded", transfer.id)
                    return

        # --- Update progress tracking ---
        state = _active_transfers.setdefault(
            transfer.id,
            {
                "bytes": transfer.bytes_transferred,
                "last_progress": transfer.bytes_transferred,
            },
        )
        state["bytes"] += chunk_bytes

        transfer.bytes_transferred = state["bytes"]
        db.session.commit()

        # --- Charge downstream quota to receiver ---
        if transfer.receiver_id is not None:
            receiver = db.session.get(User, transfer.receiver_id)
            if receiver is not None:
                try:
                    QuotaService.track_download(receiver, chunk_bytes)
                except Exception as exc:
                    log.warning(
                        "Failed to track download quota for user %d: %s",
                        transfer.receiver_id,
                        exc,
                    )

        # --- Relay chunk to receiver ---
        relay_payload = {
            "transfer_id": transfer.id,
            "chunk": chunk,
            "offset": data.get("offset", state["bytes"] - chunk_bytes),
            "bytes_transferred": state["bytes"],
        }
        if transfer.receiver_device_id:
            socketio.emit(
                "transfer.data",
                relay_payload,
                to=_device_room(transfer.receiver_device_id),
            )
        elif transfer.receiver_id:
            socketio.emit("transfer.data", relay_payload, to=_user_room(transfer.receiver_id))

        # --- Emit progress if granularity threshold crossed ---
        bytes_since_last = state["bytes"] - state["last_progress"]
        if bytes_since_last >= _PROGRESS_GRANULARITY or state["bytes"] == transfer.file_size:
            state["last_progress"] = state["bytes"]
            progress_payload = {
                "transfer_id": transfer.id,
                "bytes_transferred": state["bytes"],
                "file_size": transfer.file_size,
                "progress_percent": (
                    round(state["bytes"] / transfer.file_size * 100, 2)
                    if transfer.file_size > 0
                    else 0
                ),
            }
            # Emit to sender.
            emit("transfer.progress", progress_payload)
            # Emit to receiver.
            if transfer.receiver_device_id:
                socketio.emit(
                    "transfer.progress",
                    progress_payload,
                    to=_device_room(transfer.receiver_device_id),
                )
            elif transfer.receiver_id:
                socketio.emit("transfer.progress", progress_payload, to=_user_room(transfer.receiver_id))

    # ── transfer.complete (client signal) ────────────────────────────────────

    def on_transfer_complete(self, data: dict) -> None:
        """Sender signals that all chunks have been sent.

        Expected payload: {"transfer_id": <int>}
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        user: User = session["user"]
        transfer_id = _extract_int(data, "transfer_id")
        if transfer_id is None:
            emit("error", {"code": "VALIDATION_ERROR", "message": "transfer_id is required."})
            return

        transfer = db.session.get(Transfer, transfer_id)
        if transfer is None:
            emit("error", {"code": "NOT_FOUND", "message": "Transfer not found."})
            return

        if transfer.sender_id != user.id:
            emit("error", {"code": "FORBIDDEN", "message": "Only the sender can mark a transfer complete."})
            return

        if transfer.status not in ("accepted", "in_progress"):
            emit(
                "error",
                {
                    "code": "TRANSFER_ERROR",
                    "message": f"Transfer cannot be completed from status '{transfer.status}'.",
                },
            )
            return

        transfer.status = "completed"
        transfer.completed_at = datetime.now(timezone.utc)
        # Use the in-memory counter if available (may be more up-to-date than DB).
        state = _active_transfers.pop(transfer.id, None)
        if state is not None:
            transfer.bytes_transferred = state["bytes"]
        db.session.commit()

        complete_payload = transfer.to_dict()

        # Notify both parties.
        emit("transfer.complete", complete_payload)
        if transfer.receiver_device_id:
            socketio.emit(
                "transfer.complete",
                complete_payload,
                to=_device_room(transfer.receiver_device_id),
            )
        elif transfer.receiver_id:
            socketio.emit("transfer.complete", complete_payload, to=_user_room(transfer.receiver_id))

        log.info(
            "transfer %d completed by user %d, bytes=%d",
            transfer.id,
            user.id,
            transfer.bytes_transferred,
        )

    # ── WebRTC signaling ─────────────────────────────────────────────────────

    def on_webrtc_offer(self, data: dict) -> None:
        """Relay a WebRTC SDP offer to a target device for P2P connection setup.

        Expected payload: {"target_device_id": <int>, "transfer_id": <int>, "sdp": <str>}
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        target_device_id = _extract_int(data, "target_device_id")
        transfer_id = _extract_int(data, "transfer_id")
        sdp = data.get("sdp")

        if target_device_id is None or transfer_id is None or not sdp:
            emit(
                "error",
                {
                    "code": "VALIDATION_ERROR",
                    "message": "target_device_id, transfer_id, and sdp are required.",
                },
            )
            return

        socketio.emit(
            "webrtc.offer",
            {"from_device_id": session.get("device_id"), "transfer_id": transfer_id, "sdp": sdp},
            to=_device_room(target_device_id),
        )

    def on_webrtc_answer(self, data: dict) -> None:
        """Relay a WebRTC SDP answer back to the offerer device.

        Expected payload: {"target_device_id": <int>, "transfer_id": <int>, "sdp": <str>}
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        target_device_id = _extract_int(data, "target_device_id")
        transfer_id = _extract_int(data, "transfer_id")
        sdp = data.get("sdp")

        if target_device_id is None or transfer_id is None or not sdp:
            emit(
                "error",
                {
                    "code": "VALIDATION_ERROR",
                    "message": "target_device_id, transfer_id, and sdp are required.",
                },
            )
            return

        socketio.emit(
            "webrtc.answer",
            {"from_device_id": session.get("device_id"), "transfer_id": transfer_id, "sdp": sdp},
            to=_device_room(target_device_id),
        )

    def on_webrtc_ice_candidate(self, data: dict) -> None:
        """Relay a WebRTC ICE candidate between peers.

        Expected payload: {"target_device_id": <int>, "transfer_id": <int>, "candidate": <object>}
        """
        sid = request.sid  # type: ignore[attr-defined]
        session = self._sessions.get(sid)
        if session is None:
            emit("error", {"code": "NOT_AUTHENTICATED", "message": "Not authenticated."})
            return

        target_device_id = _extract_int(data, "target_device_id")
        transfer_id = _extract_int(data, "transfer_id")
        candidate = data.get("candidate")

        if target_device_id is None or transfer_id is None or candidate is None:
            emit(
                "error",
                {
                    "code": "VALIDATION_ERROR",
                    "message": "target_device_id, transfer_id, and candidate are required.",
                },
            )
            return

        socketio.emit(
            "webrtc.ice_candidate",
            {"from_device_id": session.get("device_id"), "transfer_id": transfer_id, "candidate": candidate},
            to=_device_room(target_device_id),
        )


# ── Module-level helpers ──────────────────────────────────────────────────────

def _extract_int(data: dict, key: str) -> int | None:
    """Return ``data[key]`` as an int, or None if missing/invalid."""
    try:
        return int(data[key])
    except (KeyError, TypeError, ValueError):
        return None


# ── Utility: push transfer.request from REST layer ───────────────────────────

def notify_transfer_request(transfer: Transfer) -> None:
    """Emit a ``transfer.request`` event to the receiver's device/account room.

    Called by the REST endpoint after creating a same_account transfer so the
    receiver is notified in real-time.  Safe to call even if the receiver has
    no active WebSocket connection (the emit will simply be a no-op).
    """
    payload = transfer.to_dict()
    if transfer.receiver_device_id:
        socketio.emit("transfer.request", payload, to=_device_room(transfer.receiver_device_id))
    elif transfer.receiver_id:
        socketio.emit("transfer.request", payload, to=_user_room(transfer.receiver_id))


# ── Register namespace ────────────────────────────────────────────────────────

socketio.on_namespace(TransferNamespace("/"))
