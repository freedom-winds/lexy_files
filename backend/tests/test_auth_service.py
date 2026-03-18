"""Unit tests for AuthService."""

import pytest
from sqlalchemy import or_

from app.extensions import db
from app.models.user import User
from app.services.auth_service import AuthService
from app.utils.errors import AuthenticationError, BannedError, ConflictError


# ---------------------------------------------------------------------------
# register_user
# ---------------------------------------------------------------------------

class TestRegisterUser:
    def test_creates_user_with_hashed_password(self, app):
        with app.app_context():
            user = AuthService.register_user("alice", "alice@example.com", "secret123")
            assert user.id is not None
            assert user.username == "alice"
            assert user.email == "alice@example.com"
            assert user.user_group == "normal"
            assert not user.is_anonymous
            assert user.check_password("secret123")
            assert not user.check_password("wrong")

    def test_raises_conflict_on_duplicate_username(self, app):
        with app.app_context():
            AuthService.register_user("bob", "bob@example.com", "pass")
            with pytest.raises(ConflictError, match="bob"):
                AuthService.register_user("bob", "bob2@example.com", "pass")

    def test_raises_conflict_on_duplicate_email(self, app):
        with app.app_context():
            AuthService.register_user("carol", "carol@example.com", "pass")
            with pytest.raises(ConflictError, match="carol@example.com"):
                AuthService.register_user("carol2", "carol@example.com", "pass")

    def test_persists_to_database(self, app):
        with app.app_context():
            AuthService.register_user("dave", "dave@example.com", "pass")
            fetched = User.query.filter_by(username="dave").first()
            assert fetched is not None


# ---------------------------------------------------------------------------
# authenticate
# ---------------------------------------------------------------------------

class TestAuthenticate:
    def test_returns_user_on_valid_credentials(self, app, normal_user):
        with app.app_context():
            user = AuthService.authenticate("testuser", "Password1!")
            assert user.id == normal_user.id

    def test_raises_on_wrong_password(self, app, normal_user):
        with app.app_context():
            with pytest.raises(AuthenticationError):
                AuthService.authenticate("testuser", "wrong")

    def test_raises_on_unknown_username(self, app):
        with app.app_context():
            with pytest.raises(AuthenticationError):
                AuthService.authenticate("nobody", "pass")

    def test_raises_banned_error_for_banned_user(self, app, normal_user):
        with app.app_context():
            u = db.session.get(User, normal_user.id)
            u.is_banned = True
            db.session.commit()
            with pytest.raises(BannedError):
                AuthService.authenticate("testuser", "Password1!")


# ---------------------------------------------------------------------------
# find_or_create_anonymous
# ---------------------------------------------------------------------------

class TestFindOrCreateAnonymous:
    def test_creates_new_anonymous_user(self, app):
        with app.app_context():
            user = AuthService.find_or_create_anonymous("10.0.0.1", "fp-xyz")
            assert user.id is not None
            assert user.is_anonymous
            assert user.user_group == "anonymous"
            assert user.ip_address == "10.0.0.1"
            assert user.device_fingerprint == "fp-xyz"

    def test_finds_existing_user_by_ip(self, app, anon_user):
        with app.app_context():
            found = AuthService.find_or_create_anonymous("192.168.1.1", "fp-different")
            assert found.id == anon_user.id

    def test_finds_existing_user_by_fingerprint(self, app, anon_user):
        with app.app_context():
            found = AuthService.find_or_create_anonymous("9.9.9.9", "fp-abc123")
            assert found.id == anon_user.id

    def test_updates_stale_identifiers(self, app, anon_user):
        with app.app_context():
            # Match on fingerprint but IP has changed.
            found = AuthService.find_or_create_anonymous("10.20.30.40", "fp-abc123")
            assert found.id == anon_user.id
            refreshed = db.session.get(User, anon_user.id)
            assert refreshed.ip_address == "10.20.30.40"

    def test_creates_distinct_user_when_no_match(self, app, anon_user):
        with app.app_context():
            new_user = AuthService.find_or_create_anonymous("5.5.5.5", "fp-brand-new")
            assert new_user.id != anon_user.id


# ---------------------------------------------------------------------------
# generate_tokens
# ---------------------------------------------------------------------------

class TestGenerateTokens:
    def test_returns_both_token_keys(self, app, normal_user):
        with app.app_context():
            tokens = AuthService.generate_tokens(normal_user)
            assert "access_token" in tokens
            assert "refresh_token" in tokens

    def test_tokens_are_non_empty_strings(self, app, normal_user):
        with app.app_context():
            tokens = AuthService.generate_tokens(normal_user)
            assert isinstance(tokens["access_token"], str) and tokens["access_token"]
            assert isinstance(tokens["refresh_token"], str) and tokens["refresh_token"]


# ---------------------------------------------------------------------------
# revoke_token / is_token_revoked
# ---------------------------------------------------------------------------

class TestTokenRevocation:
    def test_revoke_and_check(self, app, fake_redis):
        with app.app_context():
            AuthService.revoke_token("test-jti-001", expires_in=3600)
            assert AuthService.is_token_revoked("test-jti-001") is True

    def test_unknown_jti_not_revoked(self, app, fake_redis):
        with app.app_context():
            assert AuthService.is_token_revoked("unknown-jti") is False

    def test_revoked_token_key_uses_prefix(self, app, fake_redis):
        with app.app_context():
            from app.utils.constants import REDIS_JWT_BLACKLIST_PREFIX
            AuthService.revoke_token("jti-prefix-check", expires_in=60)
            assert fake_redis.exists(REDIS_JWT_BLACKLIST_PREFIX + "jti-prefix-check") == 1

    def test_revoke_sets_ttl(self, app, fake_redis):
        with app.app_context():
            from app.utils.constants import REDIS_JWT_BLACKLIST_PREFIX
            AuthService.revoke_token("jti-ttl-check", expires_in=120)
            ttl = fake_redis.ttl(REDIS_JWT_BLACKLIST_PREFIX + "jti-ttl-check")
            assert 0 < ttl <= 120
