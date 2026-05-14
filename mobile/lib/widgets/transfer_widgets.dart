import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'app_ui.dart';
import 'file_size_text.dart';

/// Unified progress panel for all transfer modes.
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSending
                        ? Icons.upload_rounded
                        : Icons.download_rounded,
                    size: 18,
                    color: AppTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: AppTheme.text1,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (targetName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${isSending ? 'To' : 'From'}: $targetName',
                          style: const TextStyle(
                            color: AppTheme.text2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${progress.toInt()}%',
                  style: const TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
              ),
            ),
            if (bytesTransferred != null && totalBytes != null) ...[
              const SizedBox(height: 8),
              Text(
                '${formatFileSize(bytesTransferred!)} / ${formatFileSize(totalBytes!)}',
                style: const TextStyle(color: AppTheme.text2, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Unified device card for selecting transfer targets.
class DeviceTargetCard extends StatelessWidget {
  const DeviceTargetCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onSend,
    this.isOnline = true,
    this.icon = Icons.devices_rounded,
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
    final color = iconColor ??
        (isOnline ? AppTheme.success : AppTheme.text3);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isOnline
                    ? AppTheme.successGradient
                    : AppTheme.offlineGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.bgDeep, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOnline ? AppTheme.text1 : AppTheme.text2,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.text2,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusPill(
              label: isOnline ? 'Ready' : 'Offline',
              color: color,
            ),
            const SizedBox(width: 8),
            if (onSend != null)
              IconButton(
                tooltip: 'Send file',
                icon: const Icon(Icons.send_rounded),
                color: AppTheme.accentColor,
                onPressed: onSend,
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact status banner for warnings and info.
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
    final Color color;
    final IconData defaultIcon;
    switch (type) {
      case StatusBannerType.success:
        color = AppTheme.success;
        defaultIcon = Icons.check_circle_rounded;
        break;
      case StatusBannerType.warning:
        color = AppTheme.warning;
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case StatusBannerType.error:
        color = AppTheme.error;
        defaultIcon = Icons.error_outline_rounded;
        break;
      case StatusBannerType.info:
        color = AppTheme.accentColor;
        defaultIcon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon ?? defaultIcon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: color,
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 28,
                height: 28,
              ),
            ),
        ],
      ),
    );
  }
}

enum StatusBannerType { success, warning, error, info }

/// Section header for grouping content.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.text1,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Connection status indicator (relay / LAN / BLE).
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
    final color = isConnected ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected ? connectedMessage : disconnectedMessage,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isConnected) const PulsingDot(color: AppTheme.success, size: 6),
        ],
      ),
    );
  }
}
