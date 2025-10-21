// lib/pages/profit_report_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  List<dynamic> _sales = [];
  bool _loading = false;
  DateTimeRange? _range;

  double _totalRevenue = 0.0;
  double _totalCost = 0.0;
  double _totalProfit = 0.0;

  @override
  void initState() {
    super.initState();
    // Default to today
    final now = DateTime.now();
    _range = DateTimeRange(start: now, end: now);
    _fetchReport();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchReport() async {
    if (_range == null) return;

    setState(() => _loading = true);
    
    final start = _formatDate(_range!.start);
    final end = _formatDate(_range!.end);

    try {
      final url = '${ApiConfig.reportsProfitLoss}?start=$start&end=$end';
      final res = await http.get(Uri.parse(url), headers: {'X-API-KEY': 'local-dev-key'});
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = List<dynamic>.from(body['profitloss'] ?? []);
        
        double tempRevenue = 0.0;
        double tempCost = 0.0;

        for (var sale in list) {
          tempRevenue += double.tryParse(sale['total_amount'].toString()) ?? 0.0;
          tempCost += double.tryParse(sale['cost'].toString()) ?? 0.0;
        }

        setState(() {
          _sales = list;
          _totalRevenue = tempRevenue;
          _totalCost = tempCost;
          _totalProfit = tempRevenue - tempCost;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: ${res.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _fetchReport();
    }
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '₱${value.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss Report'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickRange),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Center(
                  child: Text(
                    'Showing results for: ${_formatDate(_range!.start)} to ${_formatDate(_range!.end)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildSummaryCard('Total Revenue', _totalRevenue, Colors.green),
                    const SizedBox(width: 8),
                    _buildSummaryCard('Total Cost', _totalCost, Colors.red),
                  ],
                ),
                Card(
                  color: Colors.blue[50],
                  elevation: 0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('Gross Profit', style: TextStyle(color: Colors.blue, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '₱${_totalProfit.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue[900]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? const Center(child: Text('No sales found for this period.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sales.length,
                        itemBuilder: (context, i) {
                          final s = _sales[i];
                          final revenue = double.tryParse(s['total_amount'].toString()) ?? 0.0;
                          final cost = double.tryParse(s['cost'].toString()) ?? 0.0;
                          final profit = revenue - cost;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Sale ID: ${s['id']}'),
                              subtitle: Text(
                                'Revenue: ₱${revenue.toStringAsFixed(2)} • Cost: ₱${cost.toStringAsFixed(2)}',
                              ),
                              trailing: Text(
                                'Profit: ₱${profit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: profit >= 0 ? Colors.green : Colors.red,
                                ),
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