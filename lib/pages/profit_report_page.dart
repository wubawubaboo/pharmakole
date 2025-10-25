// lib/pages/profit_report_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'product_search_page.dart';
import '../api_config.dart';

import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// ---

// Enum to manage chart grouping
enum ChartGroupType { hour, day, week, month }

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  bool _loading = false;
  DateTimeRange? _range;
  double _totalRevenue = 0.0;
  double _totalRestockCost = 0.0;
  double _totalCOGS = 0.0;
  double _totalProfit = 0.0;
  
  // --- NEW: Dynamic state for cards ---
  String _profitCardTitle = 'Net Cash Flow';
  String _costCardTitle = 'Total Restock Spend';
  double _costCardValue = 0.0;
  String _secondaryCostTitle = 'Total Cost of Goods (COGS)';
  double _secondaryCostValue = 0.0;
  // --- END NEW ---

  List<Map<String, dynamic>> _records = []; // Individual transactions
  List<Map<String, dynamic>> _chartData = []; // Grouped data for chart
  bool _showBar = true;
  ChartGroupType _groupType = ChartGroupType.day;
  Map<String, dynamic>? _selectedProduct;


  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now, end: now);
    _fetchData();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchData() async {
    if (_range == null) return;
    setState(() => _loading = true);

    await Future.wait([
      _fetchSummary(),
      _fetchTransactions(),
    ]);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchSummary() async {
    if (_range == null) return;
    final start = _formatDate(_range!.start);
    final end = _formatDate(_range!.end);

    try {
      String url = '${ApiConfig.reportsFinancialSummary}?start=$start&end=$end';
      if (_selectedProduct != null) {
        url += '&product_id=${_selectedProduct!['id']}';
      }
      
      final res = await http.get(Uri.parse(url), headers: {'X-API-KEY': 'local-dev-key'});
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _totalRevenue = (body['total_revenue'] as num?)?.toDouble() ?? 0.0;
          _totalRestockCost = (body['total_restock_cost'] as num?)?.toDouble() ?? 0.0;
          _totalCOGS = (body['total_cogs'] as num?)?.toDouble() ?? 0.0;

          // --- THIS IS THE CORE LOGIC CHANGE ---
          if (_selectedProduct == null) {
            // NOT filtering by product: Show Net Cash Flow
            _totalProfit = _totalRevenue - _totalRestockCost;
            _profitCardTitle = 'Net Cash Flow (Revenue - Restock)';
            _costCardTitle = 'Total Restock Spend';
            _costCardValue = _totalRestockCost;
            _secondaryCostTitle = 'Total Cost of Goods (COGS)';
            _secondaryCostValue = _totalCOGS;
          } else {
            // ARE filtering by product: Show Gross Profit
            _totalProfit = _totalRevenue - _totalCOGS;
            _profitCardTitle = 'Gross Profit (Revenue - COGS)';
            _costCardTitle = 'Total Cost of Goods (COGS)';
            _costCardValue = _totalCOGS;
            _secondaryCostTitle = 'Total Restock Spend';
            _secondaryCostValue = _totalRestockCost;
          }
          // --- END OF LOGIC CHANGE ---
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load summary: ${res.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading summary: $e')));
    }
  }

  Future<void> _fetchTransactions() async {
    if (_range == null) return;
    final start = _formatDate(_range!.start);
    final end = _formatDate(_range!.end);

    try {
      String url = '${ApiConfig.reportsTransactions}?start=$start&end=$end';
      if (_selectedProduct != null) {
        url += '&product_id=${_selectedProduct!['id']}';
      }
      
      final res = await http.get(Uri.parse(url), headers: {'X-API-KEY': 'local-dev-key'});

      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(body['data'] ?? []);

        setState(() {
          _records = list.map((e) {
            return {
              'created_at': e['created_at'] ?? DateTime.now().toIso8601String(),
              'cashier_name': e['cashier_name'] ?? 'N/A',
              'total_price': double.tryParse(e['total_price'].toString()) ?? 0.0,
              'quantity': int.tryParse(e['quantity'].toString()) ?? 0,
              'product_name': e['product_name'] ?? 'Unknown'
            };
          }).toList();
          
          _updateChartData();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load transactions: ${res.body}')));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading transactions: $e')));
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
      await _fetchData();
    }
  }
  
  Future<void> _pickProduct() async {
    final product = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductSearchPage(mode: ProductSearchMode.simpleSelect)),
    );
    if (product != null) {
      setState(() => _selectedProduct = product);
      await _fetchData();
    }
  }

  void _clearProductFilter() {
    setState(() => _selectedProduct = null);
    _fetchData();
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  void _updateChartData() {
    final Map<DateTime, double> map = {};
    int duration = 0;

    if (_range != null) {
      duration = _range!.end.difference(_range!.start).inDays;
    }

    if (_range == null || duration == 0) { // Single day
      _groupType = ChartGroupType.hour;
    } else if (duration <= 7) { // 2-7 days
      _groupType = ChartGroupType.day;
    } else if (duration <= 90) { // Up to 3 months
      _groupType = ChartGroupType.week;
    } else { // Over 3 months
      _groupType = ChartGroupType.month;
    }

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

    final list = map.entries.map((e) => {'date': e.key, 'total': e.value}).toList();
    list.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    _chartData = list;
  }

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

  Widget _chartWidget() {
    if (_chartData.isEmpty) return const Center(child: Text('No sales data for this period'));

    final maxY = _chartData.map((g) => g['total'] as double).reduce((a, b) => a > b ? a : b) * 1.2;
    
    if (_showBar) {
      return BarChart(
        BarChartData(
          maxY: maxY > 0 ? maxY : 10,
          barGroups: List.generate(
            _chartData.length, (i) => BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: _chartData[i]['total'] as double, color: Colors.blue, width: 15),
            ]),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < _chartData.length) {
                  final date = _chartData[idx]['date'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(_getChartTitle(date, _groupType), style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      );
    } else {
      final spots = List.generate(_chartData.length, (i) => FlSpot(i.toDouble(), _chartData[i]['total'] as double));
      return LineChart(
        LineChartData(
          maxY: maxY > 0 ? maxY : 10,
          lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Colors.blue, barWidth: 3)],
          titlesData: FlTitlesData(
             bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < _chartData.length) {
                  final date = _chartData[idx]['date'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(_getChartTitle(date, _groupType), style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      );
    }
  }
  
  Widget _buildSummaryCard(String title, double value, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha(25),
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

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final header = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);

    pdf.addPage(pw.MultiPage(
      build: (ctx) => [
        pw.Text('Sales & Financial Summary', style: header),
        pw.SizedBox(height: 8),
        if (_range != null)
          pw.Text('Range: ${_formatDate(_range!.start)} - ${_formatDate(_range!.end)}'),
        if (_selectedProduct != null)
          pw.Text('Product Filter: ${_selectedProduct!['name']}'),
        pw.Divider(height: 16),

        pw.Text('Financial Summary', style: bold),
        pw.SizedBox(height: 4),
        pw.Text('Total Revenue (Sales): ₱${_totalRevenue.toStringAsFixed(2)}'),
        // --- MODIFIED: Use dynamic titles from state ---
        pw.Text('$_costCardTitle: ₱${_costCardValue.toStringAsFixed(2)}'),
        pw.Text('$_profitCardTitle: ₱${_totalProfit.toStringAsFixed(2)}', style: bold),
        pw.SizedBox(height: 4),
        pw.Text('$_secondaryCostTitle: ₱${_secondaryCostValue.toStringAsFixed(2)}'),
        // --- END MODIFICATION ---
        pw.Divider(height: 16),

        pw.Text('Sales Over Time (Grouped)', style: bold),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Date/Period', 'Total Sales'],
          data: _chartData.map((g) => [
            _getChartTitle(g['date'], _groupType),
            '₱${(g['total'] as double).toStringAsFixed(2)}',
          ]).toList(),
        ),
        pw.Divider(height: 16),

        pw.Text('Individual Transactions', style: bold),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Product', 'Cashier', 'Qty', 'Total'],
          data: _records.map((r) => [
            DateTime.parse(r['created_at']).toString().split('.')[0],
            r['product_name'],
            r['cashier_name'],
            r['quantity'].toString(),
            '₱${(r['total_price'] as double).toStringAsFixed(2)}',
          ]).toList(),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportCSV() async {
    final rows = <List<dynamic>>[];
    
    // Section 1: Summary
    rows.add(['Sales & Financial Summary']);
    if (_range != null) {
      rows.add(['Range:', '${_formatDate(_range!.start)} - ${_formatDate(_range!.end)}']);
    }
    if (_selectedProduct != null) {
      rows.add(['Product Filter:', _selectedProduct!['name']]);
    }
    rows.add([]); // Spacer
    rows.add(['Summary', 'Amount']);
    // --- MODIFIED: Use dynamic titles from state ---
    rows.add(['Total Revenue (Sales)', _totalRevenue.toStringAsFixed(2)]);
    rows.add([_costCardTitle, _costCardValue.toStringAsFixed(2)]);
    rows.add([_profitCardTitle, _totalProfit.toStringAsFixed(2)]);
    rows.add([_secondaryCostTitle, _secondaryCostValue.toStringAsFixed(2)]);
    // --- END MODIFICATION ---
    rows.add([]); // Spacer

    // Section 2: Grouped Chart Data
    rows.add(['Sales Over Time (Grouped)']);
    rows.add(['Date/Period', 'Total Sales']);
    for (final g in _chartData) {
      rows.add([
        _getChartTitle(g['date'], _groupType),
        (g['total'] as double).toStringAsFixed(2)
      ]);
    }
    rows.add([]); // Spacer

    // Section 3: Individual Transactions
    rows.add(['Individual Transactions']);
    rows.add(['Date', 'Product', 'Cashier', 'Quantity', 'Total Price']);
    for (final r in _records) {
      rows.add([
        DateTime.parse(r['created_at']).toString().split('.')[0],
        r['product_name'],
        r['cashier_name'],
        r['quantity'].toString(),
        (r['total_price'] as double).toStringAsFixed(2),
      ]);
    }

    final csvStr = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/financial_summary_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvStr);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('CSV saved to: ${file.path}'),
        action: SnackBarAction(label: 'Open', onPressed: () {
        }),
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Financial Summary'),
        actions: [
          IconButton(
            icon: Icon(_selectedProduct == null ? Icons.filter_list : Icons.filter_list_off),
            tooltip: 'Filter by Product',
            onPressed: _selectedProduct == null ? _pickProduct : _clearProductFilter,
          ),
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickRange),
          IconButton(icon: Icon(_showBar ? Icons.show_chart : Icons.bar_chart), onPressed: () => setState(() => _showBar = !_showBar)),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export as PDF',
            onPressed: _exportPDF,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export as CSV',
            onPressed: _exportCSV,
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
                Center(
                  child: Text(
                    'Showing results for: ${_formatDate(_range!.start)} to ${_formatDate(_range!.end)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (_selectedProduct != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Center(
                      child: Chip(
                        label: Text('Product: ${_selectedProduct!['name']}'),
                        onDeleted: _clearProductFilter,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
          
                Row(
                  children: [
                    _buildSummaryCard('Total Revenue (Sales)', _totalRevenue, Colors.green),
                    const SizedBox(width: 8),
                    _buildSummaryCard(_costCardTitle, _costCardValue, Colors.red),
                  ],
                ),
                Card(
                  color: _totalProfit >= 0 ? Colors.blue[50] : Colors.red[50],
                  elevation: 0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            _profitCardTitle,
                            style: TextStyle(color: _totalProfit >= 0 ? Colors.blue : Colors.red, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${_totalProfit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 20, 
                              color: _totalProfit >= 0 ? Colors.blue[900] : Colors.red[900]
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // --- MODIFIED: Use dynamic secondary cost ---
                Row(
                  children: [
                    _buildSummaryCard(_secondaryCostTitle, _secondaryCostValue, Colors.orange),
                  ],
                ),
                // --- END MODIFICATION ---

                const SizedBox(height: 12),
          
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Sales Revenue Over Time", style: Theme.of(context).textTheme.titleMedium),
                ),
                SizedBox(height: 220, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: _chartWidget()))),
                const Divider(height: 24),
          
                Text("Individual Transactions", style: Theme.of(context).textTheme.titleMedium),
                if (_records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No individual transactions found.'))
                  )
                else
                  ..._records.map((r) {
                    return Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ListTile(
                        isThreeLine: true,
                        dense: true,
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
                  }),
              ],
            ),
          ),
    );
  }
}