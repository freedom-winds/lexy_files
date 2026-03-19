import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  User? _user;
  bool _isLoading = true;
  String? _error;

  AuthProvider(this._api) {
    _init();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    final hasToken = await _api.hasToken();
    if (hasToken) {
      try {
        final response = await _api.getMe();
        final data = response.data;
        final userData = data is Map<String, dynamic> && data.containsKey('user')
            ? data['user'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        _user = User.fromJson(userData);
      } catch (_) {
        await _api.clearTokens();
        _user = null;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.login(username, password);
      final data = response.data as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      await _api.setTokens(
        tokens['access_token'] as String,
        tokens['refresh_token'] as String,
      );
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
    } catch (e) {
      _error = _api.getApiError(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String username, String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.register(username, email, password);
      final data = response.data as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      await _api.setTokens(
        tokens['access_token'] as String,
        tokens['refresh_token'] as String,
      );
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
    } catch (e) {
      _error = _api.getApiError(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Ignore
    }
    await _api.clearTokens();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
