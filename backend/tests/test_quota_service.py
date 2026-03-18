"""Unit tests for QuotaService."""

import pytest
from datetime import date

from app.extensions import db
from app.models.file import File
from app.models.quota import DEFAULT_QUOTAS, GroupQuota, TrafficUsage
from app.models.user import User
from app.services.quota_service import QuotaService
from app.utils.errors import FileTooLargeError, QuotaExceededError, StorageFullError
from app.utils.helpers import get_period_start


# ---------------------------------------------------------------------------
# get_effective_quota
# ---------------------------------------------------------------------------

class TestGetEffectiveQuota:
    def test_returns_default_quotas_for_normal_user(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            quota = QuotaService.get_effective_quota(u)
            expected = DEFAULT_QUOTAS["normal"]
            for key, value in expected.items():
                assert quota[key] == value

    def test_db_group_quota_overrides_defaults(self, app, normal_user):
        with app.app_context():
            gq = GroupQuota(
                group_name="normal",
                download_speed_limit=999,
                max_single_file_size=1,
                max_total_storage=2,
                download_traffic_quota=3,
                traffic_quota_period="monthly",
                max_retention_seconds=4,
            )
            db.session.add(gq)
            db.session.commit()

            u = db.session.get(User, normal_user.id)
            quota = QuotaService.get_effective_quota(u)
            assert quota["download_speed_limit"] == 999
            assert quota["traffic_quota_period"] == "monthly"

    def test_custom_user_overrides_take_highest_priority(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"download_speed_limit": 42, "max_retention_seconds": 99}
            db.session.commit()

            quota = QuotaService.get_effective_quota(u)
            assert quota["download_speed_limit"] == 42
            assert quota["max_retention_seconds"] == 99
            # Other keys still come from defaults.
            assert quota["max_single_file_size"] == DEFAULT_QUOTAS["normal"]["max_single_file_size"]

    def test_anonymous_group_defaults_applied(self, app, anon_user):
        with app.app_context():
            u = db.session.get(User, anon_user.id)
            quota = QuotaService.get_effective_quota(u)
            assert quota["max_single_file_size"] == DEFAULT_QUOTAS["anonymous"]["max_single_file_size"]


# ---------------------------------------------------------------------------
# check_upload_allowed
# ---------------------------------------------------------------------------

class TestCheckUploadAllowed:
    def test_allows_upload_within_limits(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            # Should not raise — 1 byte is always under any reasonable limit.
            QuotaService.check_upload_allowed(u, 1)

    def test_raises_file_too_large(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"max_single_file_size": 100}
            db.session.commit()
            with pytest.raises(FileTooLargeError):
                QuotaService.check_upload_allowed(u, 101)

    def test_raises_storage_full(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"max_total_storage": 200, "max_single_file_size": 0}
            db.session.commit()

            # Simulate existing stored files.
            existing = File(
                user_id=u.id,
                original_filename="big.bin",
                stored_filename="big-stored.bin",
                file_size=150,
                status="active",
                storage_path="/fake/path/big-stored.bin",
            )
            db.session.add(existing)
            db.session.commit()

            with pytest.raises(StorageFullError):
                QuotaService.check_upload_allowed(u, 60)

    def test_zero_max_single_file_size_is_unlimited(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"max_single_file_size": 0, "max_total_storage": 0}
            db.session.commit()
            # Should not raise for any size when limits are 0.
            QuotaService.check_upload_allowed(u, 10 * 1024 ** 3)

    def test_zero_max_total_storage_is_unlimited(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"max_single_file_size": 0, "max_total_storage": 0}
            db.session.commit()
            QuotaService.check_upload_allowed(u, 50 * 1024 ** 3)


# ---------------------------------------------------------------------------
# check_download_allowed
# ---------------------------------------------------------------------------

class TestCheckDownloadAllowed:
    def test_allows_when_quota_is_unlimited(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"download_traffic_quota": 0}
            db.session.commit()
            # Must not raise.
            QuotaService.check_download_allowed(u)

    def test_raises_when_quota_exhausted(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"download_traffic_quota": 100, "traffic_quota_period": "daily"}
            db.session.commit()

            period_start = get_period_start("daily")
            usage = TrafficUsage(
                user_id=u.id,
                bytes_downloaded=100,
                period_start=period_start,
                period_type="daily",
            )
            db.session.add(usage)
            db.session.commit()

            with pytest.raises(QuotaExceededError):
                QuotaService.check_download_allowed(u)

    def test_allows_when_quota_not_yet_exhausted(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"download_traffic_quota": 1000, "traffic_quota_period": "daily"}
            db.session.commit()

            period_start = get_period_start("daily")
            usage = TrafficUsage(
                user_id=u.id,
                bytes_downloaded=500,
                period_start=period_start,
                period_type="daily",
            )
            db.session.add(usage)
            db.session.commit()

            # Must not raise.
            QuotaService.check_download_allowed(u)


# ---------------------------------------------------------------------------
# track_download
# ---------------------------------------------------------------------------

class TestTrackDownload:
    def test_creates_usage_record_on_first_track(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"download_traffic_quota": 9999, "traffic_quota_period": "daily"}
            db.session.commit()

            QuotaService.track_download(u, 512)

            period_start = get_period_start("daily")
            usage = TrafficUsage.query.filter_by(
                user_id=u.id, period_start=period_start, period_type="daily"
            ).first()
            assert usage is not None
            assert usage.bytes_downloaded == 512

    def test_accumulates_bytes_across_calls(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.custom_quota_overrides = {"download_traffic_quota": 9999, "traffic_quota_period": "daily"}
            db.session.commit()

            QuotaService.track_download(u, 100)
            QuotaService.track_download(u, 200)

            period_start = get_period_start("daily")
            usage = TrafficUsage.query.filter_by(
                user_id=u.id, period_start=period_start, period_type="daily"
            ).first()
            assert usage.bytes_downloaded == 300


# ---------------------------------------------------------------------------
# get_current_storage
# ---------------------------------------------------------------------------

class TestGetCurrentStorage:
    def test_zero_when_no_files(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            assert QuotaService.get_current_storage(u) == 0

    def test_sums_active_and_expired_files(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            for status, size in [("active", 100), ("expired", 200), ("deleted", 50)]:
                f = File(
                    user_id=u.id,
                    original_filename=f"{status}.bin",
                    stored_filename=f"{status}-stored.bin",
                    file_size=size,
                    status=status,
                    storage_path=f"/fake/{status}.bin",
                )
                db.session.add(f)
            db.session.commit()

            # deleted files should NOT be counted.
            assert QuotaService.get_current_storage(u) == 300

    def test_excludes_other_users_files(self, app, normal_user, anon_user):
        with app.app_context():
            # Add a file for anon_user.
            f = File(
                user_id=anon_user.id,
                original_filename="other.bin",
                stored_filename="other-stored.bin",
                file_size=999,
                status="active",
                storage_path="/fake/other.bin",
            )
            db.session.add(f)
            db.session.commit()

            u = db.session.get(User, normal_user.id)
            assert QuotaService.get_current_storage(u) == 0


# ---------------------------------------------------------------------------
# get_download_speed_limit / get_retention_seconds
# ---------------------------------------------------------------------------

class TestSimpleGetters:
    def test_get_download_speed_limit(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            limit = QuotaService.get_download_speed_limit(u)
            assert limit == DEFAULT_QUOTAS["normal"]["download_speed_limit"]

    def test_get_retention_seconds(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            retention = QuotaService.get_retention_seconds(u)
            assert retention == DEFAULT_QUOTAS["normal"]["max_retention_seconds"]
