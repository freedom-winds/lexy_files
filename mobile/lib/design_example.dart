// Visual example of the new modern design direction.
// Navigate to '/design-preview' to view this in the running app.

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// NEW MODERN THEME TOKENS
// ═══════════════════════════════════════════════════════════════════════════

class ModernTheme {
  // Primary - Indigo
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFFA5B4FC);
  static const Color primarySubtle = Color(0xFFEEF2FF);

  // Accents
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutrals
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Shadows
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successDark],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERN BUTTON
// ═══════════════════════════════════════════════════════════════════════════

enum ModernButtonVariant { primary, secondary, ghost }

class ModernButton extends StatefulWidget {
  const ModernButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = ModernButtonVariant.primary,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final ModernButtonVariant variant;
  final IconData? icon;

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == ModernButtonVariant.primary;
    final isSecondary = widget.variant == ModernButtonVariant.secondary;
    final isGhost = widget.variant == ModernButtonVariant.ghost;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isPrimary ? ModernTheme.primaryGradient : null,
              color: isSecondary
                  ? ModernTheme.surface
                  : isGhost
                  ? (_isHovered
                        ? ModernTheme.primarySubtle
                        : Colors.transparent)
                  : null,
              border: isSecondary
                  ? Border.all(color: ModernTheme.border, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: ModernTheme.primary.withAlpha(_isHovered ? 80 : 60),
                        blurRadius: _isHovered ? 16 : 10,
                        offset: Offset(0, _isHovered ? 6 : 3),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 18,
                    color: isPrimary ? Colors.white : ModernTheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPrimary
                        ? Colors.white
                        : isGhost
                        ? ModernTheme.primary
                        : ModernTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERN CARD
// ═══════════════════════════════════════════════════════════════════════════

class ModernCard extends StatefulWidget {
  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: ModernTheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isHovered ? ModernTheme.shadowLg : ModernTheme.shadowMd,
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERN STATUS PILL
// ═══════════════════════════════════════════════════════════════════════════

class ModernStatusPill extends StatelessWidget {
  const ModernStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PULSING DOT (for online indicator)
// ═══════════════════════════════════════════════════════════════════════════

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, this.color = ModernTheme.success});

  final Color color;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 8 + _controller.value * 8,
              height: 8 + _controller.value * 8,
              decoration: BoxDecoration(
                color: widget.color.withAlpha((80 * (1 - _controller.value)).toInt()),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERN FILE CARD
// ═══════════════════════════════════════════════════════════════════════════

class ModernFileCard extends StatelessWidget {
  const ModernFileCard({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.pickupCode,
    required this.isActive,
    this.onCopy,
    this.onDelete,
  });

  final String fileName;
  final String fileSize;
  final String pickupCode;
  final bool isActive;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Row(
        children: [
          // Gradient icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: ModernTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: ModernTheme.primary.withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      fileSize,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onCopy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ModernTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.copy_rounded,
                              size: 11,
                              color: ModernTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pickupCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: ModernTheme.primary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ModernStatusPill(
            label: isActive ? 'Active' : 'Expired',
            color: isActive ? ModernTheme.success : ModernTheme.error,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: onDelete,
            color: ModernTheme.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERN DEVICE CARD
// ═══════════════════════════════════════════════════════════════════════════

class ModernDeviceCard extends StatelessWidget {
  const ModernDeviceCard({
    super.key,
    required this.name,
    required this.platform,
    required this.isOnline,
    this.onDelete,
  });

  final String name;
  final String platform;
  final bool isOnline;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isOnline
                  ? ModernTheme.successGradient
                  : const LinearGradient(
                      colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                    ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: ModernTheme.success.withAlpha(60),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: const Icon(
              Icons.computer_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      platform,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                    if (isOnline) ...[
                      const SizedBox(width: 10),
                      const PulsingDot(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ModernStatusPill(
            label: isOnline ? 'Online' : 'Offline',
            color: isOnline ? ModernTheme.success : ModernTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: onDelete,
            color: ModernTheme.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERN HERO ACTION CARD (for Home screen)
// ═══════════════════════════════════════════════════════════════════════════

class HeroActionCard extends StatefulWidget {
  const HeroActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  State<HeroActionCard> createState() => _HeroActionCardState();
}

class _HeroActionCardState extends State<HeroActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
          height: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: widget.isPrimary ? ModernTheme.heroGradient : null,
            color: widget.isPrimary ? null : ModernTheme.surface,
            border: widget.isPrimary
                ? null
                : Border.all(color: ModernTheme.border, width: 1.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: ModernTheme.primary.withAlpha(_isHovered ? 100 : 60),
                      blurRadius: _isHovered ? 24 : 16,
                      offset: Offset(0, _isHovered ? 8 : 4),
                    ),
                  ]
                : (_isHovered ? ModernTheme.shadowMd : ModernTheme.shadowSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isPrimary
                      ? Colors.white.withAlpha(40)
                      : ModernTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isPrimary ? Colors.white : ModernTheme.primary,
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.isPrimary
                          ? Colors.white
                          : ModernTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isPrimary
                          ? Colors.white.withAlpha(220)
                          : ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLE PREVIEW SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class ModernDesignExample extends StatelessWidget {
  const ModernDesignExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.background,
      appBar: AppBar(
        backgroundColor: ModernTheme.background,
        elevation: 0,
        title: const Text(
          'Design Preview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ModernTheme.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section: Hero cards
          _sectionTitle('Hero Actions'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HeroActionCard(
                  icon: Icons.upload_rounded,
                  title: 'Send File',
                  subtitle: 'Upload and share',
                  onTap: () {},
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HeroActionCard(
                  icon: Icons.download_rounded,
                  title: 'Receive',
                  subtitle: 'Enter pickup code',
                  onTap: () {},
                  isPrimary: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Section: Buttons
          _sectionTitle('Buttons'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ModernButton(
                onPressed: () {},
                icon: Icons.upload_rounded,
                label: 'Primary',
              ),
              ModernButton(
                onPressed: () {},
                variant: ModernButtonVariant.secondary,
                label: 'Secondary',
              ),
              ModernButton(
                onPressed: () {},
                variant: ModernButtonVariant.ghost,
                icon: Icons.refresh_rounded,
                label: 'Ghost',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Section: File cards
          _sectionTitle('File Cards'),
          const SizedBox(height: 12),
          ModernFileCard(
            fileName: 'presentation.pdf',
            fileSize: '2.4 MB',
            pickupCode: 'ABC123',
            isActive: true,
            onCopy: () {},
            onDelete: () {},
          ),
          const SizedBox(height: 10),
          ModernFileCard(
            fileName: 'vacation-photos.zip',
            fileSize: '156 MB',
            pickupCode: 'XYZ789',
            isActive: false,
            onCopy: () {},
            onDelete: () {},
          ),
          const SizedBox(height: 28),

          // Section: Device cards
          _sectionTitle('Device Cards'),
          const SizedBox(height: 12),
          ModernDeviceCard(
            name: 'Windows Desktop',
            platform: 'Windows 11',
            isOnline: true,
            onDelete: () {},
          ),
          const SizedBox(height: 10),
          ModernDeviceCard(
            name: 'MacBook Pro',
            platform: 'macOS • Last seen 2h ago',
            isOnline: false,
            onDelete: () {},
          ),
          const SizedBox(height: 28),

          // Section: Status pills
          _sectionTitle('Status Indicators'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              ModernStatusPill(
                label: 'Online',
                color: ModernTheme.success,
                icon: Icons.circle,
              ),
              ModernStatusPill(
                label: 'Offline',
                color: ModernTheme.textSecondary,
              ),
              ModernStatusPill(
                label: 'Transferring',
                color: ModernTheme.info,
                icon: Icons.sync_rounded,
              ),
              ModernStatusPill(
                label: 'Failed',
                color: ModernTheme.error,
                icon: Icons.error_outline,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ModernTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
