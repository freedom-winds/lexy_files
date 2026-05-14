import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/file_info.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/file_size_text.dart';

/// Home screen.
///
/// Visually mirrors the Windows reference (`design/windows/home.png`):
///   • Page title and account chip in a top bar
///   • Large hero pickup-code card with cyan primary action
///   • A second card below for "Receive by code"
///   • Quick-action tiles for authenticated users
///
/// All API calls are unchanged.
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
        SnackBar(content: Text(context.l10n.t('home.codeMustBe6'))),
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
      backgroundColor: AppTheme.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(auth: auth),
                const SizedBox(height: 24),
                _PickupHeroCard(
                  isUploading: _isUploading,
                  progress: _uploadProgress,
                  result: _uploadResult,
                  error: _uploadError,
                  copied: _copied,
                  onPickFile: _pickAndUpload,
                  onCopy: _copyCode,
                  onReset: _resetUpload,
                ),
                const SizedBox(height: 18),
                _ReceiveCard(
                  controller: _pickupCodeController,
                  onSubmit: _goToPickup,
                ),
                const SizedBox(height: 22),
                if (auth.isAuthenticated)
                  _QuickActions()
                else
                  _AuthPrompt(
                    onSignIn: () =>
                        Navigator.of(context).pushNamed('/login'),
                    onCreate: () =>
                        Navigator.of(context).pushNamed('/register'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top bar (page title + account chip) ───────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.auth});
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('home.title'),
                style: const TextStyle(
                  color: AppTheme.text1,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.t('home.subtitle'),
                style: const TextStyle(
                  color: AppTheme.text2,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (auth.isAuthenticated)
          PopupMenuButton<String>(
            tooltip: auth.user?.username ?? l.t('auth.account'),
            onSelected: (v) {
              if (v == 'logout') auth.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  auth.user?.username ?? l.t('auth.account'),
                  style: const TextStyle(
                    color: AppTheme.text1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Text(l.t('auth.signOut')),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    auth.user?.username ?? l.t('auth.account'),
                    style: const TextStyle(
                      color: AppTheme.text1,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: AppTheme.text2,
                    size: 18,
                  ),
                ],
              ),
            ),
          )
        else
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/login'),
                child: Text(l.t('auth.signIn')),
              ),
              const SizedBox(width: 6),
              CyanButton(
                label: l.t('auth.createAccount'),
                dense: true,
                onPressed: () =>
                    Navigator.of(context).pushNamed('/register'),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Pickup hero card ───────────────────────────────────────────────────────

class _PickupHeroCard extends StatelessWidget {
  const _PickupHeroCard({
    required this.isUploading,
    required this.progress,
    required this.result,
    required this.error,
    required this.copied,
    required this.onPickFile,
    required this.onCopy,
    required this.onReset,
  });

  final bool isUploading;
  final double progress;
  final UploadResult? result;
  final String? error;
  final bool copied;
  final VoidCallback onPickFile;
  final void Function(String) onCopy;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return HeroSurface(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flash_on_rounded,
                      size: 14,
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.t('home.quickSend'),
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (result != null)
                IconButton(
                  tooltip: context.l10n.t('home.sendAnother'),
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppTheme.text2,
                  onPressed: onReset,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (result != null)
            _PickupCodeBlock(
              code: result!.pickupCode,
              fileName: result!.filename,
              fileSize: result!.fileSize,
              copied: copied,
              onCopy: () => onCopy(result!.pickupCode),
            )
          else if (isUploading)
            _UploadingBlock(progress: progress)
          else
            _PickFileBlock(error: error, onPick: onPickFile),
        ],
      ),
    );
  }
}

