import 'package:flutter/material.dart';

enum CapsuleLoadState { idle, loading, loaded, empty, error }

class CapsuleProvider extends ChangeNotifier {
  CapsuleLoadState _state = CapsuleLoadState.idle;
  List<Map<String, dynamic>> _capsules = [];
  String? _error;

  CapsuleLoadState get state => _state;
  List<Map<String, dynamic>> get capsules => _capsules;
  String? get error => _error;

  void setCapsules(List<Map<String, dynamic>> capsules) {
    _capsules = capsules;
    _state = capsules.isEmpty ? CapsuleLoadState.empty : CapsuleLoadState.loaded;
    notifyListeners();
  }

  void setLoading() {
    _state = CapsuleLoadState.loading;
    notifyListeners();
  }

  void setError(String error) {
    _error = error;
    _state = CapsuleLoadState.error;
    notifyListeners();
  }

  void clear() {
    _capsules = [];
    _state = CapsuleLoadState.idle;
    _error = null;
    notifyListeners();
  }
}