"""User model."""

from datetime import datetime, timezone

from werkzeug.security import check_password_hash, generate_password_hash

from app.extensions import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    username = db.Column(db.String(64), unique=True, nullable=True, index=True)
    email = db.Column(db.String(256), unique=True, nullable=True, index=True)
    password_hash = db.Column(db.String(256), nullable=True)
    user_group = db.Column(
        db.Enum("anonymous", "normal", "vip", "admin", name="user_group_enum"),
        nullable=False,
        default="normal",
    )
    is_anonymous = db.Column(db.Boolean, nullable=False, default=False)
    is_banned = db.Column(db.Boolean, nullable=False, default=False)

    # Anonymous-user identification
    ip_address = db.Column(db.String(64), nullable=True, index=True)
    device_fingerprint = db.Column(db.String(256), nullable=True, index=True)

    # Per-user quota overrides stored as JSON (null means use group defaults)
    custom_quota_overrides = db.Column(db.JSON, nullable=True)

    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    devices = db.relationship("Device", back_populates="user", lazy="dynamic", cascade="all, delete-orphan")
    files = db.relationship("File", back_populates="user", lazy="dynamic", cascade="all, delete-orphan")
    sent_transfers = db.relationship(
        "Transfer", foreign_keys="Transfer.sender_id", back_populates="sender", lazy="dynamic"
    )
    received_transfers = db.relationship(
        "Transfer", foreign_keys="Transfer.receiver_id", back_populates="receiver", lazy="dynamic"
    )
    traffic_usages = db.relationship(
        "TrafficUsage", back_populates="user", lazy="dynamic", cascade="all, delete-orphan"
    )

    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        if not self.password_hash:
            return False
        return check_password_hash(self.password_hash, password)

    def to_dict(self, include_sensitive: bool = False) -> dict:
        data = {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "user_group": self.user_group,
            "is_anonymous": self.is_anonymous,
            "is_banned": self.is_banned,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
        if include_sensitive:
            data["ip_address"] = self.ip_address
            data["device_fingerprint"] = self.device_fingerprint
            data["custom_quota_overrides"] = self.custom_quota_overrides
        return data

    def __repr__(self) -> str:
        return f"<User id={self.id} username={self.username!r} group={self.user_group}>"
