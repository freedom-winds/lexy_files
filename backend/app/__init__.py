"""Flask application factory."""

import logging
import os
import sys

from flask import Flask

from app.api import register_blueprints
from app.extensions import cors, db, jwt, migrate, socketio
from app.services.auth_service import AuthService
from app.utils.errors import register_error_handlers
from config import get_config


def create_app(config_name: str | None = None) -> Flask:
    """Create and configure the Flask application."""
    app = Flask(__name__)
    config_class = get_config(config_name)
    validate_config = getattr(config_class, "validate", None)
    if validate_config is not None:
        validate_config()
    app.config.from_object(config_class)
    _validate_storage_config(app)

    # Ensure upload folder exists
    upload_folder = app.config.get("UPLOAD_FOLDER", "./uploads")
    os.makedirs(upload_folder, exist_ok=True)

    # Initialize extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    cors.init_app(app, resources={r"/api/*": {"origins": app.config.get("CORS_ORIGINS", "*")}})
    socketio.init_app(
        app,
        cors_allowed_origins=app.config.get("SOCKETIO_CORS_ORIGINS", app.config.get("CORS_ORIGINS", "*")),
        async_mode="eventlet",
    )

    # Register blueprints
    register_blueprints(app)

    # Register error handlers
    register_error_handlers(app)

    # Register WebSocket event handlers (must happen after socketio.init_app)
    from app import ws  # noqa: F401 – registers handlers as a side-effect

    # JWT token revocation check
    @jwt.token_in_blocklist_loader
    def check_if_token_revoked(jwt_header, jwt_payload):
        jti = jwt_payload["jti"]
        try:
            return AuthService.is_token_revoked(jti)
        except Exception:
            # If Redis is down, allow tokens through (fail open for availability)
            return False

    # Configure logging
    if not app.debug and not app.testing:
        logging.basicConfig(level=logging.INFO)

    # Database initialization and scheduler setup
    with app.app_context():
        # Import models to ensure they're registered with SQLAlchemy
        from app import models  # noqa: F401

        # Seed default group quotas if database tables exist
        _seed_default_quotas(app)

        # Start cleanup scheduler
        if _should_start_scheduler(app):
            _start_scheduler(app)

    return app


def _should_start_scheduler(app: Flask) -> bool:
    """Return True when the cleanup scheduler should run in this process."""
    if not app.config.get("SCHEDULER_ENABLED", False):
        return False
    if app.testing:
        return False
    if os.environ.get("FLASK_SKIP_SCHEDULER", "").lower() in {"1", "true", "yes"}:
        return False
    # Flask-Migrate imports the app for `flask db ...`; those commands should
    # not start background jobs.
    if "db" in sys.argv[1:3]:
        return False
    return True


def _validate_storage_config(app: Flask) -> None:
    """Fail fast when the selected storage backend is missing required settings."""
    if app.config.get("STORAGE_BACKEND", "local").lower() != "s3":
        return

    required = [
        "AWS_S3_BUCKET",
        "AWS_REGION",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY",
    ]
    missing = [name for name in required if not app.config.get(name)]
    if missing:
        joined = ", ".join(missing)
        raise RuntimeError(f"{joined} must be set when STORAGE_BACKEND=s3.")


def _seed_default_quotas(app: Flask) -> None:
    """Seed the group_quotas table with defaults if empty."""
    try:
        from app.models.quota import DEFAULT_QUOTAS, GroupQuota

        if GroupQuota.query.first() is None:
            for group_name, defaults in DEFAULT_QUOTAS.items():
                gq = GroupQuota(group_name=group_name, **defaults)
                db.session.add(gq)
            db.session.commit()
            app.logger.info("Seeded default group quotas.")
    except Exception:
        # Table may not exist yet (pre-migration). Skip gracefully.
        db.session.rollback()


def _start_scheduler(app: Flask) -> None:
    """Start APScheduler for periodic cleanup tasks."""
    try:
        from apscheduler.schedulers.background import BackgroundScheduler

        from app.services.cleanup_service import CleanupService

        interval_minutes = app.config.get("CLEANUP_INTERVAL_MINUTES", 30)

        def cleanup_job():
            with app.app_context():
                result = CleanupService.run_cleanup()
                app.logger.info(f"Cleanup completed: {result}")

        scheduler = BackgroundScheduler()
        scheduler.add_job(cleanup_job, "interval", minutes=interval_minutes, id="file_cleanup")
        scheduler.start()
        app.logger.info(f"Cleanup scheduler started (every {interval_minutes} min).")
    except Exception as e:
        app.logger.warning(f"Could not start cleanup scheduler: {e}")
