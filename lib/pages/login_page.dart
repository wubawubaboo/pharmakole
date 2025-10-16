import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io'; // Import for SocketException
import 'dart:async'; // Import for TimeoutException
import 'package:http/http.dart' as http;
import 'home_page.dart';
import '../api_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  final String loginUrl = ApiConfig.login;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse(loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _usernameController.text,
            'password': _passwordController.text
          })).timeout(const Duration(seconds: 5)); // Added a timeout

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
        String errorMessage = 'An unknown error occurred.';
        try {
          final jsonBody = jsonDecode(res.body);
          if (jsonBody.containsKey('error')) {
            errorMessage = jsonBody['error'];
          } else {
             errorMessage = 'Received status code ${res.statusCode}';
          }
        } catch(e) {
            errorMessage = 'Failed to understand server response: ${res.body}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      setState(() => _loading = false);
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'Could not connect to server. Check IP address and network.';
      } else if (e is TimeoutException) {
        errorMessage = 'Connection timed out. Please try again.';
      } else {
        errorMessage = 'An unexpected error occurred: $e';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
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