"""Device model."""

from datetime import datetime, timezone

from app.extensions import db


class Device(db.Model):
    __tablename__ = "devices"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name = db.Column(db.String(128), nullable=False)
    device_type = db.Column(
        db.Enum("phone", "tablet", "laptop", "desktop", "other", name="device_type_enum"),
        nullable=False,
        default="other",
    )
    platform = db.Column(
        db.Enum("android", "ios", "windows", "macos", "linux", "web", name="device_platform_enum"),
        nullable=False,
        default="web",
    )
    device_id = db.Column(db.String(256), unique=True, nullable=False, index=True)
    is_online = db.Column(db.Boolean, nullable=False, default=False)
    last_seen_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))

    # Relationships
    user = db.relationship("User", back_populates="devices")
    sent_transfers = db.relationship(
        "Transfer", foreign_keys="Transfer.sender_device_id", back_populates="sender_device", lazy="dynamic"
    )
    received_transfers = db.relationship(
        "Transfer", foreign_keys="Transfer.receiver_device_id", back_populates="receiver_device", lazy="dynamic"
    )

    def mark_online(self) -> None:
        self.is_online = True
        self.last_seen_at = datetime.now(timezone.utc)

    def mark_offline(self) -> None:
        self.is_online = False
        self.last_seen_at = datetime.now(timezone.utc)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "name": self.name,
            "device_type": self.device_type,
            "platform": self.platform,
            "device_id": self.device_id,
            "is_online": self.is_online,
            "last_seen_at": self.last_seen_at.isoformat() if self.last_seen_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self) -> str:
        return f"<Device id={self.id} name={self.name!r} platform={self.platform}>"
