"""General utility helpers."""

import random
import string
from datetime import date, datetime, timezone
from typing import Any

from app.utils.constants import PICKUP_CODE_CHARSET, PICKUP_CODE_LENGTH


def generate_pickup_code(length: int = PICKUP_CODE_LENGTH) -> str:
    """Generate a random pickup code from the unambiguous charset."""
    return "".join(random.choices(PICKUP_CODE_CHARSET, k=length))


def normalize_pickup_code(code: str) -> str:
    """Normalize a pickup code for case-insensitive comparison."""
    return code.upper().strip()


def utcnow() -> datetime:
    """Return the current UTC datetime (timezone-aware)."""
    return datetime.now(timezone.utc)


def get_period_start(period_type: str, reference: date | None = None) -> date:
    """
    Return the start of the current billing period.

    For 'daily' this is today; for 'monthly' this is the first of the month.
    """
    today = reference or date.today()
    if period_type == "monthly":
        return today.replace(day=1)
    return today  # daily


def paginate_query(query, page: int, per_page: int) -> dict[str, Any]:
    """
    Execute a paginated query and return data + pagination metadata.

    Returns a dict with keys: data (list), pagination (dict).
    """
    per_page = min(max(per_page, 1), 200)
    page = max(page, 1)
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)
    return {
        "data": pagination.items,
        "pagination": {
            "page": pagination.page,
            "per_page": pagination.per_page,
            "total": pagination.total,
            "pages": pagination.pages,
        },
    }


def parse_int(value: Any, default: int = 1, minimum: int = 1) -> int:
    """Parse an integer value from a query param, returning the default on failure."""
    try:
        return max(int(value), minimum)
    except (TypeError, ValueError):
        return default


def human_readable_size(size_bytes: int) -> str:
    """Convert bytes to a human-readable string."""
    if size_bytes == 0:
        return "0 B"
    units = ["B", "KB", "MB", "GB", "TB"]
    index = 0
    value = float(size_bytes)
    while value >= 1024 and index < len(units) - 1:
        value /= 1024
        index += 1
    return f"{value:.2f} {units[index]}"
