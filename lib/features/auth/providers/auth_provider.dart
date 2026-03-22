import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  appwrite_models.User? _user;
  String? _error;

  AuthStatus get status => _status;
  appwrite_models.User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkSession() async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user;
        await UserCryptoState.loadFromStorage(user.$id);
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final result = await _authService.login(email: email, password: password);
      _user = result.user;

      await UserCryptoState.initializeForUser(
        userId: result.user.$id,
        password: password,
        salt: result.salt,
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _error = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final result = await _authService.signup(email: email, password: password);
      _user = result.user;

      await UserCryptoState.initializeForUser(
        userId: result.user.$id,
        password: password,
        salt: result.salt,
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _error = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_user != null) {
        await UserCryptoState.clearForUser(_user!.$id);
      }
      await _authService.logout();
    } catch (_) {}
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> checkUsername() async {
  if (_user == null) return false;
  return await _authService.hasUsername(_user!.$id);
}

  String _parseError(String raw) {
    if (raw.contains('Invalid credentials')) return 'Invalid email or password.';
    if (raw.contains('already exists')) return 'An account with this email already exists.';
    if (raw.contains('network')) return 'Network error. Check your connection.';
    return 'Something went wrong. Please try again.';
  }
}