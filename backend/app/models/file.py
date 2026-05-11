"""File model."""

from datetime import datetime, timezone

from app.extensions import db


class File(db.Model):
    __tablename__ = "files"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    original_filename = db.Column(db.String(512), nullable=False)
    stored_filename = db.Column(db.String(512), nullable=False, unique=True)
    file_size = db.Column(db.BigInteger, nullable=False)  # bytes
    mime_type = db.Column(db.String(256), nullable=True)
    pickup_code = db.Column(db.String(16), nullable=True, unique=True, index=True)
    download_count = db.Column(db.Integer, nullable=False, default=0)
    status = db.Column(
        db.Enum("active", "expired", "redemption", "deleted", name="file_status_enum"),
        nullable=False,
        default="active",
        index=True,
    )
    storage_path = db.Column(db.String(1024), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=True, index=True)
    # Set when status transitions to 'expired'; redemption window is expires_at + 7 days
    redemption_ends_at = db.Column(db.DateTime, nullable=True, index=True)
    deleted_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))

    # Relationships
    user = db.relationship("User", back_populates="files")

    def is_accessible(self) -> bool:
        """Return True if the file can be downloaded by a normal user."""
        return self.status == "active"

    def is_expired(self) -> bool:
        """Return True when the active window has passed (regardless of DB status)."""
        if self.expires_at is None:
            return False
        now = datetime.now(timezone.utc)
        exp = self.expires_at
        if exp.tzinfo is None:
            from datetime import timezone as tz
            exp = exp.replace(tzinfo=tz.utc)
        return now > exp

    def to_dict(self, include_admin: bool = False) -> dict:
        data = {
            "id": self.id,
            "user_id": self.user_id,
            "original_filename": self.original_filename,
            "file_size": self.file_size,
            "mime_type": self.mime_type,
            "pickup_code": self.pickup_code,
            "download_count": self.download_count,
            "max_downloads": None,
            "status": self.status,
            "is_expired": self.status != "active" or self.is_expired(),
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "redemption_ends_at": self.redemption_ends_at.isoformat() if self.redemption_ends_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if include_admin:
            data["uploader_id"] = self.user_id
            data["uploader_username"] = self.user.username if self.user else None
            data["storage_path"] = self.storage_path
            data["stored_filename"] = self.stored_filename
            data["deleted_at"] = self.deleted_at.isoformat() if self.deleted_at else None
        return data

    def __repr__(self) -> str:
        return f"<File id={self.id} name={self.original_filename!r} status={self.status}>"
