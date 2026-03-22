import 'package:flutter/material.dart';
import 'package:boxed_app/features/capsules/services/capsule_service.dart';

enum CapsuleLoadState { idle, loading, loaded, empty, error }

class CapsuleProvider extends ChangeNotifier {
  final CapsuleService _service = CapsuleService();

  CapsuleLoadState _state = CapsuleLoadState.idle;
  List<Map<String, dynamic>> _capsules = [];
  String? _error;

  CapsuleLoadState get state => _state;
  List<Map<String, dynamic>> get capsules => _capsules;
  String? get error => _error;

  Future<void> loadCapsules(String userId) async {
    _state = CapsuleLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.fetchCapsules(userId);
      _capsules = result;
      _state = result.isEmpty ? CapsuleLoadState.empty : CapsuleLoadState.loaded;
    } catch (e) {
      _error = e.toString();
      _state = CapsuleLoadState.error;
    }
    notifyListeners();
  }

  // Called directly from CreateCapsuleScreen after
  // capsule + memories are already saved to Appwrite
  void addCapsule(Map<String, dynamic> capsule) {
    _capsules.insert(0, capsule);
    _state = CapsuleLoadState.loaded;
    notifyListeners();
  }

  Future<void> deleteCapsule(String capsuleId) async {
    await _service.deleteCapsule(capsuleId);
    _capsules.removeWhere((c) => c['capsuleId'] == capsuleId);
    _state = _capsules.isEmpty ? CapsuleLoadState.empty : CapsuleLoadState.loaded;
    notifyListeners();
  }

  void clear() {
    _capsules = [];
    _state = CapsuleLoadState.idle;
    _error = null;
    notifyListeners();
  }
}