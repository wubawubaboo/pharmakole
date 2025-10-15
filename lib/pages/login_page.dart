import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home_page.dart';
import 'check_api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  final String loginUrl = 'http://192.168.5.129/pharma/api/modules/users/login';

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse(loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _usernameController.text,
            'password': _passwordController.text
          }));
      setState(() => _loading = false);
      if (res.statusCode == 200) {
        final jsonBody = jsonDecode(res.body);
        final user = jsonBody['user'] ?? {'full_name': 'staff'};
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: Map<String, dynamic>.from(user))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials')));
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login error: $e')));
    }
  }


  @override
  void initState() {
  super.initState();
  checkApiConnection();
}
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PHARMAKOLE POS - Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 8),
          TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          const SizedBox(height: 20),
          _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _login, child: const Text('Login')),
        ]),
      ),
    );
  }
}
