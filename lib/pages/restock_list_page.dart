// lib/pages/restock_list_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'restock_details_page.dart';

class RestockListPage extends StatefulWidget {
  const RestockListPage({super.key});

  @override
  State<RestockListPage> createState() => _RestockListPageState();
}

class _RestockListPageState extends State<RestockListPage> {
  List<dynamic> _receipts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.restockList),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _receipts = body['data'] ?? []);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _viewDetails(String receiptId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RestockDetailsPage(receiptId: receiptId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Stock Receipts'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReceipts,
              child: _receipts.isEmpty
                  ? const Center(child: Text('No receipts found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _receipts.length,
                      itemBuilder: (context, i) {
                        final r = _receipts[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(r['supplier'] ?? 'No Supplier'),
                            subtitle: Text('Invoice: ${r['invoice_number'] ?? 'N/A'} • Date: ${r['created_at'].toString().split('T')[0]}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _viewDetails(r['id'].toString()),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}