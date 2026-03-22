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

  Future<bool> createCapsule({
    required String userId,
    required String name,
    required String description,
    required DateTime unlockDate,
    String emoji = '📦',
  }) async {
    try {
      final capsule = await _service.createCapsule(
        userId: userId,
        name: name,
        description: description,
        unlockDate: unlockDate,
        emoji: emoji,
      );
      _capsules.insert(0, capsule);
      _state = CapsuleLoadState.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
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