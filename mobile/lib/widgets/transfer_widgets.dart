import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'file_size_text.dart';

/// Unified progress panel for all transfer modes
class TransferProgressPanel extends StatelessWidget {
  const TransferProgressPanel({
    super.key,
    required this.fileName,
    required this.progress,
    this.targetName,
    this.bytesTransferred,
    this.totalBytes,
    this.isSending = true,
  });

  final String fileName;
  final double progress; // 0-100
  final String? targetName;
  final int? bytesTransferred;
  final int? totalBytes;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSending ? Icons.upload : Icons.download,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (targetName != null) ...[
              const SizedBox(height: 4),
              Text(
                '${isSending ? 'To' : 'From'}: $targetName',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (bytesTransferred != null && totalBytes != null)
                  Text(
                    '${formatFileSize(bytesTransferred!)} / ${formatFileSize(totalBytes!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  '${progress.toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified device card for selecting transfer targets
class DeviceTargetCard extends StatelessWidget {
  const DeviceTargetCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onSend,
    this.isOnline = true,
    this.icon = Icons.devices,
    this.iconColor,
  });

  final String name;
  final String subtitle;
  final VoidCallback? onSend;
  final bool isOnline;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ??
        (isOnline ? AppTheme.success : AppTheme.textSecondary);

    return Card(
      child: ListTile(
        leading: Icon(icon, color: effectiveIconColor, size: 22),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isOnline ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: onSend != null
            ? IconButton(
                icon: const Icon(Icons.send, size: 20),
                onPressed: onSend,
                tooltip: 'Send file',
                color: AppTheme.primaryColor,
              )
            : null,
        enabled: isOnline,
      ),
    );
  }
}

/// Compact status banner for warnings and info
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.type = StatusBannerType.info,
    this.icon,
    this.onDismiss,
  });

  final String message;
  final StatusBannerType type;
  final IconData? icon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color iconColor;
    IconData defaultIcon;

    switch (type) {
      case StatusBannerType.success:
        backgroundColor = AppTheme.success.withAlpha(24);
        iconColor = AppTheme.success;
        defaultIcon = Icons.check_circle;
        break;
      case StatusBannerType.warning:
        backgroundColor = AppTheme.warning.withAlpha(24);
        iconColor = AppTheme.warning;
        defaultIcon = Icons.warning;
        break;
      case StatusBannerType.error:
        backgroundColor = AppTheme.error.withAlpha(24);
        iconColor = AppTheme.error;
        defaultIcon = Icons.error;
        break;
      case StatusBannerType.info:
      default:
        backgroundColor = AppTheme.primaryLight;
        iconColor = AppTheme.primaryColor;
        defaultIcon = Icons.info_outline;
    }

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon ?? defaultIcon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

enum StatusBannerType { success, warning, error, info }

/// Section header for grouping content
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Connection status indicator
class ConnectionStatusPanel extends StatelessWidget {
  const ConnectionStatusPanel({
    super.key,
    required this.isConnected,
    required this.connectedMessage,
    required this.disconnectedMessage,
  });

  final bool isConnected;
  final String connectedMessage;
  final String disconnectedMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isConnected ? AppTheme.success.withAlpha(24) : AppTheme.warning.withAlpha(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              size: 18,
              color: isConnected ? AppTheme.success : AppTheme.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isConnected ? connectedMessage : disconnectedMessage,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
