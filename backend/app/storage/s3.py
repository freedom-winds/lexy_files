"""Amazon S3 (and S3-compatible) storage backend."""

from __future__ import annotations

import io
from typing import Generator

from app.storage.base import StorageBackend


class S3Storage(StorageBackend):
    """Stores files as objects in an S3 bucket.

    Object key layout::

        <prefix>/<user_id>/<stored_filename>

    e.g. ``uploads/42/a1b2c3d4.pdf``

    The storage key stored in ``File.storage_path`` is this object key.
    The bucket name is NOT embedded in the key — it is held by this class.

    Compatible with any S3-compatible service (MinIO, Cloudflare R2,
    Backblaze B2, DigitalOcean Spaces, etc.) by setting ``endpoint_url``.

    Required pip dependency: ``boto3``
    """

    def __init__(
        self,
        bucket: str,
        region: str = "us-east-1",
        access_key: str | None = None,
        secret_key: str | None = None,
        endpoint_url: str | None = None,
        prefix: str = "uploads",
    ) -> None:
        self._bucket = bucket
        self._prefix = prefix.rstrip("/")

        # Import lazily so boto3 is only required when S3 is actually used.
        try:
            import boto3
        except ImportError as exc:
            raise RuntimeError(
                "boto3 is required for S3 storage. "
                "Run: pip install boto3"
            ) from exc

        session = boto3.session.Session()
        kwargs: dict = dict(region_name=region)
        if access_key and secret_key:
            kwargs["aws_access_key_id"] = access_key
            kwargs["aws_secret_access_key"] = secret_key
        if endpoint_url:
            kwargs["endpoint_url"] = endpoint_url

        self._client = session.client("s3", **kwargs)

    def _object_key(self, user_id: int, stored_filename: str) -> str:
        return f"{self._prefix}/{user_id}/{stored_filename}"

    def save(self, source, user_id: int, stored_filename: str) -> tuple[str, int]:
        key = self._object_key(user_id, stored_filename)

        if hasattr(source, "stream"):
            # Werkzeug FileStorage — read into memory buffer then upload.
            # For large files, consider switching to multipart upload.
            data = source.stream.read()
        elif hasattr(source, "read"):
            data = source.read()
        else:
            raise TypeError(f"Unsupported source type: {type(source)}")

        file_size = len(data)
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=data,
            ContentLength=file_size,
        )
        return key, file_size

    def stream(self, storage_key: str, chunk_size: int = 256 * 1024) -> Generator[bytes, None, None]:
        response = self._client.get_object(Bucket=self._bucket, Key=storage_key)
        body = response["Body"]
        while True:
            chunk = body.read(chunk_size)
            if not chunk:
                break
            yield chunk

    def delete(self, storage_key: str) -> None:
        try:
            self._client.delete_object(Bucket=self._bucket, Key=storage_key)
        except Exception:
            # Best-effort deletion; do not crash if the object is already gone.
            pass
