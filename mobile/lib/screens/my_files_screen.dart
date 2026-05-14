import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/file_info.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/file_size_text.dart';

/// My Files screen.
///
/// Mirrors `design/windows/files.png`:
///   • Title + search/refresh on the right
///   • List of file rows: icon | name+meta | pickup code chip | size | time | actions
///   • Dark surface cards, cyan chip for pickup code
class MyFilesScreen extends StatefulWidget {
  const MyFilesScreen({super.key});

  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen> {
  List<FileInfo> _files = [];
  bool _loading = true;
  String? _error;
  String? _copiedCode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() {
        _loading = false;
        _error = null;
        _files = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final response = await api.getMyFiles();
      final data = response.data;
      final list = data is List
          ? data
          : (data is Map && data.containsKey('data')
                ? data['data'] as List
                : []);
      if (!mounted) return;
      setState(() {
        _files = list
            .map((json) => FileInfo.fromJson(json as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = api.getApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteFile(FileInfo file) async {
    final api = context.read<ApiService>();
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('files.deleteFile')),
        content: Text(
          l.t(
            'files.deleteFileConfirm',
            params: {'name': file.originalFilename},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('files.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: Text(l.t('files.confirmDelete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await api.deleteFile(file.id);
      if (!mounted) return;
      setState(() => _files.removeWhere((f) => f.id == file.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(api.getApiError(e))));
      }
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copiedCode = code);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedCode = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? _files
        : _files
              .where(
                (f) => f.originalFilename.toLowerCase().contains(
                  _query.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FilesHeader(
                  count: _files.length,
                  onRefresh: _fetchFiles,
                  onSearch: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 22),
                Expanded(child: _buildBody(filtered)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<FileInfo> files) {
    final auth = context.watch<AuthProvider>();
    
    final l = context.l10n;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!auth.isAuthenticated) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: l.t('files.signInPrompt'),
        subtitle: l.t('files.signInPromptHint'),
        action: CyanButton(
          label: l.t('auth.signIn'),
          onPressed: () => Navigator.of(context).pushNamed('/login'),
        ),
      );
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: l.t('files.couldNotLoad'),
        subtitle: _error!,
        action: CyanButton(
          label: l.t('files.retry'),
          onPressed: _fetchFiles,
        ),
      );
    }
    if (_files.isEmpty) {
      return AppEmptyState(
        icon: Icons.folder_open_rounded,
        title: l.t('files.noFiles'),
        subtitle: l.t('files.noFilesHint'),
      );
    }
    if (files.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: l.t('files.noMatches'),
        subtitle: l.t('files.noMatchesHint'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFiles,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: files.length + 1,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.borderSubtle,
          ),
          itemBuilder: (_, i) {
            if (i == 0) return const _FilesColumnHeader();
            final file = files[i - 1];
            return _FileRow(
              file: file,
              isCopied: _copiedCode == file.pickupCode,
              onCopy: () => _copyCode(file.pickupCode),
              onDelete: () => _deleteFile(file),
            );
          },
        ),
      ),
    );
  }
}

class _FilesHeader extends StatelessWidget {
  const _FilesHeader({
    required this.count,
    required this.onRefresh,
    required this.onSearch,
  });

  final int count;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final subtitleKey = count == 1 ? 'files.subtitle' : 'files.subtitlePlural';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('files.title'),
                style: const TextStyle(
                  color: AppTheme.text1,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.t(subtitleKey, params: {'count': count}),
                style: const TextStyle(color: AppTheme.text2, fontSize: 13),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 280,
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: l.t('files.search'),
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: l.t('files.refresh'),
          icon: const Icon(Icons.refresh_rounded),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _FilesColumnHeader extends StatelessWidget {
  const _FilesColumnHeader();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppTheme.surface2,
      child: Row(
        children: [
          const SizedBox(width: 44),
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: Text(
              l.t('files.colName'),
              style: _kColHeaderStyle,
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(l.t('files.colPickup'), style: _kColHeaderStyle),
          ),
          SizedBox(
            width: 90,
            child: Text(l.t('files.colSize'), style: _kColHeaderStyle),
          ),
          SizedBox(
            width: 100,
            child: Text(l.t('files.colStatus'), style: _kColHeaderStyle),
          ),
          SizedBox(
            width: 130,
            child: Text(l.t('files.colExpires'), style: _kColHeaderStyle),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

const _kColHeaderStyle = TextStyle(
  color: AppTheme.text2,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
);

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.isCopied,
    required this.onCopy,
    required this.onDelete,
  });

  final FileInfo file;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  IconData _iconFor(String mime) {
    final m = mime.toLowerCase();
    if (m.startsWith('image/')) return Icons.image_rounded;
    if (m.startsWith('video/')) return Icons.movie_rounded;
    if (m.startsWith('audio/')) return Icons.music_note_rounded;
    if (m.contains('zip') || m.contains('compressed')) {
      return Icons.folder_zip_rounded;
    }
    if (m.contains('pdf')) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              _iconFor(file.mimeType),
              color: AppTheme.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalFilename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.text1,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDate(file.createdAt),
                  style: const TextStyle(
                    color: AppTheme.text2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCopied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 13,
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      file.pickupCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              formatFileSize(file.fileSize),
              style: const TextStyle(
                color: AppTheme.text1,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: file.isExpired
                ? StatusPill(
                    label: context.l10n.t('files.statusExpired'),
                    color: AppTheme.error,
                  )
                : StatusPill(
                    label: context.l10n.t('files.statusActive'),
                    color: AppTheme.success,
                  ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              file.isExpired
                  ? context.l10n.t('files.expired')
                  : formatRelativeDate(file.expiresAt),
              style: const TextStyle(
                color: AppTheme.text2,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.t('files.delete'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
