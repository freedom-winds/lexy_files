"""Abstract storage backend interface."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Generator


class StorageBackend(ABC):
    """Common interface for all storage backends.

    All paths/keys passed to these methods are *storage keys* — opaque
    strings whose format is determined by the backend.  For local storage
    a key is a relative filesystem path; for S3 a key is an S3 object key.
    The ``File.storage_path`` column stores this value unchanged.
    """

    @abstractmethod
    def save(self, source, user_id: int, stored_filename: str) -> tuple[str, int]:
        """Persist data from *source* and return ``(storage_key, file_size)``.

        Args:
            source:          A file-like object with a ``read()`` method, or
                             a Werkzeug ``FileStorage`` instance.
            user_id:         Owner's user ID — used to namespace the key.
            stored_filename: UUID-based filename (already sanitised by the caller).

        Returns:
            A ``(storage_key, file_size_bytes)`` tuple.
            ``storage_key`` should be passed back to :meth:`stream` and
            :meth:`delete`.
        """

    @abstractmethod
    def stream(self, storage_key: str, chunk_size: int = 256 * 1024) -> Generator[bytes, None, None]:
        """Yield the stored file's content as a sequence of byte chunks.

        Args:
            storage_key: The key returned by :meth:`save`.
            chunk_size:  Maximum bytes per chunk.
        """

    @abstractmethod
    def delete(self, storage_key: str) -> None:
        """Remove the stored object.

        Implementations must not raise if the object is already absent.
        """
