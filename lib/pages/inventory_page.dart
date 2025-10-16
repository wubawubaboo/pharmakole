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
      setState(() => _loading = false);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // Expecting { data: [...] } or similar
        final list = body['data'] ?? body['products'] ?? body;
        setState(() => _items = List<dynamic>.from(list));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load inventory')));
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final it = _items[i];
                return Card(
                  child: ListTile(
                    title: Text(it['name'] ?? 'Unknown'),
                    subtitle: Text('Qty: ${it['quantity'] ?? 0}  •  Category: ${it['category'] ?? ''}'),
                    trailing: Text('₱${(it['unit_price'] ?? 0).toString()}'),
                  ),
                );
              },
            ),
    );
  }
}
