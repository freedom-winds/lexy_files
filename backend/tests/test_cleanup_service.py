"""Unit tests for CleanupService."""

import os
from datetime import timedelta

from app.extensions import db
from app.models.file import File
from app.models.user import User
from app.services.cleanup_service import CleanupService
from app.utils.helpers import utcnow


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_file(app, user, status: str, pickup_code: str, storage_path: str = "/fake/path",
               expires_at=None, redemption_ends_at=None) -> File:
    with app.app_context():
        f = File(
            user_id=user.id,
            original_filename="file.bin",
            stored_filename=f"{pickup_code}-stored.bin",
            file_size=8,
            status=status,
            pickup_code=pickup_code,
            storage_path=storage_path,
            expires_at=expires_at,
            redemption_ends_at=redemption_ends_at,
        )
        db.session.add(f)
        db.session.commit()
        return db.session.get(File, f.id)


# ---------------------------------------------------------------------------
# expire_overdue_files
# ---------------------------------------------------------------------------

class TestExpireOverdueFiles:
    def test_expires_overdue_active_files(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "overdue.bin")
            with open(real_path, "wb") as fh:
                fh.write(b"overdue")

            past = utcnow() - timedelta(hours=1)
            f = _make_file(app, u, "active", "OD0001", real_path, expires_at=past)

            count = CleanupService.expire_overdue_files()
            assert count == 1

            refreshed = db.session.get(File, f.id)
            assert refreshed.status == "expired"
            assert refreshed.redemption_ends_at is not None

    def test_does_not_expire_future_files(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            future = utcnow() + timedelta(hours=10)
            f = _make_file(app, u, "active", "FU0001", expires_at=future)

            count = CleanupService.expire_overdue_files()
            assert count == 0

            refreshed = db.session.get(File, f.id)
            assert refreshed.status == "active"

    def test_does_not_expire_files_without_expires_at(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            # expires_at=None means no expiry.
            f = _make_file(app, u, "active", "NE0001", expires_at=None)

            count = CleanupService.expire_overdue_files()
            assert count == 0
            assert db.session.get(File, f.id).status == "active"

    def test_does_not_touch_non_active_files(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            past = utcnow() - timedelta(hours=1)
            # Already expired — should not be re-processed.
            _make_file(app, u, "expired", "AL0001", expires_at=past)

            count = CleanupService.expire_overdue_files()
            assert count == 0

    def test_returns_zero_when_nothing_to_expire(self, app):
        with app.app_context():
            count = CleanupService.expire_overdue_files()
            assert count == 0

    def test_expires_multiple_files(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            past = utcnow() - timedelta(minutes=5)
            ids = []
            for i in range(3):
                real_path = str(tmp_path / f"multi{i}.bin")
                with open(real_path, "wb") as fh:
                    fh.write(b"x")
                f = _make_file(app, u, "active", f"MU00{i}", real_path, expires_at=past)
                ids.append(f.id)

            count = CleanupService.expire_overdue_files()
            assert count == 3
            for fid in ids:
                assert db.session.get(File, fid).status == "expired"


# ---------------------------------------------------------------------------
# delete_redeemed_files
# ---------------------------------------------------------------------------

class TestDeleteRedeemedFiles:
    def test_deletes_files_past_redemption_window(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "redeemed.bin")
            with open(real_path, "wb") as fh:
                fh.write(b"gone soon")

            past = utcnow() - timedelta(hours=1)
            f = _make_file(
                app, u, "expired", "RD0001", real_path,
                redemption_ends_at=past,
            )

            count = CleanupService.delete_redeemed_files()
            assert count == 1

            refreshed = db.session.get(File, f.id)
            assert refreshed.status == "deleted"
            assert not os.path.exists(real_path)

    def test_does_not_delete_files_still_in_window(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            future = utcnow() + timedelta(days=3)
            f = _make_file(
                app, u, "expired", "RD0002",
                redemption_ends_at=future,
            )

            count = CleanupService.delete_redeemed_files()
            assert count == 0
            assert db.session.get(File, f.id).status == "expired"

    def test_does_not_delete_active_files(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            past = utcnow() - timedelta(hours=1)
            # Active file with an old redemption_ends_at (edge case).
            f = _make_file(
                app, u, "active", "RD0003",
                redemption_ends_at=past,
            )

            count = CleanupService.delete_redeemed_files()
            assert count == 0
            assert db.session.get(File, f.id).status == "active"

    def test_returns_zero_when_nothing_to_delete(self, app):
        with app.app_context():
            count = CleanupService.delete_redeemed_files()
            assert count == 0


# ---------------------------------------------------------------------------
# run_cleanup
# ---------------------------------------------------------------------------

class TestRunCleanup:
    def test_returns_combined_summary(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            past = utcnow() - timedelta(hours=1)

            # One overdue active file.
            path1 = str(tmp_path / "active.bin")
            with open(path1, "wb") as fh:
                fh.write(b"x")
            _make_file(app, u, "active", "RC0001", path1, expires_at=past)

            # One expired file past redemption.
            path2 = str(tmp_path / "expired.bin")
            with open(path2, "wb") as fh:
                fh.write(b"y")
            _make_file(app, u, "expired", "RC0002", path2, redemption_ends_at=past)

            result = CleanupService.run_cleanup()
            assert result["expired"] == 1
            assert result["deleted"] == 1

    def test_returns_zeros_when_nothing_to_do(self, app):
        with app.app_context():
            result = CleanupService.run_cleanup()
            assert result == {"expired": 0, "deleted": 0}
