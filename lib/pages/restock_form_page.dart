// lib/pages/restock_form_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'product_search_page.dart';

class RestockFormPage extends StatefulWidget {
  const RestockFormPage({super.key});

  @override
  State<RestockFormPage> createState() => _RestockFormPageState();
}

class _RestockFormPageState extends State<RestockFormPage> {
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  void _addItem() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductSearchPage(mode: ProductSearchMode.restockEntry),),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _items.add(result);
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _saveReceipt() async {
    if (_supplierController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier name is required.')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item.')));
      return;
    }

    setState(() => _loading = true);

    final payload = {
      'supplier': _supplierController.text,
      'invoice_number': _invoiceController.text,
      'items': _items,
    };

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.restockReceive),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock received successfully!')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive New Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _loading ? null : _saveReceipt,
            tooltip: 'Save Receipt',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _supplierController,
                        decoration: const InputDecoration(labelText: 'Supplier Name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _invoiceController,
                        decoration: const InputDecoration(labelText: 'Invoice Number (Optional)'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('Press the "+" button to add items.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(item['name'] ?? ''),
                                subtitle: Text('Qty: ${item['quantity']} @ ₱${(item['purchase_price'] as double).toStringAsFixed(2)} each'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.red),
                                  onPressed: () => _removeItem(i),
                                ),
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