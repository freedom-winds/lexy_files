"""
Application configuration.
All values can be overridden via environment variables or a .env file.
"""

import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()


class Config:
    # ── Flask core ────────────────────────────────────────────────────────────
    SECRET_KEY: str = os.environ.get("SECRET_KEY", "dev-secret-key-change-in-production")
    DEBUG: bool = False
    TESTING: bool = False

    # ── JWT ───────────────────────────────────────────────────────────────────
    JWT_SECRET_KEY: str = os.environ.get("JWT_SECRET_KEY", "dev-jwt-secret-change-in-production")
    JWT_ACCESS_TOKEN_EXPIRES: timedelta = timedelta(minutes=15)
    JWT_REFRESH_TOKEN_EXPIRES: timedelta = timedelta(days=30)
    JWT_ALGORITHM: str = "HS256"
    JWT_BLACKLIST_ENABLED: bool = True
    JWT_BLACKLIST_TOKEN_CHECKS: list = ["access", "refresh"]

    # ── Database ──────────────────────────────────────────────────────────────
    MYSQL_HOST: str = os.environ.get("MYSQL_HOST", "localhost")
    MYSQL_PORT: int = int(os.environ.get("MYSQL_PORT", "3306"))
    MYSQL_USER: str = os.environ.get("MYSQL_USER", "lexy")
    MYSQL_PASSWORD: str = os.environ.get("MYSQL_PASSWORD", "lexy_password")
    MYSQL_DATABASE: str = os.environ.get("MYSQL_DATABASE", "lexy_files")

    SQLALCHEMY_DATABASE_URI: str = (
        f"mysql+pymysql://{os.environ.get('MYSQL_USER', 'lexy')}"
        f":{os.environ.get('MYSQL_PASSWORD', 'lexy_password')}"
        f"@{os.environ.get('MYSQL_HOST', 'localhost')}"
        f":{os.environ.get('MYSQL_PORT', '3306')}"
        f"/{os.environ.get('MYSQL_DATABASE', 'lexy_files')}"
        "?charset=utf8mb4"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS: bool = False
    SQLALCHEMY_ENGINE_OPTIONS: dict = {
        "pool_recycle": 300,
        "pool_pre_ping": True,
        "pool_size": 10,
        "max_overflow": 20,
    }

    # ── Redis ─────────────────────────────────────────────────────────────────
    REDIS_URL: str = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

    # ── File storage ──────────────────────────────────────────────────────────
    UPLOAD_FOLDER: str = os.environ.get("UPLOAD_FOLDER", "./uploads")
    MAX_CONTENT_LENGTH: int = int(os.environ.get("MAX_CONTENT_LENGTH", str(5 * 1024 ** 3)))  # 5 GB

    # ── CORS ──────────────────────────────────────────────────────────────────
    CORS_ORIGINS: list = os.environ.get("CORS_ORIGINS", "*").split(",")

    # ── Scheduler ─────────────────────────────────────────────────────────────
    SCHEDULER_ENABLED: bool = os.environ.get("SCHEDULER_ENABLED", "true").lower() == "true"
    CLEANUP_INTERVAL_MINUTES: int = int(os.environ.get("CLEANUP_INTERVAL_MINUTES", "30"))

    # ── Rate limiting ─────────────────────────────────────────────────────────
    RATE_LIMIT_DEFAULT: int = 200          # requests per minute per IP
    RATE_LIMIT_AUTH: int = 10             # auth endpoints per minute per IP
    RATE_LIMIT_UPLOAD: int = 20           # uploads per minute per user


class DevelopmentConfig(Config):
    DEBUG: bool = True


class ProductionConfig(Config):
    DEBUG: bool = False
    SQLALCHEMY_ENGINE_OPTIONS: dict = {
        "pool_recycle": 300,
        "pool_pre_ping": True,
        "pool_size": 20,
        "max_overflow": 40,
    }


class TestingConfig(Config):
    TESTING: bool = True
    DEBUG: bool = True
    # Use SQLite in-memory for tests — no real DB needed
    SQLALCHEMY_DATABASE_URI: str = "sqlite:///:memory:"
    SQLALCHEMY_ENGINE_OPTIONS: dict = {}
    JWT_ACCESS_TOKEN_EXPIRES: timedelta = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES: timedelta = timedelta(hours=2)
    UPLOAD_FOLDER: str = "/tmp/lexy_test_uploads"
    SCHEDULER_ENABLED: bool = False
    # Use fakeredis or a real Redis (tests stub it out)
    REDIS_URL: str = "redis://localhost:6379/1"


config_map = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
    "default": DevelopmentConfig,
}


def get_config(env: str | None = None) -> type[Config]:
    env = env or os.environ.get("FLASK_ENV", "default")
    return config_map.get(env, DevelopmentConfig)
