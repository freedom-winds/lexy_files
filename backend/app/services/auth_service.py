"""Authentication service: registration, login, anonymous users, JWT lifecycle."""

import redis as redis_lib
from flask import current_app
from flask_jwt_extended import create_access_token, create_refresh_token
from sqlalchemy import or_

from app.extensions import db
from app.models.user import User
from app.utils.constants import REDIS_JWT_BLACKLIST_PREFIX
from app.utils.errors import AuthenticationError, BannedError, ConflictError


class AuthService:
    # ── Registration ──────────────────────────────────────────────────────────

    @staticmethod
    def register_user(username: str, email: str, password: str) -> User:
        """Create a new registered user.

        Raises:
            ConflictError: if the username or email is already taken.
        """
        if User.query.filter_by(username=username).first() is not None:
            raise ConflictError(f"Username '{username}' is already taken.")

        if User.query.filter_by(email=email).first() is not None:
            raise ConflictError(f"Email '{email}' is already registered.")

        user = User(
            username=username,
            email=email,
            user_group="normal",
            is_anonymous=False,
        )
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        return user

    # ── Authentication ────────────────────────────────────────────────────────

    @staticmethod
    def authenticate(username: str, password: str) -> User:
        """Verify credentials and return the user.

        Raises:
            AuthenticationError: if credentials are invalid.
            BannedError: if the user account is banned.
        """
        user = User.query.filter_by(username=username).first()
        if user is None or not user.check_password(password):
            raise AuthenticationError("Invalid username or password.")

        if user.is_banned:
            raise BannedError()

        return user

    # ── Anonymous users ───────────────────────────────────────────────────────

    @staticmethod
    def find_or_create_anonymous(ip_address: str, device_fingerprint: str) -> User:
        """Find an existing anonymous session or create a fresh one.

        Matching is done by IP address OR device fingerprint so that a user
        retains their session if either identifier is preserved across
        requests.  If both identifiers have changed the record is updated to
        reflect the latest values.
        """
        user = User.query.filter(
            User.is_anonymous == True,  # noqa: E712
            or_(
                User.ip_address == ip_address,
                User.device_fingerprint == device_fingerprint,
            ),
        ).first()

        if user is not None:
            # Refresh both identifiers if they have drifted (e.g. IP change).
            changed = False
            if user.ip_address != ip_address:
                user.ip_address = ip_address
                changed = True
            if user.device_fingerprint != device_fingerprint:
                user.device_fingerprint = device_fingerprint
                changed = True
            if changed:
                db.session.commit()
        else:
            user = User(
                is_anonymous=True,
                user_group="anonymous",
                ip_address=ip_address,
                device_fingerprint=device_fingerprint,
            )
            db.session.add(user)
            db.session.commit()

        return user

    # ── Token generation ──────────────────────────────────────────────────────

    @staticmethod
    def generate_tokens(user: User) -> dict:
        """Generate a fresh access + refresh JWT pair for *user*.

        Returns:
            {"access_token": str, "refresh_token": str}
        """
        additional_claims = {
            "user_group": user.user_group,
            "is_anonymous": user.is_anonymous,
        }
        access_token = create_access_token(
            identity=str(user.id),
            additional_claims=additional_claims,
        )
        refresh_token = create_refresh_token(
            identity=str(user.id),
            additional_claims=additional_claims,
        )
        return {"access_token": access_token, "refresh_token": refresh_token}

    # ── Token revocation ──────────────────────────────────────────────────────

    @staticmethod
    def revoke_token(jti: str, expires_in: int) -> None:
        """Add a JWT ID to the Redis blacklist with TTL *expires_in* seconds."""
        client = AuthService.get_redis()
        key = REDIS_JWT_BLACKLIST_PREFIX + jti
        client.setex(key, expires_in, "revoked")

    @staticmethod
    def is_token_revoked(jti: str) -> bool:
        """Return True if the JWT ID is present in the Redis blacklist."""
        client = AuthService.get_redis()
        key = REDIS_JWT_BLACKLIST_PREFIX + jti
        return client.exists(key) == 1

    # ── Redis helper ──────────────────────────────────────────────────────────

    @staticmethod
    def get_redis() -> redis_lib.Redis:
        """Return a Redis client built from current_app config."""
        return redis_lib.from_url(
            current_app.config["REDIS_URL"],
            decode_responses=True,
        )
