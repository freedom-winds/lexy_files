"""Admin API endpoints — user management, file management, group quotas, and stats."""

import functools

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models.device import Device
from app.models.file import File
from app.models.quota import DEFAULT_QUOTAS, GroupQuota
from app.models.transfer import Transfer
from app.models.user import User
from app.services.file_service import FileService
from app.utils.errors import ForbiddenError, NotFoundError, ValidationError
from app.utils.helpers import paginate_query, parse_int

admin_bp = Blueprint("admin", __name__)

_VALID_GROUPS = {"anonymous", "normal", "vip", "admin"}


# ── Admin guard decorator ─────────────────────────────────────────────────────

def admin_required(fn):
    """Decorator: require a valid JWT and admin user_group.

    Applies jwt_required() then checks the user's group.
    """
    @functools.wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        identity = get_jwt_identity()
        user = db.session.get(User, int(identity))
        if user is None or user.user_group != "admin":
            raise ForbiddenError("Admin access required.")
        return fn(*args, **kwargs)
    return wrapper


# ── User management ───────────────────────────────────────────────────────────

@admin_bp.route("/users", methods=["GET"])
@admin_required
def list_users():
    """Paginated list of all users.

    Query params: page, per_page, q (search username/email), group (filter by group)
    Returns: {data: [...], pagination: {...}}
    """
    page = parse_int(request.args.get("page"), default=1, minimum=1)
    per_page = parse_int(request.args.get("per_page"), default=20, minimum=1)
    search = request.args.get("q", "").strip()
    group_filter = request.args.get("group", "").strip().lower()

    query = User.query

    if search:
        like_term = f"%{search}%"
        query = query.filter(
            db.or_(User.username.ilike(like_term), User.email.ilike(like_term))
        )

    if group_filter and group_filter in _VALID_GROUPS:
        query = query.filter(User.user_group == group_filter)

    query = query.order_by(User.created_at.desc())

    result = paginate_query(query, page, per_page)
    result["data"] = [u.to_dict(include_sensitive=True) for u in result["data"]]

    return jsonify(result), 200


@admin_bp.route("/users/<int:user_id>/group", methods=["PUT"])
@admin_required
def update_user_group(user_id: int):
    """Change a user's group.

    Body: {group}
    Returns: updated user dict.
    """
    user = db.session.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found.")

    data = request.get_json(silent=True) or {}
    group = data.get("group", "").strip().lower()

    if not group:
        raise ValidationError("group is required.")
    if group not in _VALID_GROUPS:
        raise ValidationError(f"group must be one of: {', '.join(sorted(_VALID_GROUPS))}.")

    user.user_group = group
    db.session.commit()

    return jsonify(user.to_dict(include_sensitive=True)), 200


@admin_bp.route("/users/<int:user_id>/quota", methods=["PUT"])
@admin_required
def update_user_quota(user_id: int):
    """Set per-user quota overrides.

    Body: {quota_overrides: {...}}
    Returns: updated user dict.
    """
    user = db.session.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found.")

    data = request.get_json(silent=True) or {}
    quota_overrides = data.get("quota_overrides")

    if quota_overrides is not None and not isinstance(quota_overrides, dict):
        raise ValidationError("quota_overrides must be a JSON object or null.")

    user.custom_quota_overrides = quota_overrides
    db.session.commit()

    return jsonify(user.to_dict(include_sensitive=True)), 200


@admin_bp.route("/users/<int:user_id>/ban", methods=["PUT"])
@admin_required
def update_user_ban(user_id: int):
    """Ban or unban a user.

    Body: {banned: true|false}
    Returns: updated user dict.
    """
    user = db.session.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found.")

    data = request.get_json(silent=True) or {}
    banned = data.get("banned")

    if banned is None or not isinstance(banned, bool):
        raise ValidationError("banned must be a boolean value (true or false).")

    user.is_banned = banned
    db.session.commit()

    return jsonify(user.to_dict(include_sensitive=True)), 200


