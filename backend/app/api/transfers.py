"""Transfer management API endpoints."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models.device import Device
from app.models.transfer import Transfer
from app.models.user import User
from app.utils.errors import (
    AuthenticationError,
    ForbiddenError,
    NotFoundError,
    TransferError,
    ValidationError,
)

transfers_bp = Blueprint("transfers", __name__)

_VALID_MODES = {"bluetooth", "lan", "same_account", "pickup"}
_TERMINAL_STATUSES = {"completed", "rejected", "cancelled", "failed"}


@transfers_bp.route("/", methods=["POST"])
@jwt_required()
def create_transfer():
    """Create a new transfer record.

    Body: {mode, target_device_id (optional), file_name, file_size}
    Returns: transfer dict, status 201.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    data = request.get_json(silent=True) or {}

    mode = data.get("mode", "").strip().lower()
    target_device_id = data.get("target_device_id")
    file_name = data.get("file_name", "").strip()
    file_size = data.get("file_size")

    if not mode:
        raise ValidationError("mode is required.")
    if mode not in _VALID_MODES:
        raise ValidationError(f"mode must be one of: {', '.join(sorted(_VALID_MODES))}.")
    if not file_name:
        raise ValidationError("file_name is required.")
    if file_size is None:
        raise ValidationError("file_size is required.")
    try:
        file_size = int(file_size)
        if file_size < 0:
            raise ValueError
    except (TypeError, ValueError):
        raise ValidationError("file_size must be a non-negative integer.")

    receiver_id = None
    receiver_device_id = None

    if target_device_id is not None:
        target_device = db.session.get(Device, int(target_device_id))
        if target_device is None:
            raise NotFoundError("Target device not found.")
        receiver_id = target_device.user_id
        receiver_device_id = target_device.id

    transfer = Transfer(
        sender_id=user.id,
        receiver_id=receiver_id,
        receiver_device_id=receiver_device_id,
        mode=mode,
        file_name=file_name,
        file_size=file_size,
        status="pending",
    )
    db.session.add(transfer)
    db.session.commit()

    return jsonify(transfer.to_dict()), 201


@transfers_bp.route("/<int:transfer_id>", methods=["GET"])
@jwt_required()
def get_transfer(transfer_id: int):
    """Get a transfer by ID.

    The requester must be either the sender or receiver.
    Returns: transfer dict.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    transfer = db.session.get(Transfer, transfer_id)
    if transfer is None:
        raise NotFoundError("Transfer not found.")

    if transfer.sender_id != user.id and transfer.receiver_id != user.id:
        raise ForbiddenError("You do not have permission to view this transfer.")

    return jsonify(transfer.to_dict()), 200


@transfers_bp.route("/<int:transfer_id>/accept", methods=["PUT"])
@jwt_required()
def accept_transfer(transfer_id: int):
    """Accept a pending transfer (receiver only).

    Returns: updated transfer dict.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    transfer = db.session.get(Transfer, transfer_id)
    if transfer is None:
        raise NotFoundError("Transfer not found.")

    if transfer.receiver_id != user.id:
        raise ForbiddenError("Only the transfer receiver can accept it.")

    if transfer.status in _TERMINAL_STATUSES:
        raise TransferError(f"Transfer cannot be accepted; it is already {transfer.status}.")

    if transfer.status != "pending":
        raise TransferError(
            f"Transfer cannot be accepted from status '{transfer.status}'."
        )

    transfer.status = "accepted"
    db.session.commit()

    return jsonify(transfer.to_dict()), 200


@transfers_bp.route("/<int:transfer_id>/reject", methods=["PUT"])
@jwt_required()
def reject_transfer(transfer_id: int):
    """Reject a pending transfer (receiver only).

    Returns: updated transfer dict.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    transfer = db.session.get(Transfer, transfer_id)
    if transfer is None:
        raise NotFoundError("Transfer not found.")

    if transfer.receiver_id != user.id:
        raise ForbiddenError("Only the transfer receiver can reject it.")

    if transfer.status in _TERMINAL_STATUSES:
        raise TransferError(f"Transfer cannot be rejected; it is already {transfer.status}.")

    if transfer.status not in ("pending", "accepted"):
        raise TransferError(
            f"Transfer cannot be rejected from status '{transfer.status}'."
        )

    transfer.status = "rejected"
    db.session.commit()

    return jsonify(transfer.to_dict()), 200


@transfers_bp.route("/<int:transfer_id>", methods=["DELETE"])
@jwt_required()
def cancel_transfer(transfer_id: int):
    """Cancel a transfer (sender or receiver).

    Returns: 204 No Content on success.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    transfer = db.session.get(Transfer, transfer_id)
    if transfer is None:
        raise NotFoundError("Transfer not found.")

    if transfer.sender_id != user.id and transfer.receiver_id != user.id:
        raise ForbiddenError("You do not have permission to cancel this transfer.")

    if transfer.status in _TERMINAL_STATUSES:
        raise TransferError(f"Transfer cannot be cancelled; it is already {transfer.status}.")

    transfer.status = "cancelled"
    db.session.commit()

    return "", 204
