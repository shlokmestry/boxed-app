import 'package:flutter/material.dart';

class AddMemoryScreen extends StatelessWidget {
  final String capsuleId;
  const AddMemoryScreen({super.key, required this.capsuleId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text('Add Memory — Coming in Phase 3',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}