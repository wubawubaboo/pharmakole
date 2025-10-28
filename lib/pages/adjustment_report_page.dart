import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'restock_details_page.dart';

class AdjustmentReportPage extends StatefulWidget {
  const AdjustmentReportPage({super.key});

  @override
  State<AdjustmentReportPage> createState() => _AdjustmentReportPageState();
}

class _AdjustmentReportPageState extends State<AdjustmentReportPage> {
  List<dynamic> _adjustments = [];
  List<dynamic> _filteredAdjustments = [];
  bool _loading = false;

  final _nameFilterController = TextEditingController();
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    _nameFilterController.addListener(_applyFilters);
    _fetchAdjustments();
  }

  @override
  void dispose() {
    _nameFilterController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdjustments() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.reportsAdjustments),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _adjustments = body['data'] ?? [];
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _getReceiptId(String? reason) {
    if (reason == null) return null;
    
    const prefix = 'Restock Receipt ID: ';
    if (reason.startsWith(prefix)) {
      return reason.substring(prefix.length).trim();
    }
    return null;
  }

  void _showLogDetails(Map<String, dynamic> logEntry) {
    final String reason = logEntry['reason'] ?? 'N/A';
    final String? receiptId = _getReceiptId(reason);
    final bool isRestock = receiptId != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(logEntry['product_name'] ?? 'Log Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${logEntry['product_name'] ?? 'Unknown'}'),
            Text('Date: ${logEntry['created_at'].toString().split('T')[0]}'),
            const SizedBox(height: 8),
            Text('New Quantity: ${logEntry['new_quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Reason: $reason'),
          ],
        ),
        actions: [
          if (isRestock)
            TextButton(
              child: const Text('View Full Receipt'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestockDetailsPage(receiptId: receiptId),
                  ),
                );
              },
            ),
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }


  void _applyFilters() {
    List<dynamic> filtered = List.from(_adjustments);
    

    if (_range != null) {
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
      
      filtered = filtered.where((r) {
        try {
          final date = DateTime.parse(r['created_at']);
          return !date.isBefore(start) && !date.isAfter(end);
        } catch (e) {
          return false;
        }
      }).toList();
    }
    

    final query = _nameFilterController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((r) {
        final name = (r['product_name'] ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    }
    
    setState(() {
      _filteredAdjustments = filtered;
    });
  }


  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment Log'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _nameFilterController,
              decoration: InputDecoration(
                labelText: 'Search by Product Name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _nameFilterController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _nameFilterController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Range: ${_range != null ? _formatDate(_range!.start) : '...'} to ${_range != null ? _formatDate(_range!.end) : '...'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Select Date Range',
                  onPressed: _pickRange,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchAdjustments,
                    child: _filteredAdjustments.isEmpty
                        ? const Center(child: Text('No adjustments match your filters.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredAdjustments.length,
                            itemBuilder: (context, i) {
                              final r = _filteredAdjustments[i];
                              final String reason = r['reason'] ?? 'N/A';
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(r['product_name'] ?? 'Unknown Product'),
                                  subtitle: Text(
                                      'Reason: $reason\nDate: ${r['created_at'].toString().split('T')[0]}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'New Qty: ${r['new_quantity']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0),
                                        child: Icon(Icons.chevron_right, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _showLogDetails(r);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}