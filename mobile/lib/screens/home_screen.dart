import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/file_info.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/file_size_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pickupCodeController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0;
  UploadResult? _uploadResult;
  String? _uploadError;
  bool _copied = false;

  @override
  void dispose() {
    _pickupCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final api = context.read<ApiService>();
    final auth = context.read<AuthProvider>();
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadResult = null;
      _uploadError = null;
    });

    try {
      await auth.ensureAnonymousSession();
      final response = await api.uploadFile(
        file.path!,
        file.name,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _uploadResult = UploadResult.fromJson(
          response.data as Map<String, dynamic>,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = api.getApiError(e));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetUpload() {
    setState(() {
      _uploadResult = null;
      _uploadError = null;
      _uploadProgress = 0;
      _copied = false;
    });
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _goToPickup() {
    final code = _pickupCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup codes are 6 characters long.')),
      );
      return;
    }
    Navigator.of(context).pushNamed('/pickup', arguments: code);
    _pickupCodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lexy Files'),
        actions: [
          if (auth.isAuthenticated)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (v) {
                if (v == 'logout') auth.logout();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    auth.user?.username ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'logout', child: Text('Sign out')),
              ],
            )
          else ...[
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              child: const Text('Sign in'),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHeader(auth),
            const SizedBox(height: 16),
            _buildUploadPanel(),
            const SizedBox(height: 12),
            _buildPickupPanel(),
            if (auth.isAuthenticated) ...[
              const SizedBox(height: 16),
              _buildQuickActions(),
            ] else ...[
              const SizedBox(height: 14),
              _buildAuthPrompt(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.folder_shared_rounded,
            color: Colors.white,
            background: Color(0x3327D7C7),
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.isAuthenticated
                      ? 'Ready, ${auth.user?.username ?? 'user'}'
                      : 'Quick file handoff',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Send once, pick up anywhere.',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                AppIconBadge(icon: Icons.upload_file_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send a file',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Upload and share a pickup code.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_uploadResult != null)
              _buildUploadSuccess()
            else
              _buildUploadArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_uploadError != null) ...[
          _InlineNotice(
            icon: Icons.error_outline,
            text: _uploadError!,
            color: AppTheme.error,
          ),
          const SizedBox(height: 12),
        ],
        if (_isUploading) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Uploading',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _uploadProgress, minHeight: 7),
        ] else ...[
          FilledButton.icon(
            onPressed: _pickAndUpload,
            icon: const Icon(Icons.attach_file),
            label: const Text('Choose file'),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadSuccess() {
    final result = _uploadResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InlineNotice(
          icon: Icons.check_circle,
          text: '${result.filename} - ${formatFileSize(result.fileSize)}',
          color: AppTheme.success,
        ),
        const SizedBox(height: 14),
        const Text(
          'Pickup code',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  result.pickupCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    letterSpacing: 5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copyCode(result.pickupCode),
                icon: Icon(_copied ? Icons.check : Icons.copy),
                tooltip: _copied ? 'Copied' : 'Copy',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _resetUpload,
          icon: const Icon(Icons.add),
          label: const Text('Send another file'),
        ),
      ],
    );
  }

  Widget _buildPickupPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                AppIconBadge(
                  icon: Icons.download_rounded,
                  color: AppTheme.success,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receive by code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enter the 6-character pickup code.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pickupCodeController,
                    decoration: const InputDecoration(hintText: 'ABC123'),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                      _UpperCaseFormatter(),
                    ],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                    onSubmitted: (_) => _goToPickup(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _goToPickup,
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Workspace',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        AppActionTile(
          icon: Icons.file_copy_outlined,
          title: 'My files',
          subtitle: 'Manage uploads and pickup codes',
          onTap: () => Navigator.of(context).pushNamed('/my-files'),
        ),
        const SizedBox(height: 8),
        AppActionTile(
          icon: Icons.devices_rounded,
          title: 'Devices',
          subtitle: 'See online devices and sessions',
          color: AppTheme.success,
          onTap: () => Navigator.of(context).pushNamed('/devices'),
        ),
        const SizedBox(height: 8),
        AppActionTile(
          icon: Icons.swap_horiz_rounded,
          title: 'Transfer',
          subtitle: 'Relay, LAN, and Bluetooth modes',
          color: AppTheme.accent,
          onTap: () => Navigator.of(context).pushNamed('/transfer'),
        ),
      ],
    );
  }

  Widget _buildAuthPrompt() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed('/register'),
            child: const Text('Create account'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('Sign in'),
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
