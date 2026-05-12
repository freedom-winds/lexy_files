import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/navigation_provider.dart';
import '../screens/home_screen.dart';
import '../screens/my_files_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/transfer_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final isWide = MediaQuery.of(context).size.width >= 640;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: 'Files',
      ),
      const NavigationDestination(
        icon: Icon(Icons.devices_outlined),
        selectedIcon: Icon(Icons.devices),
        label: 'Devices',
      ),
      const NavigationDestination(
        icon: Icon(Icons.swap_horiz_outlined),
        selectedIcon: Icon(Icons.swap_horiz),
        label: 'Transfer',
      ),
    ];

    final railDestinations = destinations
        .map(
          (d) => NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: Text(d.label),
          ),
        )
        .toList();

    final screens = [
      const HomeScreen(),
      const MyFilesScreen(),
      const DevicesScreen(),
      const TransferScreen(),
    ];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: nav.selectedIndex,
              onDestinationSelected: nav.navigateToTab,
              labelType: NavigationRailLabelType.all,
              destinations: railDestinations,
              backgroundColor: AppTheme.surface,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: screens[nav.selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: screens[nav.selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.selectedIndex,
        onDestinationSelected: nav.navigateToTab,
        destinations: destinations,
      ),
    );
  }
}
