import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> _items = [];
  bool _loading = false;
  final String url = ApiConfig.inventoryList;

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(url), headers: {'X-API-KEY': 'local-dev-key'});
      
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        
        // --- FIX: Robustly parse the JSON response ---
        if (body is Map<String, dynamic> && body.containsKey('data') && body['data'] is List) {
          // This is the expected format: {"data": [...]}
          final list = body['data'];
          setState(() => _items = List<dynamic>.from(list));
        } else if (body is List) {
          // This handles cases where the API might just return a list: [...]
          setState(() => _items = List<dynamic>.from(body));
        } else {
          // The format is unexpected, show an error
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Received unexpected data from server.')));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load inventory: ${res.statusCode}')));
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
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetch,
      color: Theme.of(context).colorScheme.primary,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
            ? const Center(child: Text("No inventory data found."))
            : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final it = _items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      it['name'] ?? 'Unknown Product',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Qty: ${it['quantity'] ?? 0}  •  Category: ${it['category'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Text(
                      '₱${(double.tryParse(it['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
