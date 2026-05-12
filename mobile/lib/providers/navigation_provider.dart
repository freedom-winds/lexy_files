import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void navigateToTab(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void navigateToHome() => navigateToTab(0);
  void navigateToFiles() => navigateToTab(1);
  void navigateToDevices() => navigateToTab(2);
  void navigateToTransfer() => navigateToTab(3);
}
