import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'inventory_alerts_page.dart';
import 'adjustment_report_page.dart';

import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({super.key});

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  bool _loading = false;
  
  // Summary Counts
  int _lowStockCount = 0;
  int _nearExpiryCount = 0;
  
  // Data Lists
  List<dynamic> _lowStockItems = [];
  List<dynamic> _nearExpiryItems = [];
  List<dynamic> _allMovements = []; // All movements from server
  List<dynamic> _filteredMovements = []; // Movements filtered by date

  DateTimeRange? _range;

  // --- NEW: State for full export ---
  bool _isExportingFullList = false;
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
    _fetchData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);

    await Future.wait([
      _fetchSummaryCounts(),
      _fetchLowStock(),
      _fetchNearExpiry(),
      _fetchAllAdjustments(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchSummaryCounts() async {
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
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load summary: ${res.body}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _fetchLowStock() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.inventoryLowStock),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _lowStockItems = body['low_stock'] ?? []);
      }
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> _fetchNearExpiry() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.inventoryNearExpiry),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _nearExpiryItems = body['near_expiry'] ?? []);
      }
    } catch (e) {
      // Fail silently
    }
  }
  
  Future<void> _fetchAllAdjustments() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.reportsAdjustments),
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _allMovements = body['data'] ?? [];
          _applyDateFilter(); // Apply the default filter
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load movements: ${res.body}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading movements: $e')));
      }
    }
  }
  
  void _applyDateFilter() {
    if (_range == null) {
      setState(() => _filteredMovements = _allMovements);
      return;
    }

    final start = DateTime(
        _range!.start.year, _range!.start.month, _range!.start.day, 0, 0, 0);
    final end = DateTime(
        _range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);

    final filtered = _allMovements.where((r) {
      try {
        final date = DateTime.parse(r['created_at']);
        return !date.isBefore(start) && !date.isAfter(end);
      } catch (e) {
        return false;
      }
    }).toList();

    setState(() => _filteredMovements = filtered);
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
        _applyDateFilter();
      });
    }
  }

  void _goToAlerts(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InventoryAlertsPage(alertType: type)),
    ).then((_) => _fetchData());
  }

  void _goToAdjustments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdjustmentReportPage()),
    ).then((_) => _fetchData());
  }

  // --- MODIFIED: Renamed to export SUMMARY ---
  Future<void> _exportSummaryPDF() async {
    final pdf = pw.Document();
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final header = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
    final title = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
    
    final filteredMovements = _filteredMovements; 

    pdf.addPage(pw.MultiPage(
      build: (ctx) => [
        pw.Text('Inventory Summary Report', style: header),
        pw.Text('Report Date: ${_formatDate(DateTime.now())}'),
        pw.Divider(height: 16),
        pw.Text('Alerts (As of Today)', style: title),
        pw.SizedBox(height: 4),
        pw.Text('Low Stock Items: $_lowStockCount'),
        pw.Text('Near Expiry Items: $_nearExpiryCount'),
        pw.SizedBox(height: 16),
        pw.Text('Low Stock Items (${_lowStockItems.length})', style: title),
        pw.SizedBox(height: 4),
        _lowStockItems.isEmpty
            ? pw.Text('No items to report.')
            : pw.TableHelper.fromTextArray(
                headers: ['Product', 'Remaining Qty', 'Price'],
                data: _lowStockItems
                    .map((item) => [
                          item['name'] ?? 'Unknown',
                          item['quantity'].toString(),
                          '₱${(double.tryParse(item['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                        ])
                    .toList(),
              ),
        pw.SizedBox(height: 16),
        pw.Text('Near Expiry Items (${_nearExpiryItems.length})', style: title),
        pw.SizedBox(height: 4),
        _nearExpiryItems.isEmpty
            ? pw.Text('No items to report.')
            : pw.TableHelper.fromTextArray(
                headers: ['Product', 'Expiry Date', 'Price'],
                data: _nearExpiryItems
                    .map((item) => [
                          item['name'] ?? 'Unknown',
                          item['earliest_expiry_date'] ?? 'N/A',
                          '₱${(double.tryParse(item['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                        ])
                    .toList(),
              ),
        pw.SizedBox(height: 16),
        
        pw.Text(
          'Stock Movements (${_range != null ? _formatDate(_range!.start) : ''} to ${_range != null ? _formatDate(_range!.end) : ''})',
          style: title,
        ),
        pw.SizedBox(height: 4),
        filteredMovements.isEmpty
            ? pw.Text('No movements in selected range.')
            : pw.TableHelper.fromTextArray(
                headers: ['Date', 'Product', 'Reason', 'New Qty'],
                data: filteredMovements
                    .map((r) {
                      final date = DateTime.tryParse(r['created_at'] ?? '');
                      return [
                        date != null ? _formatDate(date) : (r['created_at'] ?? '').toString().split('T')[0],
                        r['product_name'] ?? 'Unknown Product',
                        r['reason'] ?? 'N/A',
                        r['new_quantity'].toString(),
                      ];
                    })
                    .toList(),
              ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- MODIFIED: Renamed to export SUMMARY ---
  Future<void> _exportSummaryCSV() async {
    final rows = <List<dynamic>>[];

    rows.add(['Inventory Summary Report']);
    rows.add(['Report Date:', _formatDate(DateTime.now())]);
    rows.add([]);
    rows.add(['Alerts (As of Today)']);
    rows.add(['Low Stock Items Count', _lowStockCount]);
    rows.add(['Near Expiry Items Count', _nearExpiryCount]);
    rows.add([]);

    rows.add(['Low Stock Items']);
    rows.add(['Product', 'Remaining Qty', 'Price']);
    for (final item in _lowStockItems) {
      rows.add([
        item['name'] ?? 'Unknown',
        item['quantity'].toString(),
        (double.tryParse(item['unit_price'].toString()) ?? 0.0)
            .toStringAsFixed(2),
      ]);
    }
    rows.add([]);

    rows.add(['Near Expiry Items']);
    rows.add(['Product', 'Expiry Date', 'Price']);
    for (final item in _nearExpiryItems) {
      rows.add([
        item['name'] ?? 'Unknown',
        item['earliest_expiry_date'] ?? 'N/A',
        (double.tryParse(item['unit_price'].toString()) ?? 0.0)
            .toStringAsFixed(2),
      ]);
    }
    rows.add([]);

    rows.add([
      'Stock Movements',
      'From:',
      _range != null ? _formatDate(_range!.start) : 'N/A',
      'To:',
      _range != null ? _formatDate(_range!.end) : 'N/A'
    ]);
    rows.add(['Date', 'Product', 'Reason', 'New Qty']);
    for (final r in _filteredMovements) {
       final date = DateTime.tryParse(r['created_at'] ?? '');
      rows.add([
        date != null ? _formatDate(date) : (r['created_at'] ?? '').toString().split('T')[0],
        r['product_name'] ?? 'Unknown Product',
        r['reason'] ?? 'N/A',
        r['new_quantity'].toString(),
      ]);
    }

    final csvStr = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/inventory_summary_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvStr);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('CSV saved to: ${file.path}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ));
    }
  }

  // --- NEW: Helper function to build section headers ---
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // --- NEW: Function to fetch and export the FULL inventory PDF ---
  Future<void> _exportFullInventoryPDF() async {
    setState(() => _isExportingFullList = true);
    List<dynamic> itemsToExport = [];
    
    try {
      // 1. Fetch full list
      final url = Uri.parse(ApiConfig.inventoryList);
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        itemsToExport = jsonDecode(res.body)['data'] ?? [];
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch full inventory: ${res.body}')));
        setState(() => _isExportingFullList = false);
        return;
      }
      
      // 2. Build PDF
      final pdf = pw.Document();
      final header = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
      
      pdf.addPage(pw.MultiPage(
        build: (ctx) => [
          pw.Text('Full Inventory Report', style: header),
          pw.Text('Date: ${_formatDate(DateTime.now())}'),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [
              'ID',
              'Name',
              'Category',
              'Qty',
              'Unit Price',
              'Purchase Price',
              'Supplier',
              'Expiry'
            ],
            data: itemsToExport.map((it) {
              return [
                it['id']?.toString() ?? 'N/A',
                it['name'] ?? 'Unknown',
                it['category'] ?? 'N/A',
                it['quantity']?.toString() ?? '0',
                '₱${(double.tryParse(it['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                '₱${(double.tryParse(it['purchase_price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                it['supplier'] ?? 'N/A',
                it['earliest_expiry_date'] ?? 'N/A',
              ];
            }).toList(),
          ),
        ],
      ));

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    } finally {
      if (mounted) setState(() => _isExportingFullList = false);
    }
  }

  // --- NEW: Function to fetch and export the FULL inventory CSV ---
  Future<void> _exportFullInventoryCSV() async {
    setState(() => _isExportingFullList = true);
    List<dynamic> itemsToExport = [];

    try {
      // 1. Fetch full list
      final url = Uri.parse(ApiConfig.inventoryList);
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        itemsToExport = jsonDecode(res.body)['data'] ?? [];
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch full inventory: ${res.body}')));
        setState(() => _isExportingFullList = false);
        return;
      }

      // 2. Build CSV
      final List<List<dynamic>> rows = [];
      rows.add(['Full Inventory Report']);
      rows.add(['Date:', _formatDate(DateTime.now())]);
      rows.add([]);
      
      rows.add([
        'ID',
        'Name',
        'Category',
        'Quantity',
        'Unit Price',
        'Purchase Price',
        'Supplier',
        'Earliest Expiry'
      ]);

      for (final it in itemsToExport) {
        rows.add([
          it['id']?.toString() ?? 'N/A',
          it['name'] ?? 'Unknown',
          it['category'] ?? 'N/A',
          it['quantity']?.toString() ?? '0',
          (double.tryParse(it['unit_price'].toString()) ?? 0.0).toStringAsFixed(2),
          (double.tryParse(it['purchase_price'].toString()) ?? 0.0).toStringAsFixed(2),
          it['supplier'] ?? 'N/A',
          it['earliest_expiry_date'] ?? 'N/A',
        ]);
      }

      final csvStr = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/full_inventory_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('CSV saved to: ${file.path}'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    } finally {
      if (mounted) setState(() => _isExportingFullList = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date Range for Movements',
            onPressed: _pickRange,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Summary as PDF',
            onPressed: _loading ? null : _exportSummaryPDF,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Summary as CSV',
            onPressed: _loading ? null : _exportSummaryCSV,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    color: _lowStockCount > 0 ? Colors.orange[50] : Colors.white,
                    child: ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange[700]),
                      title: Text('Low Stock Items',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900])),
                      subtitle: Text('$_lowStockCount items need restocking (current).'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _goToAlerts('low_stock'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: _nearExpiryCount > 0 ? Colors.red[50] : Colors.white,
                    child: ListTile(
                      leading: Icon(Icons.event_busy, color: Colors.red[700]),
                      title: Text('Near Expiry Items',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[900])),
                      subtitle:
                          Text('$_nearExpiryCount items expiring soon (current).'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _goToAlerts('near_expiry'),
                    ),
                  ),
                  
                  // --- NEW SECTION FOR FULL EXPORT ---
                  _buildSectionHeader(context, 'Full Inventory Export'),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isExportingFullList
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 8),
                                    Text('Fetching full inventory...'),
                                  ],
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton.icon(
                                  icon: Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.primary),
                                  label: const Text('Export PDF'),
                                  onPressed: _exportFullInventoryPDF,
                                ),
                                TextButton.icon(
                                  icon: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                                  label: const Text('Export CSV'),
                                  onPressed: _exportFullInventoryCSV,
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'Stock Movements',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Showing for: ${_range != null ? _formatDate(_range!.start) : '...'} to ${_range != null ? _formatDate(_range!.end) : '...'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const Divider(),
                  if (_filteredMovements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: Text('No stock movements found in this period.')),
                    )
                  else
                    Column(
                      children: [
                        ..._filteredMovements.map((r) {
                          return ListTile(
                            dense: true,
                            title: Text(r['product_name'] ?? 'Unknown Product'),
                            subtitle: Text(
                                'Reason: ${r['reason'] ?? 'N/A'}\nDate: ${r['created_at'].toString().split('T')[0]}'),
                            isThreeLine: true,
                            trailing: Text('New Qty: ${r['new_quantity']}'),
                          );
                        }),
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