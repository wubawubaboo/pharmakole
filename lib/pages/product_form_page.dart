import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class ProductFormPage extends StatefulWidget {
  final Map<String, dynamic>? product;
  const ProductFormPage({super.key, this.product});

  bool get isEditing => product != null;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late TextEditingController _name;
  late TextEditingController _category;
  late TextEditingController _quantity;
  late TextEditingController _unitPrice;
  late TextEditingController _purchasePrice;
  late TextEditingController _supplier;
  late TextEditingController _earliestExpiryDate;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?['name'] ?? '');
    _category = TextEditingController(text: p?['category'] ?? '');
    _quantity = TextEditingController(text: p?['quantity']?.toString() ?? '0');
    _unitPrice = TextEditingController(text: p?['unit_price']?.toString() ?? '0.00');
    _purchasePrice = TextEditingController(text: p?['purchase_price']?.toString() ?? '0.00');
    _supplier = TextEditingController(text: p?['supplier'] ?? '');
    _earliestExpiryDate = TextEditingController(text: p?['earliest_expiry_date'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _purchasePrice.dispose();
    _supplier.dispose();
    _earliestExpiryDate.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);

    final payload = {
      'id': widget.product?['id'],
      'name': _name.text,
      'category': _category.text,
      'unit_price': double.tryParse(_unitPrice.text) ?? 0.0,
      'purchase_price': double.tryParse(_purchasePrice.text) ?? 0.0,
      'supplier': _supplier.text,
    };

    try {
      final url = widget.isEditing ? ApiConfig.inventoryUpdate : ApiConfig.inventoryCreate;
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product ${widget.isEditing ? 'updated' : 'created'}!'))
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${res.body}')));
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'Managed by Restocking and Sales',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') == null) ? 'Must be a number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitPrice,
                decoration: const InputDecoration(labelText: 'Unit Price (e.g., 10.50)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Must be a decimal' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchasePrice,
                decoration: const InputDecoration(labelText: 'Purchase Price (e.g., 5.25)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Must be a decimal' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplier,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _earliestExpiryDate,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Earliest Expiry Date (YYYY-MM-DD)',
                  hintText: 'Managed by Restocking',
                ),
              ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveProduct,
                      child: const Text('Save Product'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}