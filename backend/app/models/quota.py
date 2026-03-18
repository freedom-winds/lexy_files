"""Quota-related models: GroupQuota and TrafficUsage."""

from datetime import datetime, timezone

from app.extensions import db


class GroupQuota(db.Model):
    """Default quota settings per user group. One row per group."""

    __tablename__ = "group_quotas"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    group_name = db.Column(
        db.Enum("anonymous", "normal", "vip", "admin", name="group_quota_enum"),
        nullable=False,
        unique=True,
        index=True,
    )
    # bytes/sec — 0 means unlimited
    download_speed_limit = db.Column(db.BigInteger, nullable=False, default=0)
    # bytes — 0 means unlimited
    max_single_file_size = db.Column(db.BigInteger, nullable=False, default=0)
    # bytes — 0 means unlimited
    max_total_storage = db.Column(db.BigInteger, nullable=False, default=0)
    # bytes — 0 means unlimited
    download_traffic_quota = db.Column(db.BigInteger, nullable=False, default=0)
    traffic_quota_period = db.Column(
        db.Enum("daily", "monthly", name="traffic_quota_period_enum"),
        nullable=False,
        default="daily",
    )
    # seconds — 0 means unlimited
    max_retention_seconds = db.Column(db.Integer, nullable=False, default=0)
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "group_name": self.group_name,
            "download_speed_limit": self.download_speed_limit,
            "max_single_file_size": self.max_single_file_size,
            "max_total_storage": self.max_total_storage,
            "download_traffic_quota": self.download_traffic_quota,
            "traffic_quota_period": self.traffic_quota_period,
            "max_retention_seconds": self.max_retention_seconds,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self) -> str:
        return f"<GroupQuota group={self.group_name}>"


# Default quota values matching the specification
DEFAULT_QUOTAS = {
    "anonymous": {
        "download_speed_limit": 3 * 1024 * 1024,       # 3 MB/s
        "max_single_file_size": 500 * 1024 * 1024,     # 500 MB
        "max_total_storage": 2 * 1024 ** 3,            # 2 GB
        "download_traffic_quota": 1 * 1024 ** 3,       # 1 GB/day
        "traffic_quota_period": "daily",
        "max_retention_seconds": 15 * 60,              # 15 min
    },
    "normal": {
        "download_speed_limit": 8 * 1024 * 1024,       # 8 MB/s
        "max_single_file_size": 2 * 1024 ** 3,         # 2 GB
        "max_total_storage": 10 * 1024 ** 3,           # 10 GB
        "download_traffic_quota": 5 * 1024 ** 3,       # 5 GB/day
        "traffic_quota_period": "daily",
        "max_retention_seconds": 6 * 3600,             # 6 hours
    },
    "vip": {
        "download_speed_limit": 15 * 1024 * 1024,      # 15 MB/s
        "max_single_file_size": 5 * 1024 ** 3,         # 5 GB
        "max_total_storage": 40 * 1024 ** 3,           # 40 GB
        "download_traffic_quota": 500 * 1024 ** 3,     # 500 GB/month
        "traffic_quota_period": "monthly",
        "max_retention_seconds": 5 * 24 * 3600,        # 5 days
    },
    "admin": {
        "download_speed_limit": 0,                     # unlimited
        "max_single_file_size": 0,                     # unlimited
        "max_total_storage": 0,                        # unlimited
        "download_traffic_quota": 0,                   # unlimited
        "traffic_quota_period": "monthly",
        "max_retention_seconds": 0,                    # unlimited
    },
}


class TrafficUsage(db.Model):
    """Tracks download traffic consumed by a user per period."""

    __tablename__ = "traffic_usages"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    bytes_downloaded = db.Column(db.BigInteger, nullable=False, default=0)
    period_start = db.Column(db.Date, nullable=False, index=True)
    period_type = db.Column(
        db.Enum("daily", "monthly", name="traffic_period_type_enum"),
        nullable=False,
        default="daily",
    )

    __table_args__ = (
        db.UniqueConstraint("user_id", "period_start", "period_type", name="uq_traffic_user_period"),
    )

    # Relationships
    user = db.relationship("User", back_populates="traffic_usages")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "bytes_downloaded": self.bytes_downloaded,
            "period_start": self.period_start.isoformat() if self.period_start else None,
            "period_type": self.period_type,
        }

    def __repr__(self) -> str:
        return f"<TrafficUsage user_id={self.user_id} period={self.period_start}>"
