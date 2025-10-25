import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api_config.dart';

enum ProductSearchMode {
  simpleSelect,
  restockEntry,
}

class ProductSearchPage extends StatefulWidget {
  final ProductSearchMode mode;
  const ProductSearchPage({super.key, required this.mode});

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  List<dynamic> _products = [];
  bool _loading = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(() {
      _fetchProducts(query: _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({String query = ''}) async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse('${ApiConfig.inventoryList}?q=$query');
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _products = body['data'] ?? []);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Server returned ${res.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _fetchProducts(query: query),
            textColor: Colors.white,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onProductTap(Map<String, dynamic> product) {
    if (widget.mode == ProductSearchMode.simpleSelect) {
      Navigator.of(context).pop(product);
    } else {
      _showRestockDialog(product);
    }
  }

  void _showRestockDialog(Map<String, dynamic> product) {
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: (product['purchase_price'] ?? '0.00').toString());
    final expiryController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity Received'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Purchase Price (per unit)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: expiryController,
              decoration: const InputDecoration(
                labelText: 'Expiry Date (YYYY-MM-DD)',
                hintText: 'Leave blank if none',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final itemData = {
                'product_id': product['id'],
                'name': product['name'],
                'quantity': int.tryParse(qtyController.text) ?? 0,
                'purchase_price': double.tryParse(priceController.text) ?? 0.0,
                'expiry_date': expiryController.text.isEmpty ? null : expiryController.text,
              };
              
              if (itemData['quantity'] == 0) return;

              Navigator.of(ctx).pop(); 
              Navigator.of(context).pop(itemData);
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == ProductSearchMode.simpleSelect ? 'Find Product' : 'Find Product to Add'),
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _products.length,
                    itemBuilder: (context, i) {
                      final p = _products[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(p['name'] ?? ''),
                          subtitle: Text('Current Qty: ${p['quantity']}'),
                          trailing: Text('₱${(double.tryParse(p['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}'),
                          onTap: () => _onProductTap(p),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}