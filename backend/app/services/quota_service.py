"""Quota enforcement service.

Resolves effective quotas per user (group defaults → DB overrides → per-user
overrides) and enforces upload / download limits.
"""

from sqlalchemy import func

from app.extensions import db
from app.models.file import File
from app.models.quota import DEFAULT_QUOTAS, GroupQuota, TrafficUsage
from app.models.user import User
from app.utils.errors import FileTooLargeError, QuotaExceededError, StorageFullError
from app.utils.helpers import get_period_start


class QuotaService:
    # ── Quota resolution ──────────────────────────────────────────────────────

    @staticmethod
    def get_effective_quota(user: User) -> dict:
        """Return the effective quota dict for *user*.

        Resolution order (later entries override earlier ones):
          1. Hard-coded DEFAULT_QUOTAS for the user's group.
          2. GroupQuota table row for the user's group (DB-managed overrides).
          3. user.custom_quota_overrides (per-user JSON overrides).

        The returned dict always contains all six quota keys:
          download_speed_limit, max_single_file_size, max_total_storage,
          download_traffic_quota, traffic_quota_period, max_retention_seconds.
        """
        group = user.user_group or "normal"

        # Layer 1: hard-coded defaults.
        quota = dict(DEFAULT_QUOTAS.get(group, DEFAULT_QUOTAS["normal"]))

        # Layer 2: DB-managed group quota (may partially override defaults).
        group_row = GroupQuota.query.filter_by(group_name=group).first()
        if group_row is not None:
            quota.update(
                {
                    "download_speed_limit": group_row.download_speed_limit,
                    "max_single_file_size": group_row.max_single_file_size,
                    "max_total_storage": group_row.max_total_storage,
                    "download_traffic_quota": group_row.download_traffic_quota,
                    "traffic_quota_period": group_row.traffic_quota_period,
                    "max_retention_seconds": group_row.max_retention_seconds,
                }
            )

        # Layer 3: per-user custom overrides (partial dict).
        if user.custom_quota_overrides:
            for key in (
                "download_speed_limit",
                "max_single_file_size",
                "max_total_storage",
                "download_traffic_quota",
                "traffic_quota_period",
                "max_retention_seconds",
            ):
                if key in user.custom_quota_overrides:
                    quota[key] = user.custom_quota_overrides[key]

        return quota

    # ── Upload checks ─────────────────────────────────────────────────────────

    @staticmethod
    def check_upload_allowed(user: User, file_size: int) -> None:
        """Assert that *user* is allowed to upload a file of *file_size* bytes.

        Raises:
            FileTooLargeError: if the file exceeds max_single_file_size.
            StorageFullError: if uploading would exceed max_total_storage.
        """
        quota = QuotaService.get_effective_quota(user)

        max_single = quota["max_single_file_size"]
        if max_single > 0 and file_size > max_single:
            raise FileTooLargeError(
                f"File size {file_size} bytes exceeds the maximum allowed "
                f"single-file size of {max_single} bytes.",
                details={"max_single_file_size": max_single, "file_size": file_size},
            )

        max_total = quota["max_total_storage"]
        if max_total > 0:
            current_storage = QuotaService.get_current_storage(user)
            if current_storage + file_size > max_total:
                raise StorageFullError(
                    "You have exceeded your total storage quota.",
                    details={
                        "max_total_storage": max_total,
                        "current_storage": current_storage,
                        "file_size": file_size,
                    },
                )

    # ── Download checks ───────────────────────────────────────────────────────

    @staticmethod
    def check_download_allowed(user: User) -> None:
        """Assert that *user* has remaining download traffic for the current period.

        Raises:
            QuotaExceededError: if the user's download traffic quota is exhausted.
        """
        quota = QuotaService.get_effective_quota(user)
        traffic_quota = quota["download_traffic_quota"]
        if traffic_quota == 0:
            # 0 means unlimited; nothing to check.
            return

        period_type = quota["traffic_quota_period"]
        usage = QuotaService._get_or_create_traffic_usage(user, period_type)

        if usage.bytes_downloaded >= traffic_quota:
            raise QuotaExceededError(
                "Your download traffic quota for this period has been exhausted.",
                details={
                    "download_traffic_quota": traffic_quota,
                    "bytes_downloaded": usage.bytes_downloaded,
                    "period_start": usage.period_start.isoformat(),
                    "period_type": period_type,
                },
            )

    @staticmethod
    def track_download(user: User, bytes_count: int) -> None:
        """Record *bytes_count* downloaded bytes for *user* in the current period."""
        quota = QuotaService.get_effective_quota(user)
        period_type = quota["traffic_quota_period"]
        usage = QuotaService._get_or_create_traffic_usage(user, period_type)
        usage.bytes_downloaded += bytes_count
        db.session.commit()

    # ── Speed / retention helpers ─────────────────────────────────────────────

    @staticmethod
    def get_download_speed_limit(user: User) -> int:
        """Return download speed limit in bytes/sec. 0 means unlimited."""
        return QuotaService.get_effective_quota(user)["download_speed_limit"]

    @staticmethod
    def get_retention_seconds(user: User) -> int:
        """Return maximum file retention time in seconds. 0 means unlimited."""
        return QuotaService.get_effective_quota(user)["max_retention_seconds"]

    # ── Storage accounting ────────────────────────────────────────────────────

    @staticmethod
    def get_current_storage(user: User) -> int:
        """Return total bytes currently stored for *user* across active files."""
        result = (
            db.session.query(
                func.coalesce(func.sum(File.file_size), 0)
            )
            .filter(
                File.user_id == user.id,
                File.status.in_(["active", "expired", "redemption"]),
            )
            .scalar()
        )
        return int(result)

    # ── Internal helpers ──────────────────────────────────────────────────────

    @staticmethod
    def _get_or_create_traffic_usage(user: User, period_type: str) -> TrafficUsage:
        """Return the TrafficUsage row for *user* in the current period.

        Creates a fresh row (with bytes_downloaded = 0) if none exists yet.
        """
        period_start = get_period_start(period_type)
        usage = TrafficUsage.query.filter_by(
            user_id=user.id,
            period_start=period_start,
            period_type=period_type,
        ).first()

        if usage is None:
            usage = TrafficUsage(
                user_id=user.id,
                period_start=period_start,
                period_type=period_type,
                bytes_downloaded=0,
            )
            db.session.add(usage)
            db.session.flush()  # assign PK without committing the outer transaction

        return usage
