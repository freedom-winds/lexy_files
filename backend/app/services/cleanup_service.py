"""Background cleanup service.

Transitions overdue active files to expired/redemption status, then physically
deletes files whose redemption window has closed.  Designed to be called from
an APScheduler job or a management CLI command.
"""

from app.models.file import File
from app.services.file_service import FileService
from app.utils.helpers import utcnow


class CleanupService:
    @staticmethod
    def expire_overdue_files() -> int:
        """Find active files past their ``expires_at`` and move them to redemption.

        Returns:
            The number of files that were transitioned.
        """
        now = utcnow()
        overdue_files = File.query.filter(
            File.status == "active",
            File.expires_at.is_not(None),
            File.expires_at < now,
        ).all()

        count = 0
        for f in overdue_files:
            FileService.expire_file(f)
            count += 1

        return count

    @staticmethod
    def delete_redeemed_files() -> int:
        """Find expired files past their ``redemption_ends_at`` and delete them.

        Returns:
            The number of files that were physically deleted.
        """
        now = utcnow()
        expired_files = File.query.filter(
            File.status == "expired",
            File.redemption_ends_at.is_not(None),
            File.redemption_ends_at < now,
        ).all()

        count = 0
        for f in expired_files:
            FileService.delete_file(f)
            count += 1

        return count

    @staticmethod
    def run_cleanup() -> dict:
        """Execute all cleanup tasks and return a summary.

        Returns:
            {"expired": int, "deleted": int}
        """
        expired = CleanupService.expire_overdue_files()
        deleted = CleanupService.delete_redeemed_files()
        return {"expired": expired, "deleted": deleted}
