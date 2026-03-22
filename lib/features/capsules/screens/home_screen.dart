import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text('Home Screen — Coming in Phase 2',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}