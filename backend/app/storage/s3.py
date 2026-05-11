"""Amazon S3 (and S3-compatible) storage backend."""

from __future__ import annotations

import os
import tempfile
from typing import Generator

from app.storage.base import StorageBackend
from app.utils.constants import DOWNLOAD_CHUNK_SIZE


class S3Storage(StorageBackend):
    """Stores files as objects in an S3 bucket.

    Object key layout::

        <prefix>/<user_id>/<stored_filename>

    The storage key stored in ``File.storage_path`` is the object key. The
    bucket name is held by this class.
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
        if not bucket:
            raise RuntimeError("AWS_S3_BUCKET is required when STORAGE_BACKEND=s3.")
        if not region:
            raise RuntimeError("AWS_REGION is required when STORAGE_BACKEND=s3.")
        if bool(access_key) != bool(secret_key):
            raise RuntimeError(
                "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be configured together."
            )

        self._bucket = bucket
        self._prefix = prefix.rstrip("/")

        try:
            import boto3
            from boto3.s3.transfer import TransferConfig
        except ImportError as exc:
            raise RuntimeError(
                "boto3 is required for S3 storage. Run: pip install boto3"
            ) from exc

        session = boto3.session.Session()
        kwargs: dict = dict(region_name=region)
        if access_key and secret_key:
            kwargs["aws_access_key_id"] = access_key
            kwargs["aws_secret_access_key"] = secret_key
        if endpoint_url:
            kwargs["endpoint_url"] = endpoint_url

        self._client = session.client("s3", **kwargs)
        self._transfer_config = TransferConfig(
            multipart_threshold=8 * 1024 * 1024,
            multipart_chunksize=8 * 1024 * 1024,
            max_concurrency=4,
            use_threads=True,
        )

    def _object_key(self, user_id: int, stored_filename: str) -> str:
        return f"{self._prefix}/{user_id}/{stored_filename}"

    def save(self, source, user_id: int, stored_filename: str) -> tuple[str, int]:
        key = self._object_key(user_id, stored_filename)

        if hasattr(source, "stream"):
            stream = source.stream
            content_type = getattr(source, "mimetype", None)
        elif hasattr(source, "read"):
            stream = source
            content_type = None
        else:
            raise TypeError(f"Unsupported source type: {type(source)}")

        stream, file_size = self._prepare_stream(stream)

        extra_args = {"ContentType": content_type} if content_type else None
        self._client.upload_fileobj(
            stream,
            self._bucket,
            key,
            ExtraArgs=extra_args,
            Config=self._transfer_config,
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

    @staticmethod
    def _prepare_stream(stream):
        """Return a seekable stream positioned at 0 and its size."""
        try:
            current = stream.tell()
            stream.seek(0, os.SEEK_END)
            size = stream.tell()
            stream.seek(current)
            stream.seek(0)
            return stream, size
        except (AttributeError, OSError):
            spool = tempfile.SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode="w+b")
            total = 0
            while True:
                chunk = stream.read(DOWNLOAD_CHUNK_SIZE)
                if not chunk:
                    break
                spool.write(chunk)
                total += len(chunk)
            spool.seek(0)
            return spool, total
