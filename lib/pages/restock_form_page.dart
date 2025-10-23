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
  // --- MODIFICATION: Removed supplier controller
  // final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  // --- NEW STATE for suppliers dropdown ---
  Map<String, dynamic>? _selectedSupplier;
  List<Map<String, dynamic>> _suppliers = [];
  bool _suppliersLoading = false;
  // --- End of NEW STATE ---

  // --- NEW: Function to fetch suppliers ---
  Future<void> _fetchSuppliers() async {
    setState(() => _suppliersLoading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.suppliersList), //
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _suppliers = List<Map<String, dynamic>>.from(body['data'] ?? []);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load suppliers: ${res.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading suppliers: $e')));
    } finally {
      if (mounted) setState(() => _suppliersLoading = false);
    }
  }
  // --- End of NEW function ---

  @override
  void initState() {
    super.initState();
    _fetchSuppliers(); // --- NEW: Call fetch suppliers on init ---
  }

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
    // --- MODIFICATION: Check selected supplier object ---
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier name is required.')));
      return;
    }
    // --- End of MODIFICATION ---

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item.')));
      return;
    }

    setState(() => _loading = true);

    final payload = {
      // --- MODIFICATION: Use name from selected supplier map ---
      'supplier': _selectedSupplier!['name'],
      // --- End of MODIFICATION ---
      'invoice_number': _invoiceController.text,
      'items': _items,
    };

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.restockReceive), //
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
                      // --- MODIFICATION: Replaced TextField with DropdownButtonFormField ---
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedSupplier,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Supplier Name',
                          suffixIcon: _suppliersLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        items: _suppliers.map((supplier) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: supplier,
                            child: Text(supplier['name'] ?? 'Unknown Supplier'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSupplier = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a supplier' : null,
                      ),
                      // --- End of MODIFICATION ---
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