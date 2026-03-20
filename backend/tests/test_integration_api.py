"""Integration tests exercising the full API flow through HTTP endpoints.

Flow: register → login → /me → upload file → pickup by code → download →
      list files → delete file → verify deletion.
"""

import io
import os
import tempfile
from unittest.mock import patch

import fakeredis
import pytest

from app import create_app
from app.extensions import db as _db
from app.services import auth_service as _auth_module


# ---------------------------------------------------------------------------
# Fixtures – full app with all blueprints
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def integration_app():
    """Create a full Flask application (with all blueprints) for integration tests."""
    # Patch socketio async_mode to 'threading' to avoid eventlet dependency in tests
    with patch("app.extensions.socketio") as mock_sio:
        mock_sio.init_app = lambda *a, **kw: None

        app = create_app("testing")
        app.config["UPLOAD_FOLDER"] = tempfile.mkdtemp(prefix="lexy_integ_")

        with app.app_context():
            _db.create_all()
            yield app
            _db.drop_all()


@pytest.fixture(autouse=True)
def _clean_integration_db(integration_app):
    """Truncate all tables between tests."""
    with integration_app.app_context():
        yield
        _db.session.rollback()
        for table in reversed(_db.metadata.sorted_tables):
            _db.session.execute(table.delete())
        _db.session.commit()


@pytest.fixture()
def client(integration_app):
    return integration_app.test_client()


@pytest.fixture(autouse=True)
def _stub_redis(monkeypatch):
    """Replace Redis with fakeredis so logout/revocation works without a real Redis."""
    server = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(
        _auth_module.AuthService, "get_redis", staticmethod(lambda: server)
    )
    return server


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Full happy-path integration test
# ---------------------------------------------------------------------------

class TestFullApiFlow:
    """End-to-end API flow exercising the core product journey."""

    def test_register_login_upload_pickup_download_delete(self, client):
        # ── 1. Register ──────────────────────────────────────────────────
        resp = client.post("/api/v1/auth/register", json={
            "username": "alice",
            "email": "alice@example.com",
            "password": "Str0ngP@ss!",
        })
        assert resp.status_code == 201, resp.get_json()
        data = resp.get_json()
        assert "user" in data
        assert "tokens" in data
        assert data["user"]["username"] == "alice"

        access_token = data["tokens"]["access_token"]
        refresh_token = data["tokens"]["refresh_token"]
        user_id = data["user"]["id"]

        # ── 2. Login with same credentials ───────────────────────────────
        resp = client.post("/api/v1/auth/login", json={
            "username": "alice",
            "password": "Str0ngP@ss!",
        })
        assert resp.status_code == 200, resp.get_json()
        login_data = resp.get_json()
        access_token = login_data["tokens"]["access_token"]  # use fresh token

        # ── 3. /me endpoint ──────────────────────────────────────────────
        resp = client.get("/api/v1/auth/me", headers=auth_header(access_token))
        assert resp.status_code == 200
        me_data = resp.get_json()
        assert me_data["user"]["id"] == user_id
        assert me_data["user"]["username"] == "alice"

        # ── 4. Upload a file ─────────────────────────────────────────────
        file_content = b"Hello, Lexy Files! This is a test file."
        resp = client.post(
            "/api/v1/files/upload",
            headers=auth_header(access_token),
            data={"file": (io.BytesIO(file_content), "hello.txt")},
            content_type="multipart/form-data",
        )
        assert resp.status_code == 201, resp.get_json()
        upload_data = resp.get_json()
        assert "pickup_code" in upload_data
        assert "download_url" in upload_data
        assert upload_data["original_filename"] == "hello.txt"
        assert upload_data["file_size"] == len(file_content)
        assert upload_data["status"] == "active"

        file_id = upload_data["id"]
        pickup_code = upload_data["pickup_code"]

        # ── 5. Retrieve file info by pickup code (public, no auth) ───────
        resp = client.get(f"/api/v1/files/pickup/{pickup_code}")
        assert resp.status_code == 200
        pickup_data = resp.get_json()
        assert pickup_data["original_filename"] == "hello.txt"
        assert pickup_data["file_size"] == len(file_content)
        assert pickup_data["pickup_code"] == pickup_code

        # Case-insensitive lookup
        resp = client.get(f"/api/v1/files/pickup/{pickup_code.lower()}")
        assert resp.status_code == 200

        # ── 6. Download the file ─────────────────────────────────────────
        resp = client.get(
            f"/api/v1/files/download/{file_id}",
            headers=auth_header(access_token),
        )
        assert resp.status_code == 200
        assert resp.data == file_content
        assert "hello.txt" in resp.headers.get("Content-Disposition", "")

        # ── 7. List user's files ─────────────────────────────────────────
        resp = client.get("/api/v1/files/", headers=auth_header(access_token))
        assert resp.status_code == 200
        list_data = resp.get_json()
        assert "data" in list_data
        assert "pagination" in list_data
        assert len(list_data["data"]) == 1
        assert list_data["data"][0]["id"] == file_id
        assert list_data["pagination"]["total"] == 1

        # ── 8. Delete the file ───────────────────────────────────────────
        resp = client.delete(
            f"/api/v1/files/{file_id}",
            headers=auth_header(access_token),
        )
        assert resp.status_code == 204

        # ── 9. Verify file is gone from listing ──────────────────────────
        resp = client.get("/api/v1/files/", headers=auth_header(access_token))
        assert resp.status_code == 200
        assert len(resp.get_json()["data"]) == 0

        # Pickup code should now return 404 (deleted file)
        resp = client.get(f"/api/v1/files/pickup/{pickup_code}")
        assert resp.status_code in (404, 410)  # NotFound or FileExpired


