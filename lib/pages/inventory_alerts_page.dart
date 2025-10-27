import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class InventoryAlertsPage extends StatefulWidget {
  final String alertType;
  const InventoryAlertsPage({super.key, required this.alertType});

  @override
  State<InventoryAlertsPage> createState() => _InventoryAlertsPageState();
}

class _InventoryAlertsPageState extends State<InventoryAlertsPage> {
  List<dynamic> _items = [];
  bool _loading = false;
  String _title = '';
  String _apiKey = '';
  String _url = '';

  @override
  void initState() {
    super.initState();
    if (widget.alertType == 'low_stock') {
      _title = 'Low Stock Report';
      _apiKey = 'low_stock';
      _url = ApiConfig.inventoryLowStock;
    } else {
      _title = 'Near Expiry Report';
      _apiKey = 'near_expiry';
      _url = ApiConfig.inventoryNearExpiry;
    }
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(_url),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _items = body[_apiKey] ?? []);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load report: ${res.body}')));
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
        title: Text(_title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAlerts,
              child: _items.isEmpty
                  ? const Center(child: Text('No items to report.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        String subtitle;
                        if (widget.alertType == 'low_stock') {
                          subtitle = 'Quantity remaining: ${item['quantity']}';
                        } else {
                          subtitle = 'Expires on: ${item['earliest_expiry_date']}';
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item['name'] ?? 'Unknown'),
                            subtitle: Text(subtitle),
                            trailing: Text(
                              '₱${(double.tryParse(item['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
