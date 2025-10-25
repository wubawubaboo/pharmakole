import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class StaffFormPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const StaffFormPage({super.key, this.user});

  bool get isEditing => user != null;

  @override
  State<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends State<StaffFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late TextEditingController _username;
  late TextEditingController _fullName;
  late TextEditingController _password;
  String _role = 'staff';
  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _username = TextEditingController(text: u?['username'] ?? '');
    _fullName = TextEditingController(text: u?['full_name'] ?? '');
    _password = TextEditingController();
    _role = u?['role'] ?? 'staff';
  }

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final payload = {
      'id': widget.user?['id'],
      'username': _username.text,
      'full_name': _fullName.text,
      'role': _role,
      'password': _password.text.isEmpty ? null : _password.text,
    };

    if (payload['password'] == null) {
      payload.remove('password');
    }

    try {
      final url = widget.isEditing ? ApiConfig.usersUpdate : ApiConfig.usersCreate;
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${widget.isEditing ? 'updated' : 'created'}!'))
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Staff' : 'Add Staff'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'staff'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: widget.isEditing ? 'Leave blank to keep unchanged' : 'Required',
                ),
                obscureText: true,
                validator: (v) {
                  if (!widget.isEditing && (v == null || v.isEmpty)) {
                    return 'Password is required for new user';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveUser,
                      child: const Text('Save User'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}