@admin_bp.route("/users/<int:user_id>/kick", methods=["POST"])
@admin_required
def kick_user(user_id: int):
    """Force all of a user's devices offline.

    Returns: {message}
    """
    user = db.session.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found.")

    devices = Device.query.filter_by(user_id=user.id).all()
    for device in devices:
        device.mark_offline()

    db.session.commit()

    return jsonify({"message": "User forced offline"}), 200


# ── File management ───────────────────────────────────────────────────────────

@admin_bp.route("/files", methods=["GET"])
@admin_required
def list_files():
    """Paginated list of all files in all statuses.

    Query params: page, per_page, status, user_id, q (search original_filename)
    Returns: {data: [...], pagination: {...}}
    """
    page = parse_int(request.args.get("page"), default=1, minimum=1)
    per_page = parse_int(request.args.get("per_page"), default=20, minimum=1)
    status_filter = request.args.get("status", "").strip().lower()
    user_id_filter = request.args.get("user_id", "").strip()
    search = request.args.get("q", "").strip()

    query = File.query

    valid_statuses = {"active", "expired", "redemption", "deleted"}
    if status_filter and status_filter in valid_statuses:
        query = query.filter(File.status == status_filter)

    if user_id_filter:
        try:
            query = query.filter(File.user_id == int(user_id_filter))
        except ValueError:
            raise ValidationError("user_id must be an integer.")

    if search:
        query = query.filter(File.original_filename.ilike(f"%{search}%"))

    query = query.order_by(File.created_at.desc())

    result = paginate_query(query, page, per_page)
    result["data"] = [f.to_dict(include_admin=True) for f in result["data"]]

    return jsonify(result), 200


@admin_bp.route("/files/<int:file_id>/download", methods=["GET"])
@admin_required
def admin_download_file(file_id: int):
    """Admin: stream any file regardless of status (as long as storage still exists).

    No speed limit is applied.
    Returns: streaming file response.
    """
    from urllib.parse import quote

    from flask import Response, stream_with_context

    from app.services.quota_service import QuotaService

    identity = get_jwt_identity()
    admin_user = db.session.get(User, int(identity))

    file_record = db.session.get(File, file_id)
    if file_record is None:
        raise NotFoundError("File not found.")

    if file_record.status == "deleted":
        raise NotFoundError("File has been physically deleted and cannot be downloaded.")

    # Admin downloads bypass speed limits — pass admin user (unlimited quota)
    generator = FileService.create_download_stream(file_record, admin_user)

    filename_encoded = quote(file_record.original_filename)
    content_disposition = (
        f"attachment; filename=\"{file_record.original_filename}\"; "
        f"filename*=UTF-8''{filename_encoded}"
    )

    headers = {
        "Content-Disposition": content_disposition,
        "Content-Length": str(file_record.file_size),
    }

    mime_type = file_record.mime_type or "application/octet-stream"

    return Response(
        stream_with_context(generator),
        status=200,
        mimetype=mime_type,
        headers=headers,
        direct_passthrough=False,
    )


@admin_bp.route("/files/<int:file_id>/expire", methods=["PUT"])
@admin_required
def expire_file(file_id: int):
    """Force-expire a file.

    Returns: updated file dict.
    """
    file_record = db.session.get(File, file_id)
    if file_record is None:
        raise NotFoundError("File not found.")

    FileService.force_expire_file(file_record)

    return jsonify(file_record.to_dict(include_admin=True)), 200


@admin_bp.route("/files/<int:file_id>", methods=["DELETE"])
@admin_required
def delete_file(file_id: int):
    """Force-delete a file (admin override).

    Returns: 204 No Content on success.
    """
    file_record = db.session.get(File, file_id)
    if file_record is None:
        raise NotFoundError("File not found.")

    FileService.force_delete_file(file_record)

    return "", 204


# ── Group quota management ────────────────────────────────────────────────────

@admin_bp.route("/groups", methods=["GET"])
@admin_required
def list_groups():
    """List all GroupQuota records. Seeds defaults if none exist.

    Returns: [{group_quota}, ...]
    """
    groups = GroupQuota.query.order_by(GroupQuota.group_name).all()

    if not groups:
        # Seed defaults
        for group_name, defaults in DEFAULT_QUOTAS.items():
            gq = GroupQuota(group_name=group_name, **defaults)
            db.session.add(gq)
        db.session.commit()
        groups = GroupQuota.query.order_by(GroupQuota.group_name).all()

    return jsonify([g.to_dict() for g in groups]), 200


