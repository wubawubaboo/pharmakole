// lib/pages/staff_list_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'staff_form_page.dart';

class StaffListPage extends StatefulWidget {
  const StaffListPage({super.key});

  @override
  State<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends State<StaffListPage> {
  List<dynamic> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.usersList),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _users = body['data'] ?? []);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load users: ${res.body}')));
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

  void _editUser(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StaffFormPage(user: user)),
    ).then((_) => _fetchUsers()); // Refresh list on return
  }

  void _addUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StaffFormPage()),
    ).then((_) => _fetchUsers()); // Refresh list on return
  }

  Future<void> _deleteUser(String id) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this user?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.usersDelete),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode({'id': id}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
        _fetchUsers(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        tooltip: 'Add Staff',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _users.length,
                itemBuilder: (context, i) {
                  final user = _users[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(user['full_name'] ?? ''),
                      subtitle: Text(user['username'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(label: Text(user['role'] ?? 'staff')),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                            onPressed: () => _deleteUser(user['id'].toString()),
                          ),
                        ],
                      ),
                      onTap: () => _editUser(user),
                    ),
                  );
                },
              ),
            ),
    );
  }
}