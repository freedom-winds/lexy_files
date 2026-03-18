"""
Centralised error handling.

All API errors use the standard envelope:
  { "error": { "code": "...", "message": "...", "details": {} } }
"""

from flask import Flask, jsonify


class AppError(Exception):
    """Base class for all application-level errors."""

    http_status: int = 500
    error_code: str = "SERVER_ERROR"

    def __init__(self, message: str = "An unexpected error occurred.", details: dict | None = None):
        super().__init__(message)
        self.message = message
        self.details = details or {}

    def to_response(self):
        body = {
            "error": {
                "code": self.error_code,
                "message": self.message,
                "details": self.details,
            }
        }
        return jsonify(body), self.http_status


# ── Concrete error types ──────────────────────────────────────────────────────

class ValidationError(AppError):
    http_status = 400
    error_code = "VALIDATION_ERROR"


class AuthenticationError(AppError):
    http_status = 401
    error_code = "UNAUTHORIZED"


class ForbiddenError(AppError):
    http_status = 403
    error_code = "FORBIDDEN"


class BannedError(AppError):
    http_status = 403
    error_code = "FORBIDDEN"

    def __init__(self, message: str = "Your account has been banned."):
        super().__init__(message)


class NotFoundError(AppError):
    http_status = 404
    error_code = "NOT_FOUND"


class ConflictError(AppError):
    http_status = 409
    error_code = "CONFLICT"


class FileTooLargeError(AppError):
    http_status = 413
    error_code = "FILE_TOO_LARGE"


class QuotaExceededError(AppError):
    http_status = 429
    error_code = "QUOTA_EXCEEDED"


class RateLimitedError(AppError):
    http_status = 429
    error_code = "RATE_LIMITED"


class StorageFullError(AppError):
    http_status = 409
    error_code = "STORAGE_FULL"


class FileExpiredError(AppError):
    http_status = 410
    error_code = "FILE_EXPIRED"


class TransferError(AppError):
    http_status = 400
    error_code = "TRANSFER_FAILED"


class DeviceOfflineError(AppError):
    http_status = 409
    error_code = "DEVICE_OFFLINE"


# ── Error-response helpers ────────────────────────────────────────────────────

def error_response(code: str, message: str, details: dict | None = None, status: int = 400):
    """Build a generic error response without raising an exception."""
    body = {
        "error": {
            "code": code,
            "message": message,
            "details": details or {},
        }
    }
    return jsonify(body), status


# ── Flask error handler registration ─────────────────────────────────────────

def register_error_handlers(app: Flask) -> None:
    """Attach error handlers to the Flask app."""

    @app.errorhandler(AppError)
    def handle_app_error(exc: AppError):
        return exc.to_response()

    @app.errorhandler(400)
    def bad_request(exc):
        return error_response("VALIDATION_ERROR", str(exc), status=400)

    @app.errorhandler(401)
    def unauthorized(exc):
        return error_response("UNAUTHORIZED", "Authentication required.", status=401)

    @app.errorhandler(403)
    def forbidden(exc):
        return error_response("FORBIDDEN", "You do not have permission to perform this action.", status=403)

    @app.errorhandler(404)
    def not_found(exc):
        return error_response("NOT_FOUND", "The requested resource was not found.", status=404)

    @app.errorhandler(405)
    def method_not_allowed(exc):
        return error_response("METHOD_NOT_ALLOWED", "HTTP method not allowed.", status=405)

    @app.errorhandler(409)
    def conflict(exc):
        return error_response("CONFLICT", str(exc), status=409)

    @app.errorhandler(413)
    def payload_too_large(exc):
        return error_response("FILE_TOO_LARGE", "The uploaded file exceeds the maximum allowed size.", status=413)

    @app.errorhandler(429)
    def too_many_requests(exc):
        return error_response("RATE_LIMITED", "Too many requests. Please try again later.", status=429)

    @app.errorhandler(500)
    def server_error(exc):
        app.logger.exception("Unhandled server error")
        return error_response("SERVER_ERROR", "An internal server error occurred.", status=500)
