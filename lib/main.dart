// lib/main.dart
import 'package:flutter/material.dart';
import 'package:winspin_app/screens/win_spin_screen.dart'; // Assurez-vous que le chemin est correct

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinSpin SalesUpLift',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WinSpinScreen(), // Notre écran principal
    );
  }
}