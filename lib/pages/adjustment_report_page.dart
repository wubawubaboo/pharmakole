import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class AdjustmentReportPage extends StatefulWidget {
  const AdjustmentReportPage({super.key});

  @override
  State<AdjustmentReportPage> createState() => _AdjustmentReportPageState();
}

class _AdjustmentReportPageState extends State<AdjustmentReportPage> {
  List<dynamic> _adjustments = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchAdjustments();
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
        setState(() => _adjustments = body['data'] ?? []);
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
        title: const Text('Stock Adjustment Log'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAdjustments,
              child: _adjustments.isEmpty
                  ? const Center(child: Text('No adjustments found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _adjustments.length,
                      itemBuilder: (context, i) {
                        final r = _adjustments[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(r['product_name'] ?? 'Unknown Product'),
                            subtitle: Text(
                                'Reason: ${r['reason'] ?? 'N/A'}\nDate: ${r['created_at'].toString().split('T')[0]}'),
                            trailing: Text(
                              'New Qty: ${r['new_quantity']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}