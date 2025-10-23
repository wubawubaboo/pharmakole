// lib/pages/inventory_report_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'inventory_alerts_page.dart';
import 'adjustment_report_page.dart';

class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({super.key});

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  bool _loading = false;
  int _lowStockCount = 0;
  int _nearExpiryCount = 0;
  List<dynamic> _recentMovements = [];

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.reportsInventorySummary),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _lowStockCount = body['low_stock_count'] ?? 0;
          _nearExpiryCount = body['near_expiry_count'] ?? 0;
          _recentMovements = body['recent_movements'] ?? [];
        });
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load summary: ${res.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToAlerts(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InventoryAlertsPage(alertType: type)),
    ).then((_) => _fetchSummary()); // Refresh on return
  }

  void _goToAdjustments() {
     Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdjustmentReportPage()),
    ).then((_) => _fetchSummary()); // Refresh on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Report'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSummary,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Low Stock Card
                  Card(
                    color: _lowStockCount > 0 ? Colors.orange[50] : Colors.white,
                    child: ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange[700]),
                      title: Text('Low Stock Items', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900])),
                      subtitle: Text('$_lowStockCount items need restocking.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _goToAlerts('low_stock'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Near Expiry Card
                  Card(
                    color: _nearExpiryCount > 0 ? Colors.red[50] : Colors.white,
                    child: ListTile(
                      leading: Icon(Icons.event_busy, color: Colors.red[700]),
                      title: Text('Near Expiry Items', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[900])),
                      subtitle: Text('$_nearExpiryCount items are expiring soon.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _goToAlerts('near_expiry'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Movements
                  Text(
                    'Recent Stock Movements',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  if (_recentMovements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('No recent stock movements found.')),
                    )
                  else
                    Column(
                      children: [
                        ..._recentMovements.map((r) {
                          return ListTile(
                            dense: true,
                            title: Text(r['product_name'] ?? 'Unknown Product'),
                            subtitle: Text('Reason: ${r['reason'] ?? 'N/A'}'),
                            trailing: Text('New Qty: ${r['new_quantity']}'),
                          );
                        }).toList(),
                        TextButton(
                          onPressed: _goToAdjustments,
                          child: const Text('View All Movements'),
                        )
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}