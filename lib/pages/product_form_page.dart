import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'product_batch_editor_page.dart';

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

  void _manageBatches() {
    if (!widget.isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the product before managing batches.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductBatchEditorPage(
          productId: widget.product!['id'].toString(),
          productName: widget.product!['name'] ?? 'Product',
        ),
      ),
    ).then((_) async {
      await _refreshProduct();
    });
  }

  Future<void> _refreshProduct() async {
    if (!widget.isEditing) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);

    final id = widget.product!['id'].toString();

    try {
      final uri = Uri.parse('${ApiConfig.inventoryList}/$id');
      final res = await http.get(uri, headers: {'X-API-KEY': 'local-dev-key'});

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        final updated =
            (body is Map && body.containsKey('data')) ? body['data'] : body;

        if (updated is Map<String, dynamic>) {
          setState(() {
            _name.text = updated['name']?.toString() ?? _name.text;
            _category.text = updated['category']?.toString() ?? _category.text;
            _quantity.text = updated['quantity']?.toString() ?? _quantity.text;
            _unitPrice.text = updated['unit_price']?.toString() ?? _unitPrice.text;
            _purchasePrice.text =
                updated['purchase_price']?.toString() ?? _purchasePrice.text;
            _supplier.text = updated['supplier']?.toString() ?? _supplier.text;
            _earliestExpiryDate.text =
                updated['earliest_expiry_date']?.toString() ?? _earliestExpiryDate.text;
          });
        } else {
          messenger.showSnackBar(const SnackBar(content: Text('Unexpected product data')));
        }
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Failed to refresh: ${res.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error refreshing product: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                  labelText: 'Total Quantity',
                  hintText: 'Managed by stock batches',
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
                  hintText: 'Managed by stock batches',
                ),
              ),
              const SizedBox(height: 24),
              if (widget.isEditing) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manage Stock Batches'),
                  onPressed: _manageBatches,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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