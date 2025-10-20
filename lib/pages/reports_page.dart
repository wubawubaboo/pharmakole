// lib/pages/reports_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:pharmakole_mobile/api_config.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'product_search_selector_page.dart'; // <-- IMPORT NEW PAGE

// Enum to manage chart grouping
enum ChartGroupType { hour, day, week, month }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Holds individual transactions from API
  List<Map<String, dynamic>> _records = [];
  // Holds data grouped for the chart
  List<Map<String, dynamic>> _chartData = [];

  bool _loading = false;
  DateTimeRange? _range;
  bool _showBar = true;
  double _grandTotal = 0.0;
  ChartGroupType _groupType = ChartGroupType.day;

  // --- NEW: State for product filter ---
  Map<String, dynamic>? _selectedProduct;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // --- UPDATED: _fetch to use new endpoint and filters ---
  Future<void> _fetch() async {
    setState(() => _loading = true);
    
    // Default to today if no range is set
    final now = DateTime.now();
    final start = _range?.start ?? now;
    final end = _range?.end ?? now;

    try {
      String url = '${ApiConfig.reportsTransactions}?start=${_formatDate(start)}&end=${_formatDate(end)}';
      
      // Add product ID to filter if one is selected
      if (_selectedProduct != null) {
        url += '&product_id=${_selectedProduct!['id']}';
      }
      
      final res = await http.get(Uri.parse(url), headers: {'X-API-KEY': 'local-dev-key'});
      
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(body['data'] ?? []);

        setState(() {
          _records = list.map((e) {
            // Parse all fields, provide defaults
            return {
              'created_at': e['created_at'] ?? DateTime.now().toIso8601String(),
              'cashier_name': e['cashier_name'] ?? 'N/A',
              'total_price': double.tryParse(e['total_price'].toString()) ?? 0.0,
              'quantity': int.tryParse(e['quantity'].toString()) ?? 0,
              'product_name': e['product_name'] ?? 'Unknown'
            };
          }).toList();
          
          // Calculate grand total
          _grandTotal = _records.fold(0.0, (s, r) => s + (r['total_price'] as double));
          
          // Process data for the chart
          _updateChartData();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: ${res.statusCode}')));
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- NEW: Date range picker logic ---
  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context, 
      firstDate: DateTime(2020), 
      lastDate: DateTime.now()
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _fetch(); // Refetch data with new range
    }
  }

  // --- NEW: Product picker logic ---
  Future<void> _pickProduct() async {
    final product = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductSearchSelectorPage()),
    );
    if (product != null) {
      setState(() => _selectedProduct = product);
      await _fetch(); // Refetch data with product filter
    }
  }

  // --- NEW: Clear product filter ---
  void _clearProductFilter() {
    setState(() => _selectedProduct = null);
    _fetch(); // Refetch without product filter
  }

  // Helper to get the start of the week (Sunday)
  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  // --- UPDATED: Chart grouping logic ---
  void _updateChartData() {
    final Map<DateTime, double> map = {};
    int duration = 0;

    if (_range != null) {
      duration = _range!.end.difference(_range!.start).inDays;
    }

    // 1. Determine group type based on user request
    if (_range == null || duration == 0) { // Single day
      _groupType = ChartGroupType.hour;
    } else if (duration <= 7) { // 2-7 days
      _groupType = ChartGroupType.day;
    } else if (duration <= 90) { // Up to 3 months
      _groupType = ChartGroupType.week;
    } else { // Over 3 months
      _groupType = ChartGroupType.month;
    }

    // 2. Group data by the determined type
    for (final r in _records) {
      final total = r['total_price'] as double;
      final date = DateTime.parse(r['created_at']);
      DateTime key;

      switch (_groupType) {
        case ChartGroupType.hour:
          key = DateTime(date.year, date.month, date.day, date.hour);
          break;
        case ChartGroupType.day:
          key = DateTime(date.year, date.month, date.day);
          break;
        case ChartGroupType.week:
          key = _getStartOfWeek(date);
          break;
        case ChartGroupType.month:
          key = DateTime(date.year, date.month, 1);
          break;
      }
      map[key] = (map[key] ?? 0) + total;
    }

    // 3. Convert map to sorted list
    final list = map.entries.map((e) => {'date': e.key, 'total': e.value}).toList();
    list.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    _chartData = list;
  }

  // Helper to format chart titles
  String _getChartTitle(DateTime date, ChartGroupType type) {
    switch (type) {
      case ChartGroupType.hour:
        return '${date.hour.toString().padLeft(2, '0')}:00';
      case ChartGroupType.day:
        return _formatDate(date);
      case ChartGroupType.week:
        return 'Wk of ${_formatDate(date)}';
      case ChartGroupType.month:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
  }

  // --- UPDATED: Chart widget (now uses _chartData) ---
  Widget _chartWidget() {
    if (_chartData.isEmpty) return const Center(child: Text('No data for selected range'));

    final maxY = _chartData.map((g) => g['total'] as double).reduce((a, b) => a > b ? a : b) * 1.2;
    
    if (_showBar) {
      return BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: List.generate(
            _chartData.length, (i) => BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: _chartData[i]['total'] as double, color: Colors.blue),
            ]),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < _chartData.length) {
                  final date = _chartData[idx]['date'] as DateTime;
                  return Text(_getChartTitle(date, _groupType), style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            )),
          ),
        ),
      );
    } else {
      final spots = List.generate(_chartData.length, (i) => FlSpot(i.toDouble(), _chartData[i]['total'] as double));
      return LineChart(
        LineChartData(
          maxY: maxY,
          lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Colors.blue)],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < _chartData.length) {
                  final date = _chartData[idx]['date'] as DateTime;
                  return Text(_getChartTitle(date, _groupType), style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            )),
          ),
        ),
      );
    }
  }

  // --- UPDATED: Exports now use _chartData (grouped data) ---
  Future<void> _exportPDF() async {
    if (_chartData.isEmpty) return;
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (ctx) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Sales Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (_range != null) pw.Text('Range: ${_formatDate(_range!.start)} - ${_formatDate(_range!.end)}'),
        if (_selectedProduct != null) pw.Text('Product: ${_selectedProduct!['name']}'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(), 
          children: [
            pw.TableRow(children: [
              pw.Text('Date/Period', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Total Sales', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ]),
            ..._chartData.map((g) => pw.TableRow(children: [
              pw.Text(_getChartTitle(g['date'], _groupType)),
              pw.Text((g['total'] as double).toStringAsFixed(2)),
            ])),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('Grand Total: ₱${_grandTotal.toStringAsFixed(2)}'),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportCSV() async {
    if (_chartData.isEmpty) return;
    final rows = <List<dynamic>>[];
    rows.add(['Date/Period', 'Total Sales']);
    for (final g in _chartData) {
      rows.add([_getChartTitle(g['date'], _groupType), (g['total'] as double).toStringAsFixed(2)]);
    }
    rows.add(['Grand Total', _grandTotal.toStringAsFixed(2)]);
    final csvStr = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvStr);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV saved to: ${file.path}')));
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: Icon(_selectedProduct == null ? Icons.filter_list : Icons.filter_list_off),
            tooltip: 'Filter by Product',
            onPressed: _selectedProduct == null ? _pickProduct : _clearProductFilter,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickRange),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportPDF),
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportCSV),
          IconButton(icon: Icon(_showBar ? Icons.show_chart : Icons.bar_chart), onPressed: () => setState(() => _showBar = !_showBar)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                // --- NEW: Show current filters ---
                if (_range != null)
                  Text('Range: ${_formatDate(_range!.start)} - ${_formatDate(_range!.end)}'),
                if (_selectedProduct != null)
                  Chip(
                    label: Text('Product: ${_selectedProduct!['name']}'),
                    onDeleted: _clearProductFilter,
                  ),
                
                const SizedBox(height: 12),
                SizedBox(height: 220, child: Card(child: Padding(padding: const EdgeInsets.all(8), child: _chartWidget()))),
                const SizedBox(height: 12),

                // --- UPDATED: List now shows individual transactions from _records ---
                Expanded(
                  child: _records.isEmpty
                      ? const Center(child: Text('No records found'))
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            return Card(
                              child: ListTile(
                                isThreeLine: true,
                                title: Text(r['product_name'] ?? 'Unknown'),
                                subtitle: Text(
                                  'Cashier: ${r['cashier_name']}\nDate: ${DateTime.parse(r['created_at']).toString().split('.')[0]}',
                                ),
                                trailing: Text(
                                  '₱${(r['total_price'] as double).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Text('Grand Total: ₱${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
    );
  }
}