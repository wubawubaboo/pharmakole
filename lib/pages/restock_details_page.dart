import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class RestockDetailsPage extends StatefulWidget {
  final String receiptId;
  const RestockDetailsPage({super.key, required this.receiptId});

  @override
  State<RestockDetailsPage> createState() => _RestockDetailsPageState();
}

class _RestockDetailsPageState extends State<RestockDetailsPage> {
  Map<String, dynamic>? _receiptData;
  List<dynamic> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse('${ApiConfig.restockDetails}?id=${widget.receiptId}');
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _receiptData = body['receipt'];
          _items = body['items'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt #${widget.receiptId}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _receiptData == null
              ? const Center(child: Text('Receipt not found.'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _receiptData!['supplier'] ?? '',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text('Invoice: ${_receiptData!['invoice_number'] ?? 'N/A'}'),
                          Text('Date: ${_receiptData!['created_at'].toString().split('T')[0]}'),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          return ListTile(
                            title: Text(item['product_name'] ?? 'Unknown Item'),
                            subtitle: Text('Qty: ${item['quantity_received']}'),
                            trailing: Text('Cost: ₱${(double.tryParse(item['purchase_price_at_time'].toString()) ?? 0.0).toStringAsFixed(2)}'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}