class _PickFileBlock extends StatelessWidget {
  const _PickFileBlock({required this.error, required this.onPick});
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.t('home.dropAFile'),
          style: const TextStyle(
            color: AppTheme.text1,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l.t('home.youWillGetCode'),
          style: const TextStyle(color: AppTheme.text2, fontSize: 13),
        ),
        const SizedBox(height: 22),
        if (error != null) ...[
          _InlineNotice(
            icon: Icons.error_outline_rounded,
            text: error!,
            color: AppTheme.error,
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.bgDeep,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.accentGlow(alpha: 0.30),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  color: AppTheme.bgDeep,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l.t('home.chooseFileToUpload'),
                style: const TextStyle(
                  color: AppTheme.text1,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.t('home.fileTypesHint'),
                style: const TextStyle(
                  color: AppTheme.text2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              CyanButton(
                label: l.t('home.chooseFile'),
                icon: Icons.attach_file_rounded,
                onPressed: onPick,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UploadingBlock extends StatelessWidget {
  const _UploadingBlock({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.t('home.uploading'),
          style: const TextStyle(
            color: AppTheme.text1,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: progress, minHeight: 10),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _PickupCodeBlock extends StatelessWidget {
  const _PickupCodeBlock({
    required this.code,
    required this.fileName,
    required this.fileSize,
    required this.copied,
    required this.onCopy,
  });

  final String code;
  final String fileName;
  final int fileSize;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.t('home.yourPickupCode'),
          style: const TextStyle(
            color: AppTheme.text2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        // Big code display
        Center(
          child: SelectableText(
            code,
            style: const TextStyle(
              color: AppTheme.accentColor,
              fontFamily: 'monospace',
              fontSize: 64,
              fontWeight: FontWeight.w800,
              letterSpacing: 12,
              height: 1.0,
              shadows: [
                Shadow(
                  color: Color(0x6600F0FF),
                  blurRadius: 28,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgDeep,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 14,
                  color: AppTheme.text2,
                ),
                const SizedBox(width: 6),
                Text(
                  fileName,
                  style: const TextStyle(
                    color: AppTheme.text1,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppTheme.text3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatFileSize(fileSize),
                  style: const TextStyle(
                    color: AppTheme.text2,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: CyanButton(
            label: copied
                ? l.t('home.copied')
                : l.t('home.copyCode'),
            icon: copied ? Icons.check_rounded : Icons.copy_rounded,
            onPressed: onCopy,
          ),
        ),
      ],
    );
  }
}

// ── Receive by code card ──────────────────────────────────────────────────

class _ReceiveCard extends StatelessWidget {
  const _ReceiveCard({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: Icons.download_rounded,
                  color: AppTheme.accentColor,
                  useGradient: false,
                  glow: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('home.receiveByCode'),
                        style: const TextStyle(
                          color: AppTheme.text1,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.t('home.enterPickupCode'),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'ABC123',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                      _UpperCaseFormatter(),
                    ],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text1,
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(width: 10),
                CyanButton(
                  label: l.t('home.pickup'),
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onSubmit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick actions for signed-in users ─────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationProvider>();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: l.t('home.workspace')),
        AppActionTile(
          icon: Icons.folder_rounded,
          title: l.t('nav.files'),
          subtitle: l.t('home.manageUploads'),
          onTap: nav.navigateToFiles,
        ),
        const SizedBox(height: 8),
        AppActionTile(
          icon: Icons.devices_rounded,
          title: l.t('nav.devices'),
          subtitle: l.t('home.devicesOnline'),
          color: AppTheme.success,
          onTap: nav.navigateToDevices,
        ),
        const SizedBox(height: 8),
        AppActionTile(
          icon: Icons.swap_horiz_rounded,
          title: l.t('nav.transfer'),
          subtitle: l.t('home.transferDirect'),
          color: AppTheme.info,
          onTap: nav.navigateToTransfer,
        ),
      ],
    );
  }
}

class _AuthPrompt extends StatelessWidget {
  const _AuthPrompt({required this.onSignIn, required this.onCreate});
  final VoidCallback onSignIn;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final intro = Row(
              children: [
                const AppIconBadge(
                  icon: Icons.lock_outline_rounded,
                  color: AppTheme.info,
                  useGradient: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('auth.signInToSync'),
                        style: const TextStyle(
                          color: AppTheme.text1,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.t('auth.signInDescription'),
                        style: const TextStyle(
                          color: AppTheme.text2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onCreate,
                  child: Text(l.t('auth.createAccount')),
                ),
                CyanButton(
                  label: l.t('auth.signIn'),
                  onPressed: onSignIn,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  intro,
                  const SizedBox(height: 14),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: intro),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
      ),
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
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.40)),
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
                fontWeight: FontWeight.w600,
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