@admin_bp.route("/groups/<string:group_name>", methods=["PUT"])
@admin_required
def update_group(group_name: str):
    """Update quota settings for a named group.

    Body may contain any combination of GroupQuota fields:
        download_speed_limit, max_single_file_size, max_total_storage,
        download_traffic_quota, traffic_quota_period, max_retention_seconds
    Returns: updated group_quota dict.
    """
    group_name = group_name.lower()
    if group_name not in _VALID_GROUPS:
        raise ValidationError(f"group must be one of: {', '.join(sorted(_VALID_GROUPS))}.")

    gq = GroupQuota.query.filter_by(group_name=group_name).first()
    if gq is None:
        # Create from defaults if missing
        defaults = DEFAULT_QUOTAS.get(group_name, {})
        gq = GroupQuota(group_name=group_name, **defaults)
        db.session.add(gq)

    data = request.get_json(silent=True) or {}

    _updatable_int_fields = {
        "download_speed_limit",
        "max_single_file_size",
        "max_total_storage",
        "download_traffic_quota",
        "max_retention_seconds",
    }
    _valid_periods = {"daily", "monthly"}

    for field in _updatable_int_fields:
        if field in data:
            try:
                value = int(data[field])
                if value < 0:
                    raise ValueError
                setattr(gq, field, value)
            except (TypeError, ValueError):
                raise ValidationError(f"{field} must be a non-negative integer.")

    if "traffic_quota_period" in data:
        period = data["traffic_quota_period"]
        if period not in _valid_periods:
            raise ValidationError(
                f"traffic_quota_period must be one of: {', '.join(sorted(_valid_periods))}."
            )
        gq.traffic_quota_period = period

    db.session.commit()

    return jsonify(gq.to_dict()), 200


# ── Stats ─────────────────────────────────────────────────────────────────────

@admin_bp.route("/stats", methods=["GET"])
@admin_required
def stats():
    """Return aggregate platform statistics.

    Returns: {
        total_users, total_files, total_storage_bytes,
        active_files, expired_files, files_in_redemption, total_transfers
    }
    """
    total_users = db.session.query(db.func.count(User.id)).scalar() or 0

    active_users = (
        db.session.query(db.func.count(User.id))
        .filter(User.is_banned == False, User.is_anonymous == False)  # noqa: E712
        .scalar()
        or 0
    )

    anonymous_users = (
        db.session.query(db.func.count(User.id))
        .filter(User.is_anonymous == True)  # noqa: E712
        .scalar()
        or 0
    )

    total_files = db.session.query(db.func.count(File.id)).scalar() or 0

    total_storage_bytes = (
        db.session.query(db.func.sum(File.file_size))
        .filter(File.status != "deleted")
        .scalar()
        or 0
    )

    active_files = (
        db.session.query(db.func.count(File.id))
        .filter(File.status == "active")
        .scalar()
        or 0
    )

    expired_files = (
        db.session.query(db.func.count(File.id))
        .filter(File.status == "expired")
        .scalar()
        or 0
    )

    files_in_redemption = (
        db.session.query(db.func.count(File.id))
        .filter(File.status == "redemption")
        .scalar()
        or 0
    )

    total_downloads = (
        db.session.query(db.func.sum(File.download_count))
        .scalar()
        or 0
    )

    total_transfers = (
        db.session.query(db.func.count(Transfer.id)).scalar() or 0
    )

    return jsonify(
        {
            "total_users": total_users,
            "active_users": active_users,
            "anonymous_users": anonymous_users,
            "total_files": total_files,
            "total_storage_bytes": total_storage_bytes,
            "active_files": active_files,
            "expired_files": expired_files,
            "files_in_redemption": files_in_redemption,
            "total_downloads": total_downloads,
            "total_transfers": total_transfers,
        }
    ), 200
