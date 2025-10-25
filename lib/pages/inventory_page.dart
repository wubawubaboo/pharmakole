import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'product_form_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> _items = [];
  bool _loading = false;
  final _searchController = TextEditingController();

  String _sortColumn = 'name';
  bool _sortAscending = true;

  Future<void> _fetch({String query = ''}) async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse('${ApiConfig.inventoryList}?q=$query');
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});
      
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
          if (body is Map<String, dynamic> && body.containsKey('data') && body['data'] is List) {
            final list = body['data'];
            setState(() {
              _items = List<dynamic>.from(list);
              _sortItems(); // <-- NEW: Sort after fetching
            });
          } 
          else if (body is List) {
             setState(() {
              _items = List<dynamic>.from(body);
              _sortItems(); // <-- NEW: Sort after fetching
            });
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

  // --- NEW: Client-side sorting logic ---
  void _sortItems() {
    _items.sort((a, b) {
      dynamic aValue = a[_sortColumn];
      dynamic bValue = b[_sortColumn];

      // Handle numeric sorting for quantity and price
      if (_sortColumn == 'quantity') {
        aValue = int.tryParse(aValue.toString()) ?? 0;
        bValue = int.tryParse(bValue.toString()) ?? 0;
      } else if (_sortColumn == 'unit_price') {
        aValue = double.tryParse(aValue.toString()) ?? 0.0;
        bValue = double.tryParse(bValue.toString()) ?? 0.0;
      }

      // Default to string comparison
      final comparison = aValue.compareTo(bValue);
      return _sortAscending ? comparison : -comparison;
    });
  }
  
  // --- NEW: Handler for when a sort chip is tapped ---
  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _sortItems();
    });
  }
  
  void _editProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormPage(product: product)),
    ).then((_) => _fetch(query: _searchController.text));
  }

  void _addProduct() {
     Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormPage()),
    ).then((_) => _fetch(query: _searchController.text));
  }

  Future<void> _deleteProduct(String id) async {
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
        _fetch(query: _searchController.text);
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
    _searchController.addListener(() {
      _fetch(query: _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- MODIFIED: Helper widget to build sort chips ---
  Widget _buildSortChip(String label, String column) {
    final bool isActive = _sortColumn == column;
    final primaryColor = Theme.of(context).colorScheme.primary; // This is Color(0xFF02367B)
    
    return ActionChip(
      avatar: isActive
          ? Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: primaryColor,
            )
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        color: isActive ? primaryColor : null,
      ),
      // --- MODIFIED LINES ---
      backgroundColor: isActive ? const Color(0x1902367B) : const Color(0xFFEEEEEE),
      shape: StadiumBorder(
        side: BorderSide(
          color: isActive ? primaryColor : const Color(0xFFBDBDBD), // Using Grey[400]
          // --- END MODIFIED LINES ---
          width: 1,
        ),
      ),
      onPressed: () => _onSort(column),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
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
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              children: [
                const Text('Sort by:', style: TextStyle(color: Colors.black54)),
                const SizedBox(width: 8),
                _buildSortChip('Name', 'name'),
                const SizedBox(width: 8),
                _buildSortChip('Quantity', 'quantity'),
                const SizedBox(width: 8),
                _buildSortChip('Price', 'unit_price'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(query: _searchController.text),
              color: Theme.of(context).colorScheme.primary,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                    ? const Center(child: Text("No inventory data found."))
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                                  onPressed: () => _deleteProduct(it['id'].toString()),
                                ),
                              ],
                            ),
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