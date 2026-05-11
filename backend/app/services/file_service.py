"""File management service: upload, retrieval, streaming download, expiry, deletion."""

import mimetypes
import os
import time
import uuid
from datetime import datetime, timedelta

from werkzeug.utils import secure_filename

from app.extensions import db
from app.models.file import File
from app.services.quota_service import QuotaService
from app.storage import get_storage
from app.utils.constants import DOWNLOAD_CHUNK_SIZE, MAX_PICKUP_CODE_ATTEMPTS, REDEMPTION_GRACE_DAYS
from app.utils.errors import FileExpiredError, NotFoundError, ValidationError
from app.utils.helpers import generate_pickup_code, normalize_pickup_code, utcnow


class FileService:
    # ── Upload ────────────────────────────────────────────────────────────────

    @staticmethod
    def save_uploaded_file(file_storage, user) -> File:
        """Persist an uploaded file and create the corresponding DB record.

        Works with any configured storage backend (local filesystem or S3).

        Args:
            file_storage: A Werkzeug ``FileStorage`` object (from ``request.files``).
            user:         The ``User`` performing the upload.

        Returns:
            The newly-created ``File`` model instance.

        Raises:
            ValidationError: if a unique pickup code cannot be generated.
        """
        original_filename = secure_filename(file_storage.filename or "upload")

        # Generate a UUID-based name to avoid storage collisions.
        extension = os.path.splitext(original_filename)[1]
        stored_filename = f"{uuid.uuid4().hex}{extension}"

        # Determine MIME type from the original filename.
        mime_type, _ = mimetypes.guess_type(original_filename)

        # Delegate to the configured storage backend.
        storage = get_storage()
        storage_key, file_size = storage.save(file_storage, user.id, stored_filename)

        # Generate a unique pickup code, retrying on collision.
        pickup_code = FileService._generate_unique_pickup_code()

        # Calculate expiry based on quota.
        retention_seconds = QuotaService.get_retention_seconds(user)
        expires_at: datetime | None = None
        if retention_seconds > 0:
            expires_at = utcnow() + timedelta(seconds=retention_seconds)

        file_record = File(
            user_id=user.id,
            original_filename=original_filename,
            stored_filename=stored_filename,
            file_size=file_size,
            mime_type=mime_type,
            pickup_code=pickup_code,
            download_count=0,
            status="active",
            storage_path=storage_key,
            expires_at=expires_at,
        )
        db.session.add(file_record)
        db.session.commit()
        return file_record

    # ── Retrieval ─────────────────────────────────────────────────────────────

    @staticmethod
    def get_file_by_pickup_code(code: str) -> File:
        """Look up an active file by pickup code (case-insensitive).

        Raises:
            NotFoundError:    if no active file exists for the code.
            FileExpiredError: if the file's active window has passed.
        """
        normalized = normalize_pickup_code(code)
        file_record = File.query.filter(
            File.pickup_code == normalized,
            File.status == "active",
        ).first()

        if file_record is None:
            raise NotFoundError("No active file found for the given pickup code.")

        if file_record.is_expired():
            FileService.expire_file(file_record)
            raise FileExpiredError(
                "The file associated with this pickup code has expired."
            )

        return file_record

    # ── Streaming download ────────────────────────────────────────────────────

    @staticmethod
    def create_download_stream(file_record: File, user):
        """Yield file data as a speed-limited byte-stream generator.

        Enforces the user's download speed limit (bytes/sec).  Tracks consumed
        bytes against the user's traffic quota after each chunk.  Increments
        the file's download_count once the stream is exhausted.
        """
        speed_limit = QuotaService.get_download_speed_limit(user)
        total_sent = 0

        storage = get_storage()
        for chunk in storage.stream(file_record.storage_path, chunk_size=DOWNLOAD_CHUNK_SIZE):
            chunk_start = time.monotonic()
            yield chunk
            chunk_size = len(chunk)
            total_sent += chunk_size

            # Track traffic usage.
            QuotaService.track_download(user, chunk_size)

            # Throttle if a speed limit is configured.
            if speed_limit > 0:
                elapsed = time.monotonic() - chunk_start
                expected = chunk_size / speed_limit
                delay = expected - elapsed
                if delay > 0:
                    time.sleep(delay)

        # Increment download counter after the entire file has been streamed.
        file_record.download_count += 1
        db.session.commit()

    # ── Status transitions ────────────────────────────────────────────────────

    @staticmethod
    def expire_file(file_record: File) -> None:
        """Transition a file from *active* to *expired* and open the redemption window."""
        file_record.status = "expired"
        file_record.redemption_ends_at = utcnow() + timedelta(days=REDEMPTION_GRACE_DAYS)
        db.session.commit()

    @staticmethod
    def delete_file(file_record: File) -> None:
        """Remove the file from storage and mark its DB record as deleted."""
        storage = get_storage()
        storage.delete(file_record.storage_path)

        file_record.status = "deleted"
        file_record.deleted_at = utcnow()
        db.session.commit()

    # ── Admin operations ──────────────────────────────────────────────────────

    @staticmethod
    def force_expire_file(file_record: File) -> None:
        """Admin: force-expire a file regardless of its scheduled expiry time."""
        if file_record.status == "active":
            FileService.expire_file(file_record)

    @staticmethod
    def force_delete_file(file_record: File) -> None:
        """Admin: delete a file regardless of its current status."""
        FileService.delete_file(file_record)

    # ── Internal helpers ──────────────────────────────────────────────────────

    @staticmethod
    def _generate_unique_pickup_code() -> str:
        """Generate a pickup code that is not already in use.

        Raises:
            ValidationError: if MAX_PICKUP_CODE_ATTEMPTS retries are exhausted.
        """
        for _ in range(MAX_PICKUP_CODE_ATTEMPTS):
            code = generate_pickup_code()
            if File.query.filter_by(pickup_code=code).first() is None:
                return code
        raise ValidationError(
            "Could not generate a unique pickup code. Please try again.",
        )
