"""Transfer model."""

from datetime import datetime, timezone

from app.extensions import db


class Transfer(db.Model):
    __tablename__ = "transfers"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    sender_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    receiver_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    sender_device_id = db.Column(
        db.Integer, db.ForeignKey("devices.id", ondelete="SET NULL"), nullable=True, index=True
    )
    receiver_device_id = db.Column(
        db.Integer, db.ForeignKey("devices.id", ondelete="SET NULL"), nullable=True, index=True
    )
    mode = db.Column(
        db.Enum("bluetooth", "lan", "same_account", "pickup", name="transfer_mode_enum"),
        nullable=False,
    )
    status = db.Column(
        db.Enum(
            "pending",
            "accepted",
            "in_progress",
            "completed",
            "rejected",
            "cancelled",
            "failed",
            name="transfer_status_enum",
        ),
        nullable=False,
        default="pending",
        index=True,
    )
    file_name = db.Column(db.String(512), nullable=False)
    file_size = db.Column(db.BigInteger, nullable=False)
    bytes_transferred = db.Column(db.BigInteger, nullable=False, default=0)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    completed_at = db.Column(db.DateTime, nullable=True)

    # Relationships
    sender = db.relationship("User", foreign_keys=[sender_id], back_populates="sent_transfers")
    receiver = db.relationship("User", foreign_keys=[receiver_id], back_populates="received_transfers")
    sender_device = db.relationship("Device", foreign_keys=[sender_device_id], back_populates="sent_transfers")
    receiver_device = db.relationship(
        "Device", foreign_keys=[receiver_device_id], back_populates="received_transfers"
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "sender_id": self.sender_id,
            "receiver_id": self.receiver_id,
            "sender_device_id": self.sender_device_id,
            "receiver_device_id": self.receiver_device_id,
            "mode": self.mode,
            "status": self.status,
            "file_name": self.file_name,
            "file_size": self.file_size,
            "bytes_transferred": self.bytes_transferred,
            "progress_percent": (
                round(self.bytes_transferred / self.file_size * 100, 2) if self.file_size > 0 else 0
            ),
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }

    def __repr__(self) -> str:
        return f"<Transfer id={self.id} mode={self.mode} status={self.status}>"
