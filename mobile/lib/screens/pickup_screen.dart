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
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPage,
        title: Text(widget.code,
            style: const TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 4,
            )),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'File not found',
                  subtitle: _error!,
                  action: CyanButton(
                    label: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                )
              : _file != null
                  ? _buildFileInfo()
                  : const SizedBox.shrink(),
    );
  }

  Widget _buildFileInfo() {
    final file = _file!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero code ────────────────────────────────────────────
              HeroSurface(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  children: [
                    const Text(
                      'Pickup code',
                      style: TextStyle(
                        color: AppTheme.text2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.code,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontFamily: 'monospace',
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: Color(0x6600F0FF),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ── File detail card ─────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.accentColor
                                    .withValues(alpha: 0.30),
                              ),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file_rounded,
                              color: AppTheme.accentColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.originalFilename,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.text1,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${formatFileSize(file.fileSize)} • ${file.mimeType}',
                                  style: const TextStyle(
                                    color: AppTheme.text2,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.schedule_rounded,
                              label: 'Expires',
                              value: formatRelativeDate(file.expiresAt),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.download_rounded,
                              label: 'Downloads',
                              value:
                                  '${file.downloadCount}${file.maxDownloads != null ? ' / ${file.maxDownloads}' : ''}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_downloading) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Downloading',
                              style: TextStyle(color: AppTheme.text2),
                            ),
                            Text(
                              '${(_downloadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _downloadProgress,
                            minHeight: 8,
                          ),
                        ),
                      ] else
                        CyanButton(
                          label: 'Download file',
                          icon: Icons.download_rounded,
                          expanded: true,
                          onPressed: _downloadFile,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.text2),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppTheme.text2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.text1,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