class TestAuthEdgeCases:
    """Test auth error paths via the API."""

    def test_register_duplicate_username(self, client):
        client.post("/api/v1/auth/register", json={
            "username": "bob",
            "email": "bob@example.com",
            "password": "Password1!",
        })
        resp = client.post("/api/v1/auth/register", json={
            "username": "bob",
            "email": "bob2@example.com",
            "password": "Password1!",
        })
        assert resp.status_code == 409
        assert resp.get_json()["error"]["code"] == "CONFLICT"

    def test_register_duplicate_email(self, client):
        client.post("/api/v1/auth/register", json={
            "username": "carol",
            "email": "carol@example.com",
            "password": "Password1!",
        })
        resp = client.post("/api/v1/auth/register", json={
            "username": "carol2",
            "email": "carol@example.com",
            "password": "Password1!",
        })
        assert resp.status_code == 409

    def test_login_wrong_password(self, client):
        client.post("/api/v1/auth/register", json={
            "username": "dave",
            "email": "dave@example.com",
            "password": "Password1!",
        })
        resp = client.post("/api/v1/auth/login", json={
            "username": "dave",
            "password": "WrongPassword!",
        })
        assert resp.status_code == 401
        assert resp.get_json()["error"]["code"] == "UNAUTHORIZED"

    def test_login_nonexistent_user(self, client):
        resp = client.post("/api/v1/auth/login", json={
            "username": "nobody",
            "password": "nope",
        })
        assert resp.status_code == 401

    def test_access_protected_route_without_token(self, client):
        resp = client.get("/api/v1/auth/me")
        assert resp.status_code == 401

    def test_refresh_token_flow(self, client):
        # Register
        resp = client.post("/api/v1/auth/register", json={
            "username": "eve",
            "email": "eve@example.com",
            "password": "Password1!",
        })
        refresh_token = resp.get_json()["tokens"]["refresh_token"]

        # Use refresh token to get new access token
        resp = client.post(
            "/api/v1/auth/refresh",
            headers=auth_header(refresh_token),
        )
        assert resp.status_code == 200
        assert "access_token" in resp.get_json()

        # New access token should work
        new_token = resp.get_json()["access_token"]
        resp = client.get("/api/v1/auth/me", headers=auth_header(new_token))
        assert resp.status_code == 200
        assert resp.get_json()["user"]["username"] == "eve"

    def test_register_missing_fields(self, client):
        resp = client.post("/api/v1/auth/register", json={
            "username": "partial",
        })
        assert resp.status_code == 400
        assert resp.get_json()["error"]["code"] == "VALIDATION_ERROR"


class TestFileEdgeCases:
    """Test file operation error paths."""

    def _register_and_get_token(self, client, username="fileuser"):
        resp = client.post("/api/v1/auth/register", json={
            "username": username,
            "email": f"{username}@example.com",
            "password": "Password1!",
        })
        return resp.get_json()["tokens"]["access_token"]

    def test_upload_without_file(self, client):
        token = self._register_and_get_token(client)
        resp = client.post(
            "/api/v1/files/upload",
            headers=auth_header(token),
            data={},
            content_type="multipart/form-data",
        )
        assert resp.status_code == 400

    def test_download_nonexistent_file(self, client):
        token = self._register_and_get_token(client)
        resp = client.get(
            "/api/v1/files/download/99999",
            headers=auth_header(token),
        )
        assert resp.status_code == 404

    def test_delete_other_users_file(self, client):
        # User A uploads a file
        token_a = self._register_and_get_token(client, "userA")
        resp = client.post(
            "/api/v1/files/upload",
            headers=auth_header(token_a),
            data={"file": (io.BytesIO(b"owned by A"), "a.txt")},
            content_type="multipart/form-data",
        )
        file_id = resp.get_json()["id"]

        # User B tries to delete it
        token_b = self._register_and_get_token(client, "userB")
        resp = client.delete(
            f"/api/v1/files/{file_id}",
            headers=auth_header(token_b),
        )
        assert resp.status_code == 403

    def test_pickup_nonexistent_code(self, client):
        resp = client.get("/api/v1/files/pickup/ZZZZZZ")
        assert resp.status_code == 404

    def test_multiple_file_upload_and_listing(self, client):
        token = self._register_and_get_token(client, "multiuser")

        # Upload 3 files
        for i in range(3):
            resp = client.post(
                "/api/v1/files/upload",
                headers=auth_header(token),
                data={"file": (io.BytesIO(f"file {i}".encode()), f"file_{i}.txt")},
                content_type="multipart/form-data",
            )
            assert resp.status_code == 201

        # List should show 3
        resp = client.get("/api/v1/files/", headers=auth_header(token))
        assert resp.status_code == 200
        assert len(resp.get_json()["data"]) == 3
        assert resp.get_json()["pagination"]["total"] == 3


class TestAnonymousFlow:
    """Test anonymous user flow via the API."""

    def test_anonymous_auth_and_upload(self, client):
        # Create anonymous session
        resp = client.post("/api/v1/auth/anonymous", json={
            "device_id": "test-device-001",
            "fingerprint": "fp-integration-test",
        })
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["user"]["is_anonymous"] is True
        token = data["tokens"]["access_token"]

        # Anonymous user can upload
        resp = client.post(
            "/api/v1/files/upload",
            headers=auth_header(token),
            data={"file": (io.BytesIO(b"anon file"), "anon.txt")},
            content_type="multipart/form-data",
        )
        assert resp.status_code == 201
        assert resp.get_json()["pickup_code"] is not None

    def test_anonymous_requires_identifier(self, client):
        resp = client.post("/api/v1/auth/anonymous", json={})
        assert resp.status_code == 400
