import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'home_page.dart';
import '../api_config.dart';
import '../cart_service.dart';

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
  final _cartService = CartService();

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse(loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _usernameController.text,
            'password': _passwordController.text
          })).timeout(const Duration(seconds: 10));

      setState(() => _loading = false);

      if (res.statusCode == 200) {
        final jsonBody = jsonDecode(res.body);
        final user = jsonBody['user'] ?? {'full_name': 'staff'};
        
        _cartService.setUser(Map<String, dynamic>.from(user));

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      setState(() => _loading = false);
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'Could not connect to server. Check IP and network.';
      } else if (e is TimeoutException) {
        errorMessage = 'Connection timed out. Please try again.';
      } else {
        errorMessage = 'An unexpected error occurred: $e';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.local_pharmacy,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'PHARMAKOLE POS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('Login'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}