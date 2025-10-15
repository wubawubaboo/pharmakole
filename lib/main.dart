import 'package:flutter/material.dart';
import 'pages/login_page.dart';

void main() {
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHARMAKOLE POS',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const LoginPage(),
    );
  }
}
