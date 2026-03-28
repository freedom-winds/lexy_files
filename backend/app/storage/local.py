"""Local filesystem storage backend."""

from __future__ import annotations

import os
from typing import Generator

from app.storage.base import StorageBackend


class LocalStorage(StorageBackend):
    """Stores files on the local filesystem under *upload_folder*.

    Directory layout::

        <upload_folder>/<user_id>/<stored_filename>

    The storage key is the full absolute path to the file.
    """

    def __init__(self, upload_folder: str) -> None:
        self._root = upload_folder

    def save(self, source, user_id: int, stored_filename: str) -> tuple[str, int]:
        user_dir = os.path.join(self._root, str(user_id))
        os.makedirs(user_dir, exist_ok=True)
        storage_key = os.path.join(user_dir, stored_filename)

        if hasattr(source, "save"):
            # Werkzeug FileStorage
            source.save(storage_key)
        else:
            with open(storage_key, "wb") as fh:
                for chunk in iter(lambda: source.read(256 * 1024), b""):
                    fh.write(chunk)

        file_size = os.path.getsize(storage_key)
        return storage_key, file_size

    def stream(self, storage_key: str, chunk_size: int = 256 * 1024) -> Generator[bytes, None, None]:
        with open(storage_key, "rb") as fh:
            while True:
                chunk = fh.read(chunk_size)
                if not chunk:
                    break
                yield chunk

    def delete(self, storage_key: str) -> None:
        try:
            os.remove(storage_key)
        except FileNotFoundError:
            pass
