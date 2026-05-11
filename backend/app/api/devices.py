"""Device management API endpoints."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models.device import Device
from app.models.user import User
from app.services.auth_service import AuthService
from app.utils.constants import DEVICE_ONLINE_TTL_SECONDS, REDIS_DEVICE_ONLINE_PREFIX
from app.utils.errors import AuthenticationError, ForbiddenError, NotFoundError, ValidationError

devices_bp = Blueprint("devices", __name__)

_VALID_DEVICE_TYPES = {"phone", "tablet", "laptop", "desktop", "other"}
_VALID_PLATFORMS = {"android", "ios", "windows", "macos", "linux", "web"}
_DEVICE_TYPE_ALIASES = {
    "mobile": "phone",
    "tv": "other",
}


@devices_bp.route("/", methods=["GET"])
@jwt_required()
def list_devices():
    """List all devices registered to the current user.

    Returns: [{device}, ...]
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    devices = Device.query.filter_by(user_id=user.id).order_by(Device.created_at.desc()).all()
    return jsonify([_device_to_presence_dict(d) for d in devices]), 200


@devices_bp.route("/", methods=["POST"])
@jwt_required()
def create_device():
    """Register a new device for the current user.

    Body: {name, device_type, platform, device_id}
    Returns: device dict, status 201.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    data = request.get_json(silent=True) or {}

    name = data.get("name", "").strip()
    device_type = data.get("device_type", "other").strip().lower()
    device_type = _DEVICE_TYPE_ALIASES.get(device_type, device_type)
    platform = data.get("platform", "web").strip().lower()
    device_id = data.get("device_id", "").strip()

    if not name:
        raise ValidationError("name is required.")
    if not device_id:
        raise ValidationError("device_id is required.")
    if device_type not in _VALID_DEVICE_TYPES:
        raise ValidationError(
            f"device_type must be one of: {', '.join(sorted(_VALID_DEVICE_TYPES))}."
        )
    if platform not in _VALID_PLATFORMS:
        raise ValidationError(
            f"platform must be one of: {', '.join(sorted(_VALID_PLATFORMS))}."
        )

    # Check for duplicate device_id
    existing = Device.query.filter_by(device_id=device_id).first()
    if existing is not None:
        raise ValidationError("A device with this device_id is already registered.")

    device = Device(
        user_id=user.id,
        name=name,
        device_type=device_type,
        platform=platform,
        device_id=device_id,
    )
    db.session.add(device)
    db.session.commit()

    return jsonify(device.to_dict()), 201


@devices_bp.route("/<int:device_id>", methods=["DELETE"])
@jwt_required()
def delete_device(device_id: int):
    """Delete a device registered to the current user.

    Returns: 204 No Content on success.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    device = db.session.get(Device, device_id)
    if device is None:
        raise NotFoundError("Device not found.")

    if device.user_id != user.id:
        raise ForbiddenError("You do not have permission to delete this device.")

    db.session.delete(device)
    db.session.commit()

    return "", 204


@devices_bp.route("/<int:device_id>/online", methods=["PUT"])
@jwt_required()
def mark_online(device_id: int):
    """Mark a device as online and update its last_seen_at timestamp.

    Returns: updated device dict.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    device = db.session.get(Device, device_id)
    if device is None:
        raise NotFoundError("Device not found.")

    if device.user_id != user.id:
        raise ForbiddenError("You do not have permission to update this device.")

    device.mark_online()
    try:
        _refresh_device_presence(device)
    except Exception:
        # Keep REST heartbeat useful even during a transient Redis outage.
        pass
    db.session.commit()

    return jsonify(_device_to_presence_dict(device)), 200


def _refresh_device_presence(device: Device) -> None:
    """Refresh the Redis presence TTL for a device heartbeat."""
    redis = AuthService.get_redis()
    key = REDIS_DEVICE_ONLINE_PREFIX + str(device.id)
    redis.setex(key, DEVICE_ONLINE_TTL_SECONDS, "rest-heartbeat")


def _is_device_online(device: Device) -> bool:
    """Return online presence based on Redis TTL, falling back to DB state."""
    try:
        redis = AuthService.get_redis()
        return redis.exists(REDIS_DEVICE_ONLINE_PREFIX + str(device.id)) == 1
    except Exception:
        return bool(device.is_online)


def _device_to_presence_dict(device: Device) -> dict:
    data = device.to_dict()
    data["is_online"] = _is_device_online(device)
    return data
