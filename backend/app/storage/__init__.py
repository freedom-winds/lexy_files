"""Storage backend factory.

Select the active backend via the ``STORAGE_BACKEND`` config key:
  - ``"local"``  (default) — local filesystem under UPLOAD_FOLDER
  - ``"s3"``     — Amazon S3 (or any S3-compatible service)

Usage anywhere in the app::

    from app.storage import get_storage
    storage = get_storage()          # returns the configured backend
    storage.save(stream, key)
    storage.stream(key)
    storage.delete(key)
"""

from __future__ import annotations

from flask import current_app

from app.storage.base import StorageBackend
from app.storage.local import LocalStorage
from app.storage.s3 import S3Storage


def get_storage() -> StorageBackend:
    """Return the configured storage backend instance.

    Instantiated lazily on each call; backends are cheap to construct.
    For performance-critical code, cache the result at the call site.
    """
    backend = current_app.config.get("STORAGE_BACKEND", "local").lower()
    if backend == "s3":
        return S3Storage(
            bucket=current_app.config["AWS_S3_BUCKET"],
            region=current_app.config.get("AWS_REGION", "us-east-1"),
            access_key=current_app.config.get("AWS_ACCESS_KEY_ID"),
            secret_key=current_app.config.get("AWS_SECRET_ACCESS_KEY"),
            endpoint_url=current_app.config.get("AWS_S3_ENDPOINT_URL"),
            prefix=current_app.config.get("AWS_S3_PREFIX", "uploads"),
        )
    return LocalStorage(
        upload_folder=current_app.config.get("UPLOAD_FOLDER", "./uploads"),
    )
