import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  List<dynamic> _logs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.reportsActivity),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _logs = body['data'] ?? []);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Activity Log'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLogs,
              child: _logs.isEmpty
                  ? const Center(child: Text('No activity logs found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (context, i) {
                        final r = _logs[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            isThreeLine: true,
                            title: Text(r['action'] ?? 'UNKNOWN_ACTION'),
                            subtitle: Text(
                                '${r['details'] ?? 'No details.'}\nUser: ${r['username']} • Date: ${_formatDate(r['created_at'])}'),
                            leading: CircleAvatar(
                              child: Icon(_getIconForAction(r['action'])),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  IconData _getIconForAction(String? action) {
    switch (action) {
      case 'login_success':
        return Icons.login;
      case 'login_fail':
        return Icons.warning;
      case 'create_user':
        return Icons.person_add;
      case 'update_user':
        return Icons.person;
      case 'delete_user':
        return Icons.person_remove;
      case 'create_product':
        return Icons.add_box;
      case 'update_product':
        return Icons.edit;
      case 'delete_product':
        return Icons.delete;
      case 'create_sale':
        return Icons.point_of_sale;
      case 'adjust_stock':
        return Icons.edit_note;
      default:
        return Icons.history;
    }
  }
}