"""Application-wide constants."""

# Pickup code character set — excludes ambiguous chars: 0, O, 1, I, L
PICKUP_CODE_CHARSET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
PICKUP_CODE_LENGTH = 6
PICKUP_CODE_MAX_RETRIES = 10

# Redemption grace period after file expiry
REDEMPTION_GRACE_DAYS = 7

# Chunk size for streaming file downloads (512 KB)
DOWNLOAD_CHUNK_SIZE = 512 * 1024

# Redis key prefixes
REDIS_JWT_BLACKLIST_PREFIX = "jwt_blacklist:"
REDIS_RATE_LIMIT_PREFIX = "rate_limit:"
REDIS_USER_ONLINE_PREFIX = "user_online:"
REDIS_DEVICE_ONLINE_PREFIX = "device_online:"

# Token type identifiers stored in JWT 'type' claim
TOKEN_TYPE_ACCESS = "access"
TOKEN_TYPE_REFRESH = "refresh"

# Allowed image/file MIME types (informational; we accept all)
ALLOWED_MIME_TYPES: list[str] = []  # empty = allow all

# Maximum pickup-code generation attempts before raising an error
MAX_PICKUP_CODE_ATTEMPTS = 20
