"""Shared test fixtures for the Lexy Files backend test suite."""

import os
import tempfile

import fakeredis
import pytest

from app.extensions import db as _db
from app.models.user import User
from app.models.file import File
from app.models.quota import GroupQuota, TrafficUsage


# ---------------------------------------------------------------------------
# App factory
# ---------------------------------------------------------------------------

def create_test_app():
    """Create a minimal Flask app suitable for unit tests."""
    from flask import Flask
    from flask_jwt_extended import JWTManager
    from config import TestingConfig

    app = Flask(__name__)
    app.config.from_object(TestingConfig)

    # Override UPLOAD_FOLDER to a fresh temp dir per test run.
    app.config["UPLOAD_FOLDER"] = tempfile.mkdtemp(prefix="lexy_test_")

    _db.init_app(app)
    JWTManager(app)

    return app


@pytest.fixture(scope="session")
def app():
    """Session-scoped Flask application."""
    application = create_test_app()
    with application.app_context():
        _db.create_all()
        yield application
        _db.drop_all()


@pytest.fixture(autouse=True)
def clean_db(app):
    """Roll back every test's DB changes to keep tests independent."""
    with app.app_context():
        yield
        _db.session.rollback()
        # Truncate every table that tests might populate.
        for table in reversed(_db.metadata.sorted_tables):
            _db.session.execute(table.delete())
        _db.session.commit()


@pytest.fixture()
def client(app):
    return app.test_client()


# ---------------------------------------------------------------------------
# Redis stub
# ---------------------------------------------------------------------------

@pytest.fixture()
def fake_redis(monkeypatch):
    """Replace AuthService.get_redis() with an in-process fakeredis server."""
    import fakeredis
    from app.services import auth_service as _auth_module

    server = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(_auth_module.AuthService, "get_redis", staticmethod(lambda: server))
    return server


# ---------------------------------------------------------------------------
# Common model factories
# ---------------------------------------------------------------------------

@pytest.fixture()
def normal_user(app):
    with app.app_context():
        u = User(username="testuser", email="test@example.com", user_group="normal", is_anonymous=False)
        u.set_password("Password1!")
        _db.session.add(u)
        _db.session.commit()
        # Re-query to ensure the object is attached to the current session.
        return _db.session.get(User, u.id)


@pytest.fixture()
def anon_user(app):
    with app.app_context():
        u = User(
            is_anonymous=True,
            user_group="anonymous",
            ip_address="192.168.1.1",
            device_fingerprint="fp-abc123",
        )
        _db.session.add(u)
        _db.session.commit()
        return _db.session.get(User, u.id)


@pytest.fixture()
def upload_folder(app):
    """Return the configured upload folder path."""
    return app.config["UPLOAD_FOLDER"]
