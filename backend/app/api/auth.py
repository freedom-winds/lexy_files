"""Authentication API endpoints."""

from datetime import timedelta

from flask import Blueprint, jsonify, request
from flask_jwt_extended import (
    create_access_token,
    get_jwt,
    get_jwt_identity,
    jwt_required,
)

from app.extensions import db
from app.models.user import User
from app.services.auth_service import AuthService
from app.utils.errors import AuthenticationError, NotFoundError, ValidationError

auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/register", methods=["POST"])
def register():
    """Register a new user account.

    Body: {username, email, password}
    Returns: {user, tokens} with status 201.
    """
    data = request.get_json(silent=True) or {}

    username = data.get("username", "").strip()
    email = data.get("email", "").strip()
    password = data.get("password", "")

    if not username:
        raise ValidationError("username is required.")
    if not email:
        raise ValidationError("email is required.")
    if not password:
        raise ValidationError("password is required.")

    user = AuthService.register_user(username, email, password)
    tokens = AuthService.generate_tokens(user)

    return jsonify({"user": user.to_dict(), "tokens": tokens}), 201


@auth_bp.route("/login", methods=["POST"])
def login():
    """Authenticate with username and password.

    Body: {username, password}
    Returns: {user, tokens}
    """
    data = request.get_json(silent=True) or {}

    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not username:
        raise ValidationError("username is required.")
    if not password:
        raise ValidationError("password is required.")

    user = AuthService.authenticate(username, password)
    tokens = AuthService.generate_tokens(user)

    return jsonify({"user": user.to_dict(), "tokens": tokens}), 200


@auth_bp.route("/refresh", methods=["POST"])
@jwt_required(refresh=True)
def refresh():
    """Issue a new access token using a valid refresh token.

    Requires: Authorization header with Bearer <refresh_token>
    Returns: {access_token}
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise NotFoundError("User not found.")

    from flask import current_app
    expires: timedelta = current_app.config.get(
        "JWT_ACCESS_TOKEN_EXPIRES", timedelta(minutes=15)
    )
    access_token = create_access_token(
        identity=str(user.id),
        additional_claims={"user_group": user.user_group},
    )

    return jsonify({"access_token": access_token}), 200


@auth_bp.route("/logout", methods=["POST"])
@jwt_required()
def logout():
    """Revoke the current access token (add its JTI to the blacklist).

    Requires: Authorization header with Bearer <access_token>
    Returns: {message}
    """
    jwt_payload = get_jwt()
    jti = jwt_payload["jti"]

    from flask import current_app
    expires: timedelta = current_app.config.get(
        "JWT_ACCESS_TOKEN_EXPIRES", timedelta(minutes=15)
    )
    expires_in_seconds = int(expires.total_seconds())

    AuthService.revoke_token(jti, expires_in_seconds)

    return jsonify({"message": "Logged out"}), 200


@auth_bp.route("/me", methods=["GET"])
@jwt_required()
def me():
    """Return the currently authenticated user's profile.

    Requires: Authorization header with Bearer <access_token>
    Returns: {user}
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise NotFoundError("User not found.")

    return jsonify({"user": user.to_dict()}), 200


@auth_bp.route("/anonymous", methods=["POST"])
def anonymous():
    """Create or retrieve an anonymous user session.

    Body: {device_id, fingerprint}
    Also reads request.remote_addr for IP-based identification.
    Returns: {user, tokens}
    """
    data = request.get_json(silent=True) or {}

    device_id = data.get("device_id", "").strip()
    fingerprint = data.get("fingerprint", "").strip()
    ip_address = request.remote_addr or "0.0.0.0"

    if not device_id and not fingerprint:
        raise ValidationError("At least one of device_id or fingerprint is required.")

    user = AuthService.find_or_create_anonymous(ip_address, fingerprint or device_id)
    tokens = AuthService.generate_tokens(user)

    return jsonify({"user": user.to_dict(), "tokens": tokens}), 200
