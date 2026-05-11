"""File upload, retrieval, listing, and download endpoints."""

from urllib.parse import quote

from flask import Blueprint, Response, jsonify, request, stream_with_context
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models.file import File
from app.models.user import User
from app.services.auth_service import AuthService
from app.services.file_service import FileService
from app.services.quota_service import QuotaService
from app.utils.errors import (
    AuthenticationError,
    FileExpiredError,
    ForbiddenError,
    NotFoundError,
    ValidationError,
)
from app.utils.helpers import parse_int, paginate_query

files_bp = Blueprint("files", __name__)


@files_bp.route("/upload", methods=["POST"])
@jwt_required()
def upload():
    """Upload a file for the current user.

    Expects multipart/form-data with field 'file'.
    Returns: file metadata including pickup_code and download_url, status 201.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    if "file" not in request.files:
        raise ValidationError("No file part in the request.")

    file_storage = request.files["file"]
    if not file_storage.filename:
        raise ValidationError("No filename provided.")

    # Peek at the content length to perform quota check before streaming
    file_size = request.content_length or 0

    QuotaService.check_upload_allowed(user, file_size)

    file_record = FileService.save_uploaded_file(file_storage, user)

    result = file_record.to_dict()
    result["download_url"] = f"/api/v1/files/download/{file_record.id}"

    return jsonify(result), 201


@files_bp.route("/pickup/<string:code>", methods=["GET"])
def pickup_info(code: str):
    """Retrieve file metadata by pickup code (public, no auth required).

    Returns file metadata without the storage_path field.
    """
    file_record = FileService.get_file_by_pickup_code(code)

    if not file_record.is_accessible():
        if file_record.status == "expired":
            raise FileExpiredError("This file has expired.")
        if file_record.status == "redemption":
            raise FileExpiredError(
                "This file has expired but may still be redeemable by its owner."
            )
        raise NotFoundError("File not found or no longer available.")

    return jsonify(file_record.to_dict()), 200


@files_bp.route("/download/<int:file_id>", methods=["GET"])
@jwt_required(optional=True)
def download(file_id: int):
    """Stream a file download by file ID.

    Authentication is optional. Unauthenticated requests are subject to
    anonymous quota and speed limits.

    Returns: streaming file response with appropriate headers.
    """
    identity = get_jwt_identity()

    if identity is not None:
        user = db.session.get(User, int(identity))
        if user is None:
            # Identity present but user deleted — treat as anonymous
            user = None
    else:
        user = None

    # Resolve anonymous user for quota tracking when not authenticated
    if user is None:
        ip_address = request.remote_addr or "0.0.0.0"
        fingerprint = request.headers.get("X-Device-Fingerprint", ip_address)
        user = AuthService.find_or_create_anonymous(ip_address, fingerprint)

    file_record = db.session.get(File, file_id)
    if file_record is None:
        raise NotFoundError("File not found.")

    if not file_record.is_accessible():
        if file_record.status in ("expired", "redemption"):
            raise FileExpiredError("This file has expired.")
        raise NotFoundError("File not found or no longer available.")

    QuotaService.check_download_allowed(user)

    generator = FileService.create_download_stream(file_record, user)

    filename_encoded = quote(file_record.original_filename)
    content_disposition = (
        f"attachment; filename=\"{file_record.original_filename}\"; "
        f"filename*=UTF-8''{filename_encoded}"
    )

    headers = {
        "Content-Disposition": content_disposition,
        "Content-Length": str(file_record.file_size),
        "X-Pickup-Code": file_record.pickup_code or "",
    }

    mime_type = file_record.mime_type or "application/octet-stream"

    return Response(
        stream_with_context(generator),
        status=200,
        mimetype=mime_type,
        headers=headers,
        direct_passthrough=False,
    )


@files_bp.route("/", methods=["GET"])
@jwt_required()
def list_files():
    """List files owned by the current user (paginated).

    Query params: page, per_page
    Returns: {data: [...], pagination: {...}}
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    page = parse_int(request.args.get("page"), default=1, minimum=1)
    per_page = parse_int(request.args.get("per_page"), default=20, minimum=1)

    query = (
        File.query.filter_by(user_id=user.id)
        .filter(File.status != "deleted")
        .order_by(File.created_at.desc())
    )

    result = paginate_query(query, page, per_page)
    result["data"] = [f.to_dict() for f in result["data"]]

    return jsonify(result), 200


@files_bp.route("/<int:file_id>", methods=["DELETE"])
@jwt_required()
def delete_file(file_id: int):
    """Delete a file owned by the current user.

    Returns: 204 No Content on success.
    """
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity))
    if user is None:
        raise AuthenticationError("User not found.")

    file_record = db.session.get(File, file_id)
    if file_record is None:
        raise NotFoundError("File not found.")

    if file_record.user_id != user.id:
        raise ForbiddenError("You do not have permission to delete this file.")

    FileService.delete_file(file_record)

    return "", 204
