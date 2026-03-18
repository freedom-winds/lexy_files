"""Unit tests for FileService."""

import io
import os
import tempfile
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest

from app.extensions import db
from app.models.file import File
from app.models.user import User
from app.services.file_service import FileService
from app.utils.errors import FileExpiredError, NotFoundError, ValidationError
from app.utils.helpers import utcnow


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_file_storage(content: bytes = b"hello world", filename: str = "test.txt"):
    """Return a minimal Werkzeug-compatible FileStorage stub."""
    from werkzeug.datastructures import FileStorage
    return FileStorage(
        stream=io.BytesIO(content),
        filename=filename,
        content_type="text/plain",
    )


def _create_active_file(app, user, storage_path: str, pickup_code: str = "AABBCC") -> File:
    """Persist an active File record pointing at *storage_path*.

    Must be called inside an existing app context.
    """
    f = File(
        user_id=user.id,
        original_filename="sample.txt",
        stored_filename=os.path.basename(storage_path),
        file_size=len(b"hello world"),
        mime_type="text/plain",
        pickup_code=pickup_code,
        status="active",
        storage_path=storage_path,
    )
    db.session.add(f)
    db.session.commit()
    return db.session.get(File, f.id)


# ---------------------------------------------------------------------------
# save_uploaded_file
# ---------------------------------------------------------------------------

