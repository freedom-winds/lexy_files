"""initial schema

Revision ID: 20260318_0001
Revises:
Create Date: 2026-03-18 00:01:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260318_0001"
down_revision = None
branch_labels = None
depends_on = None


user_group_enum = sa.Enum("anonymous", "normal", "vip", "admin", name="user_group_enum")
file_status_enum = sa.Enum("active", "expired", "redemption", "deleted", name="file_status_enum")
device_type_enum = sa.Enum("phone", "tablet", "laptop", "desktop", "other", name="device_type_enum")
device_platform_enum = sa.Enum("android", "ios", "windows", "macos", "linux", "web", name="device_platform_enum")
transfer_mode_enum = sa.Enum("bluetooth", "lan", "same_account", "pickup", name="transfer_mode_enum")
transfer_status_enum = sa.Enum(
    "pending",
    "accepted",
    "in_progress",
    "completed",
    "rejected",
    "cancelled",
    "failed",
    name="transfer_status_enum",
)
group_quota_enum = sa.Enum("anonymous", "normal", "vip", "admin", name="group_quota_enum")
traffic_quota_period_enum = sa.Enum("daily", "monthly", name="traffic_quota_period_enum")
traffic_period_type_enum = sa.Enum("daily", "monthly", name="traffic_period_type_enum")


def upgrade():
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("username", sa.String(length=64), nullable=True),
        sa.Column("email", sa.String(length=256), nullable=True),
        sa.Column("password_hash", sa.String(length=256), nullable=True),
        sa.Column("user_group", user_group_enum, nullable=False),
        sa.Column("is_anonymous", sa.Boolean(), nullable=False),
        sa.Column("is_banned", sa.Boolean(), nullable=False),
        sa.Column("ip_address", sa.String(length=64), nullable=True),
        sa.Column("device_fingerprint", sa.String(length=256), nullable=True),
        sa.Column("custom_quota_overrides", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
        sa.UniqueConstraint("username"),
    )
    op.create_index(op.f("ix_users_device_fingerprint"), "users", ["device_fingerprint"], unique=False)
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=False)
    op.create_index(op.f("ix_users_ip_address"), "users", ["ip_address"], unique=False)
    op.create_index(op.f("ix_users_username"), "users", ["username"], unique=False)

    op.create_table(
        "group_quotas",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("group_name", group_quota_enum, nullable=False),
        sa.Column("download_speed_limit", sa.BigInteger(), nullable=False),
        sa.Column("max_single_file_size", sa.BigInteger(), nullable=False),
        sa.Column("max_total_storage", sa.BigInteger(), nullable=False),
        sa.Column("download_traffic_quota", sa.BigInteger(), nullable=False),
        sa.Column("traffic_quota_period", traffic_quota_period_enum, nullable=False),
        sa.Column("max_retention_seconds", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("group_name"),
    )
    op.create_index(op.f("ix_group_quotas_group_name"), "group_quotas", ["group_name"], unique=False)

    op.create_table(
        "devices",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("device_type", device_type_enum, nullable=False),
        sa.Column("platform", device_platform_enum, nullable=False),
        sa.Column("device_id", sa.String(length=256), nullable=False),
        sa.Column("is_online", sa.Boolean(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("device_id"),
    )
    op.create_index(op.f("ix_devices_device_id"), "devices", ["device_id"], unique=False)
    op.create_index(op.f("ix_devices_user_id"), "devices", ["user_id"], unique=False)

    op.create_table(
        "files",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("original_filename", sa.String(length=512), nullable=False),
        sa.Column("stored_filename", sa.String(length=512), nullable=False),
        sa.Column("file_size", sa.BigInteger(), nullable=False),
        sa.Column("mime_type", sa.String(length=256), nullable=True),
        sa.Column("pickup_code", sa.String(length=16), nullable=True),
        sa.Column("download_count", sa.Integer(), nullable=False),
        sa.Column("status", file_status_enum, nullable=False),
        sa.Column("storage_path", sa.String(length=1024), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=True),
        sa.Column("redemption_ends_at", sa.DateTime(), nullable=True),
        sa.Column("deleted_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("pickup_code"),
        sa.UniqueConstraint("stored_filename"),
    )
    op.create_index(op.f("ix_files_expires_at"), "files", ["expires_at"], unique=False)
    op.create_index(op.f("ix_files_pickup_code"), "files", ["pickup_code"], unique=False)
    op.create_index(op.f("ix_files_redemption_ends_at"), "files", ["redemption_ends_at"], unique=False)
    op.create_index(op.f("ix_files_status"), "files", ["status"], unique=False)
    op.create_index(op.f("ix_files_user_id"), "files", ["user_id"], unique=False)

    op.create_table(
        "transfers",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=False),
        sa.Column("receiver_id", sa.Integer(), nullable=True),
        sa.Column("sender_device_id", sa.Integer(), nullable=True),
        sa.Column("receiver_device_id", sa.Integer(), nullable=True),
        sa.Column("mode", transfer_mode_enum, nullable=False),
        sa.Column("status", transfer_status_enum, nullable=False),
        sa.Column("file_name", sa.String(length=512), nullable=False),
        sa.Column("file_size", sa.BigInteger(), nullable=False),
        sa.Column("bytes_transferred", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["receiver_device_id"], ["devices.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["receiver_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["sender_device_id"], ["devices.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["sender_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_transfers_receiver_device_id"), "transfers", ["receiver_device_id"], unique=False)
    op.create_index(op.f("ix_transfers_receiver_id"), "transfers", ["receiver_id"], unique=False)
    op.create_index(op.f("ix_transfers_sender_device_id"), "transfers", ["sender_device_id"], unique=False)
    op.create_index(op.f("ix_transfers_sender_id"), "transfers", ["sender_id"], unique=False)
    op.create_index(op.f("ix_transfers_status"), "transfers", ["status"], unique=False)

    op.create_table(
        "traffic_usages",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("bytes_downloaded", sa.BigInteger(), nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_type", traffic_period_type_enum, nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "period_start", "period_type", name="uq_traffic_user_period"),
    )
    op.create_index(op.f("ix_traffic_usages_period_start"), "traffic_usages", ["period_start"], unique=False)
    op.create_index(op.f("ix_traffic_usages_user_id"), "traffic_usages", ["user_id"], unique=False)


def downgrade():
    op.drop_index(op.f("ix_traffic_usages_user_id"), table_name="traffic_usages")
    op.drop_index(op.f("ix_traffic_usages_period_start"), table_name="traffic_usages")
    op.drop_table("traffic_usages")
    op.drop_index(op.f("ix_transfers_status"), table_name="transfers")
    op.drop_index(op.f("ix_transfers_sender_id"), table_name="transfers")
    op.drop_index(op.f("ix_transfers_sender_device_id"), table_name="transfers")
    op.drop_index(op.f("ix_transfers_receiver_id"), table_name="transfers")
    op.drop_index(op.f("ix_transfers_receiver_device_id"), table_name="transfers")
    op.drop_table("transfers")
    op.drop_index(op.f("ix_files_user_id"), table_name="files")
    op.drop_index(op.f("ix_files_status"), table_name="files")
    op.drop_index(op.f("ix_files_redemption_ends_at"), table_name="files")
    op.drop_index(op.f("ix_files_pickup_code"), table_name="files")
    op.drop_index(op.f("ix_files_expires_at"), table_name="files")
    op.drop_table("files")
    op.drop_index(op.f("ix_devices_user_id"), table_name="devices")
    op.drop_index(op.f("ix_devices_device_id"), table_name="devices")
    op.drop_table("devices")
    op.drop_index(op.f("ix_group_quotas_group_name"), table_name="group_quotas")
    op.drop_table("group_quotas")
    op.drop_index(op.f("ix_users_username"), table_name="users")
    op.drop_index(op.f("ix_users_ip_address"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_index(op.f("ix_users_device_fingerprint"), table_name="users")
    op.drop_table("users")
