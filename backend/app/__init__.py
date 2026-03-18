"""Flask application factory."""

import logging
import os

from flask import Flask

from app.api import register_blueprints
from app.extensions import cors, db, jwt, migrate, socketio
from app.services.auth_service import AuthService
from app.utils.errors import register_error_handlers
from config import get_config


def create_app(config_name: str | None = None) -> Flask:
    """Create and configure the Flask application."""
    app = Flask(__name__)
    app.config.from_object(get_config(config_name))

    # Ensure upload folder exists
    upload_folder = app.config.get("UPLOAD_FOLDER", "./uploads")
    os.makedirs(upload_folder, exist_ok=True)

    # Initialize extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    cors.init_app(app, resources={r"/api/*": {"origins": app.config.get("CORS_ORIGINS", "*")}})
    socketio.init_app(app, cors_allowed_origins="*", async_mode="eventlet")

    # Register blueprints
    register_blueprints(app)

    # Register error handlers
    register_error_handlers(app)

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
        if app.config.get("SCHEDULER_ENABLED", False):
            _start_scheduler(app)

    return app


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
