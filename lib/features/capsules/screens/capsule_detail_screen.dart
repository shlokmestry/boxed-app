import 'package:flutter/material.dart';

class CapsuleDetailScreen extends StatelessWidget {
  final String capsuleId;
  const CapsuleDetailScreen({super.key, required this.capsuleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text('Capsule $capsuleId — Coming in Phase 3',
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}