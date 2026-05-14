import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/home_screen.dart';
import '../screens/my_files_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/transfer_screen.dart';

/// Top-level app shell.
///
/// Wide screens (Windows / tablet / web): full-height navy sidebar with a
/// **cyan pill** for the active item — matches the design/windows reference.
///
/// Narrow (phone): compact `NavigationBar` at the bottom, still dark theme.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _items = <_NavItem>[
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItem(
      label: 'My Files',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    _NavItem(
      label: 'Devices',
      icon: Icons.devices_outlined,
      selectedIcon: Icons.devices_rounded,
    ),
    _NavItem(
      label: 'Transfer',
      icon: Icons.swap_horiz_outlined,
      selectedIcon: Icons.swap_horiz_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final isWide = MediaQuery.of(context).size.width >= 720;

    final screens = <Widget>[
      const HomeScreen(),
      const MyFilesScreen(),
      const DevicesScreen(),
      const TransferScreen(),
    ];

    if (isWide) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: Row(
          children: [
            _Sidebar(
              items: _items,
              selectedIndex: nav.selectedIndex,
              onSelect: nav.navigateToTab,
            ),
            Expanded(child: screens[nav.selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: screens[nav.selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface2,
          border: Border(
            top: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: nav.selectedIndex,
          onDestinationSelected: nav.navigateToTab,
          backgroundColor: Colors.transparent,
          destinations: _items
              .map(
                (it) => NavigationDestination(
                  icon: Icon(it.icon),
                  selectedIcon: Icon(it.selectedIcon),
                  label: it.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userLabel = auth.isAuthenticated
        ? (auth.user?.username ?? 'Account')
        : 'Guest';

    return Container(
      width: AppTheme.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppTheme.surface2,
        border: Border(
          right: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Brand ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 16, 20),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppTheme.accentGlow(alpha: 0.25),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.bgDeep,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        children: [
                          TextSpan(
                            text: 'Lexy',
                            style: TextStyle(color: AppTheme.text1),
                          ),
                          TextSpan(
                            text: ' Files',
                            style: TextStyle(color: AppTheme.accentColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Nav items ────────────────────────────────────────────────
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: _SidebarItem(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
              ),

            const Spacer(),

            // ── Account pill ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: _AccountRow(
                name: userLabel,
                isAuthenticated: auth.isAuthenticated,
                onSignIn: () =>
                    Navigator.of(context).pushNamed('/login'),
                onSignOut: auth.logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final bg = sel
        ? AppTheme.accentColor
        : (_hovered ? AppTheme.surface3 : Colors.transparent);
    final fg = sel ? AppTheme.bgDeep : AppTheme.text1;
    final iconColor = sel ? AppTheme.bgDeep : AppTheme.text2;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel ? AppTheme.accentGlow(alpha: 0.35) : null,
          ),
          child: Row(
            children: [
              Icon(
                sel ? widget.item.selectedIcon : widget.item.icon,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.2,
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

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.name,
    required this.isAuthenticated,
    required this.onSignIn,
    required this.onSignOut,
  });

  final String name;
  final bool isAuthenticated;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAuthenticated
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              color: AppTheme.accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.text1,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isAuthenticated ? 'Signed in' : 'Not signed in',
                  style: const TextStyle(color: AppTheme.text2, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isAuthenticated ? 'Sign out' : 'Sign in',
            icon: Icon(
              isAuthenticated ? Icons.logout_rounded : Icons.login_rounded,
              size: 18,
            ),
            onPressed: isAuthenticated ? onSignOut : onSignIn,
          ),
        ],
      ),
    );
  }
}
