import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'product_form_page.dart'; // <-- NEW

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> _items = [];
  bool _loading = false;
  // --- NEW: Controller for search ---
  final _searchController = TextEditingController();

  // --- MODIFIED: Fetch now accepts a query ---
  Future<void> _fetch({String query = ''}) async {
    setState(() => _loading = true);
    try {
      // --- MODIFIED: Append query to URL ---
      final url = Uri.parse('${ApiConfig.inventoryList}?q=$query');
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});
      
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
          if (body is Map<String, dynamic> && body.containsKey('data') && body['data'] is List) {
            final list = body['data'];
            setState(() => _items = List<dynamic>.from(list));
          } 
          else if (body is List) {
            setState(() => _items = List<dynamic>.from(body));
          } 
          else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Received unexpected data from server.')));
          }
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
  
  // --- NEW: Navigate to Product Form for editing ---
  void _editProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormPage(product: product)),
    ).then((_) => _fetch(query: _searchController.text)); // Refresh list on return
  }

  // --- NEW: Navigate to Product Form for adding ---
  void _addProduct() {
     Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormPage()),
    ).then((_) => _fetch(query: _searchController.text)); // Refresh list on return
  }

  // --- NEW: Delete a product ---
  Future<void> _deleteProduct(String id) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.inventoryDelete),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode({'id': id}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
        _fetch(query: _searchController.text); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }


  @override
  void initState() {
    super.initState();
    _fetch();
    // --- NEW: Add listener to search controller ---
    _searchController.addListener(() {
      _fetch(query: _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- NEW: Add Product Button ---
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // --- NEW: Search Bar ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Products',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          // --- MODIFIED: List is now in an Expanded widget ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(query: _searchController.text),
              color: Theme.of(context).colorScheme.primary,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                    ? const Center(child: Text("No inventory data found."))
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₱${(double.tryParse(it['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                // --- NEW: Delete Button ---
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                                  onPressed: () => _deleteProduct(it['id'].toString()),
                                ),
                              ],
                            ),
                            // --- NEW: Edit on Tap ---
                            onTap: () => _editProduct(it),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}