import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class ProductBatchEditorPage extends StatefulWidget {
  final String productId;
  final String productName;

  const ProductBatchEditorPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProductBatchEditorPage> createState() => _ProductBatchEditorPageState();
}

class _ProductBatchEditorPageState extends State<ProductBatchEditorPage> {
  List<dynamic> _batches = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  Future<void> _fetchBatches() async {
    final messenger = ScaffoldMessenger.of(context); // capture synchronously
    setState(() => _loading = true);
    try {
      final url = Uri.parse('${ApiConfig.inventoryListBatches}?product_id=${widget.productId}');
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _batches = body['data'] ?? []);
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Failed to load batches: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateBatch(String batchId, String newQty, String newExpiry) async {
    final messenger = ScaffoldMessenger.of(context); // capture synchronously
    try {
      final payload = {
        'batch_id': batchId,
        'quantity': int.tryParse(newQty) ?? 0,
        'expiry_date': newExpiry.isEmpty ? null : newExpiry,
      };

      final res = await http.post(
        Uri.parse(ApiConfig.inventoryUpdateBatch),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        messenger.showSnackBar(const SnackBar(content: Text('Batch updated!')));
        await _fetchBatches();
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Failed to update: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteBatch(String batchId) async {
    final messenger = ScaffoldMessenger.of(context); // capture synchronously
    try {
      final payload = {'batch_id': batchId};
      final res = await http.post(
        Uri.parse(ApiConfig.inventoryDeleteBatch),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        messenger.showSnackBar(const SnackBar(content: Text('Batch deleted!')));
        await _fetchBatches(); // Refresh list
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Failed to delete: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showEditDialog(Map<String, dynamic> batch) {
    final qtyController = TextEditingController(text: batch['quantity']?.toString() ?? '0');
    final expiryController = TextEditingController(text: batch['expiry_date'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Batch (ID: ${batch['id']})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
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
          TextButton(
            onPressed: () async {
              // capture navigator for this dialog synchronously to avoid using ctx after await
              final parentNavigator = Navigator.of(ctx);

              final bool? confirm = await showDialog<bool>(
                context: ctx,
                builder: (alertCtx) => AlertDialog(
                  title: const Text('Are you sure?'),
                  content: const Text('Do you want to permanently delete this batch?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(alertCtx).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(alertCtx).pop(true), child: const Text('Delete')),
                  ],
                ),
              );

              if (confirm == true) {
                if (mounted) parentNavigator.pop();
                await _deleteBatch(batch['id'].toString());
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateBatch(batch['id'].toString(), qtyController.text, expiryController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Batches for ${widget.productName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchBatches,
              child: _batches.isEmpty
                  ? const Center(child: Text('No batches found for this product.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _batches.length,
                      itemBuilder: (context, i) {
                        final b = _batches[i];
                        final expiry = b['expiry_date'] ?? 'No Expiry';
                        final purchasePrice = double.tryParse(b['purchase_price_at_time'].toString()) ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('Quantity: ${b['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Expires: $expiry\nCost: ₱${purchasePrice.toStringAsFixed(2)} • Received: ${b['received_at'].split(' ')[0]}'),
                            trailing: const Icon(Icons.edit_outlined),
                            isThreeLine: true,
                            onTap: () => _showEditDialog(b),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}