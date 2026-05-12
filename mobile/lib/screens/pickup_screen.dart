import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/file_info.dart';
import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/file_size_text.dart';

class PickupScreen extends StatefulWidget {
  final String code;
  const PickupScreen({super.key, required this.code});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  FileInfo? _file;
  bool _loading = true;
  String? _error;
  bool _downloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _fetchFile();
  }

  Future<void> _fetchFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final response = await api.getFileByPickupCode(widget.code);
      if (!mounted) return;
      setState(() {
        _file = FileInfo.fromJson(response.data as Map<String, dynamic>);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.read<ApiService>().getApiError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadFile() async {
    if (_file == null) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      final api = context.read<ApiService>();
      final dir = Directory.systemTemp;
      final savePath = p.join(dir.path, _file!.originalFilename);

      await api.downloadFile(
        _file!.id,
        savePath,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloaded to: $savePath')));
      _fetchFile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<ApiService>().getApiError(e))),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.code)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'File not found',
              subtitle: _error!,
              action: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            )
          : _file != null
          ? _buildFileInfo()
          : const SizedBox.shrink(),
    );
  }

  Widget _buildFileInfo() {
    final file = _file!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const AppIconBadge(
                icon: Icons.download_done_rounded,
                color: Colors.white,
                background: Color(0x3327D7C7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup ready',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.code,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppIconBadge(icon: Icons.insert_drive_file_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.originalFilename,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${formatFileSize(file.fileSize)} - ${file.mimeType}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.schedule,
                        label: 'Expires',
                        value: formatRelativeDate(file.expiresAt),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.download,
                        label: 'Downloads',
                        value:
                            '${file.downloadCount}${file.maxDownloads != null ? ' / ${file.maxDownloads}' : ''}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_downloading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Downloading',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      Text('${(_downloadProgress * 100).toInt()}%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 7,
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _downloadFile,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download file'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