class TestSaveUploadedFile:
    def test_creates_file_record(self, app, normal_user, upload_folder):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            fs = make_file_storage(b"data data data", "report.pdf")
            file_record = FileService.save_uploaded_file(fs, u)

            assert file_record.id is not None
            assert file_record.user_id == u.id
            assert file_record.original_filename == "report.pdf"
            assert file_record.file_size == len(b"data data data")
            assert file_record.status == "active"
            assert file_record.pickup_code is not None

    def test_file_written_to_disk(self, app, normal_user, upload_folder):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            fs = make_file_storage(b"disk content", "disk_test.bin")
            file_record = FileService.save_uploaded_file(fs, u)

            assert os.path.isfile(file_record.storage_path)
            with open(file_record.storage_path, "rb") as fh:
                assert fh.read() == b"disk content"

    def test_generates_unique_pickup_code(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            r1 = FileService.save_uploaded_file(make_file_storage(b"a", "a.txt"), u)
            r2 = FileService.save_uploaded_file(make_file_storage(b"b", "b.txt"), u)
            assert r1.pickup_code != r2.pickup_code

    def test_sets_expires_at_for_users_with_retention(self, app, anon_user):
        with app.app_context():
            u = db.session.get(User, anon_user.id)
            before = utcnow().replace(tzinfo=None)
            file_record = FileService.save_uploaded_file(make_file_storage(b"x", "x.bin"), u)
            after = utcnow().replace(tzinfo=None)

            # Anonymous users have a 15-minute retention.
            assert file_record.expires_at is not None
            # Normalize timezone for SQLite (returns naive datetimes)
            expires = file_record.expires_at.replace(tzinfo=None) if file_record.expires_at.tzinfo else file_record.expires_at
            assert expires > before
            assert expires < after + timedelta(seconds=20 * 60)

    def test_raises_validation_error_on_code_exhaustion(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            with patch("app.services.file_service.generate_pickup_code", return_value="ZZZZZZ"):
                # Seed one record with the same code to guarantee collision.
                existing = File(
                    user_id=u.id,
                    original_filename="existing.txt",
                    stored_filename="existing-stored.txt",
                    file_size=1,
                    status="active",
                    pickup_code="ZZZZZZ",
                    storage_path="/fake/existing.txt",
                )
                db.session.add(existing)
                db.session.commit()

                with pytest.raises(ValidationError):
                    FileService.save_uploaded_file(make_file_storage(b"y", "y.txt"), u)


# ---------------------------------------------------------------------------
# get_file_by_pickup_code
# ---------------------------------------------------------------------------

class TestGetFileByPickupCode:
    def test_returns_active_file(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "sample.txt")
            with open(real_path, "wb") as fh:
                fh.write(b"hello world")

            f = _create_active_file(app, u, real_path, pickup_code="AA2233")
            found = FileService.get_file_by_pickup_code("AA2233")
            assert found.id == f.id

    def test_case_insensitive_lookup(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "case.txt")
            with open(real_path, "wb") as fh:
                fh.write(b"data")

            f = _create_active_file(app, u, real_path, pickup_code="BB3344")
            # Lookup with lowercase — normalize_pickup_code uppercases it.
            found = FileService.get_file_by_pickup_code("bb3344")
            assert found.id == f.id

    def test_raises_not_found_for_unknown_code(self, app):
        with app.app_context():
            with pytest.raises(NotFoundError):
                FileService.get_file_by_pickup_code("XXXXXX")

    def test_raises_file_expired_for_overdue_file(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "expired.txt")
            with open(real_path, "wb") as fh:
                fh.write(b"data")

            past = utcnow() - timedelta(hours=1)
            f = File(
                user_id=u.id,
                original_filename="expired.txt",
                stored_filename="expired-stored.txt",
                file_size=4,
                pickup_code="EXP123",
                status="active",
                storage_path=real_path,
                expires_at=past,
            )
            db.session.add(f)
            db.session.commit()

            with pytest.raises(FileExpiredError):
                FileService.get_file_by_pickup_code("EXP123")

            # The file status should now be 'expired'.
            refreshed = db.session.get(File, f.id)
            assert refreshed.status == "expired"


# ---------------------------------------------------------------------------
# expire_file / delete_file
# ---------------------------------------------------------------------------

class TestExpireFile:
    def test_sets_status_to_expired_and_redemption_ends_at(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "toexpire.txt")
            with open(real_path, "wb") as fh:
                fh.write(b"data")

            f = _create_active_file(app, u, real_path, pickup_code="EX9900")
            FileService.expire_file(f)

            refreshed = db.session.get(File, f.id)
            assert refreshed.status == "expired"
            assert refreshed.redemption_ends_at is not None
            # Normalize timezone for SQLite (returns naive datetimes)
            redemption = refreshed.redemption_ends_at
            now = utcnow().replace(tzinfo=None)
            if redemption.tzinfo:
                redemption = redemption.replace(tzinfo=None)
            assert redemption > now


class TestDeleteFile:
    def test_removes_file_from_disk_and_marks_deleted(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "todelete.txt")
            with open(real_path, "wb") as fh:
                fh.write(b"delete me")

            f = _create_active_file(app, u, real_path, pickup_code="DEL001")
            FileService.delete_file(f)

            assert not os.path.exists(real_path)
            refreshed = db.session.get(File, f.id)
            assert refreshed.status == "deleted"
            assert refreshed.deleted_at is not None

    def test_handles_already_missing_file_gracefully(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            missing_path = str(tmp_path / "ghost.txt")
            # Do NOT create the file; storage_path points to a nonexistent path.
            f = File(
                user_id=u.id,
                original_filename="ghost.txt",
                stored_filename="ghost-stored.txt",
                file_size=0,
                status="active",
                pickup_code="GHO001",
                storage_path=missing_path,
            )
            db.session.add(f)
            db.session.commit()

            # Should not raise.
            FileService.delete_file(f)
            refreshed = db.session.get(File, f.id)
            assert refreshed.status == "deleted"


# ---------------------------------------------------------------------------
# Admin operations
# ---------------------------------------------------------------------------

class TestAdminOperations:
    def test_force_expire_only_affects_active_files(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "admin_exp.txt")
            with open(real_path, "wb") as fh:
                fh.write(b"x")

            f = _create_active_file(app, u, real_path, pickup_code="ADM001")
            FileService.force_expire_file(f)
            assert db.session.get(File, f.id).status == "expired"

            # Calling again should be a no-op (already expired).
            FileService.force_expire_file(f)
            assert db.session.get(File, f.id).status == "expired"

    def test_force_delete_removes_any_status_file(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "admin_del.txt")
            with open(real_path, "wb") as fh:
                fh.write(b"x")

            f = _create_active_file(app, u, real_path, pickup_code="ADM002")
            FileService.force_delete_file(f)
            assert db.session.get(File, f.id).status == "deleted"


# ---------------------------------------------------------------------------
# create_download_stream
# ---------------------------------------------------------------------------

class TestCreateDownloadStream:
    def test_streams_correct_content(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "stream.bin")
            content = b"A" * 1024
            with open(real_path, "wb") as fh:
                fh.write(content)

            f = File(
                user_id=u.id,
                original_filename="stream.bin",
                stored_filename="stream-stored.bin",
                file_size=len(content),
                status="active",
                pickup_code="STR001",
                storage_path=real_path,
            )
            db.session.add(f)
            db.session.commit()

            # Use unlimited quota so no throttling.
            u.custom_quota_overrides = {
                "download_speed_limit": 0,
                "download_traffic_quota": 0,
                "traffic_quota_period": "daily",
            }
            db.session.commit()

            received = b"".join(FileService.create_download_stream(f, u))
            assert received == content

    def test_increments_download_count(self, app, normal_user, tmp_path):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            real_path = str(tmp_path / "count.bin")
            with open(real_path, "wb") as fh:
                fh.write(b"count me")

            f = File(
                user_id=u.id,
                original_filename="count.bin",
                stored_filename="count-stored.bin",
                file_size=8,
                status="active",
                pickup_code="CNT001",
                storage_path=real_path,
                download_count=0,
            )
            db.session.add(f)
            db.session.commit()
            fid = f.id

            u.custom_quota_overrides = {
                "download_speed_limit": 0,
                "download_traffic_quota": 0,
                "traffic_quota_period": "daily",
            }
            db.session.commit()

            # Exhaust the generator.
            list(FileService.create_download_stream(f, u))

            refreshed = db.session.get(File, fid)
            assert refreshed.download_count == 1
