import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = false;
  DateTimeRange? _range;
  bool _showBar = true;
  double _grandTotal = 0.0;

  final String summaryUrl = 'http://192.168.5.129/pharma/api/reports/summary';
  final String dailyUrl = 'http://192.168.5.129/pharma/api/reports/daily';


  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetch({DateTimeRange? range}) async {
    setState(() => _loading = true);
    try {
      String url = dailyUrl;
      if (range != null) {
        final s = _formatDate(range.start);
        final e = _formatDate(range.end);
        url = '$summaryUrl?start=$s&end=$e';
      }
      final res = await http.get(Uri.parse(url), headers: {'X-API-KEY': 'local-dev-key'});
      
      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);
          List<Map<String, dynamic>> list = [];
          
          if (body is Map && body.containsKey('summary')) {
            list = List<Map<String, dynamic>>.from(body['summary']);
          } else if (body is Map && body.containsKey('sales')) {
            list = List<Map<String, dynamic>>.from(body['sales']);
          } else if (body is List) {
            list = List<Map<String, dynamic>>.from(body);
          }
          
          final normalized = list.map((e) {
            final dateStr = (e['date'] ?? e['created_at'] ?? '').toString().split('T')[0];
            double total = 0.0;
            if (e.containsKey('total')) total = double.tryParse(e['total'].toString()) ?? 0;
            if (e.containsKey('total_amount')) total = double.tryParse(e['total_amount'].toString()) ?? total;
            if (e.containsKey('total_sales')) total = double.tryParse(e['total_sales'].toString()) ?? total;
            return {
              'date': dateStr,
              'total': total,
              'cashier': e['cashier']?.toString() ?? ''
            };
          }).toList();

          setState(() {
            _records = normalized;
            _grandTotal = _records.fold(0.0, (s, r) => s + (r['total'] as double? ?? 0.0));
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error parsing response: $e')));
        }
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

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) {
      setState(() => _range = picked);
      await _fetch(range: picked);
    }
  }

  List<Map<String, dynamic>> _groupByDate() {
    final Map<String, double> map = {};
    for (final r in _records) {
      final d = r['date'] ?? '';
      map[d] = (map[d] ?? 0) + (r['total'] as double? ?? 0.0);
    }
    final list = map.entries.map((e) => {'date': e.key, 'total': e.value}).toList();
    list.sort((a, b) => DateTime.parse(a['date'] as String).compareTo(DateTime.parse(b['date'] as String))
);

    return list;
  }

  Future<void> _exportPDF() async {
    final grouped = _groupByDate();
    if (grouped.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }
    
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (ctx) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Sales Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (_range != null) pw.Text('Range: ${_formatDate(_range!.start)} - ${_formatDate(_range!.end)}'),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Date', 'Total Sales'],
          data: grouped.map((g) => [g['date'], (g['total'] as double).toStringAsFixed(2)]).toList(),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Grand Total: ₱${_grandTotal.toStringAsFixed(2)}'),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportCSV() async {
    final grouped = _groupByDate();
    if (grouped.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }
    
    final rows = <List<dynamic>>[];
    rows.add(['Date', 'Total Sales']);
    for (final g in grouped) {rows.add([g['date'], (g['total'] as double).toStringAsFixed(2)]);}
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

Widget _chartWidget() {
  final grouped = _groupByDate();
  if (grouped.isEmpty) return const Center(child: Text('No data for selected range'));

  final maxY = grouped.map((g) => g['total'] as double).reduce((a, b) => a > b ? a : b) * 1.2;
  
if (_showBar) {
  return BarChart(
    BarChartData(
      maxY: maxY,
      barGroups: List.generate(
        grouped.length,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: grouped[i]['total'] as double,
              color: Colors.blue,
            ),
          ],
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx >= 0 && idx < grouped.length) {
                return Text(grouped[idx]['date'].toString(),
                    style: const TextStyle(fontSize: 10));
              }
              return const Text('');
            },
          ),
        ),
      ),
    ),
  );
} else {
  final spots = List.generate(
    grouped.length,
    (i) => FlSpot(
      i.toDouble(),
      grouped[i]['total'] as double,
    ),
  );

  return LineChart(
    LineChartData(
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.blue,
        ),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx >= 0 && idx < grouped.length) {
                return Text(grouped[idx]['date'].toString(),
                    style: const TextStyle(fontSize: 10));
              }
              return const Text('');
            },
          ),
        ),
      ),
    ),
  );
}

}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
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
                if (_range != null) Text('Range: ${_formatDate(_range!.start)} - ${_formatDate(_range!.end)}'),
                const SizedBox(height: 12),
                SizedBox(height: 220, child: Card(child: Padding(padding: const EdgeInsets.all(8), child: _chartWidget()))),
                const SizedBox(height: 12),
                Expanded(
                  child: _records.isEmpty
                      ? const Center(child: Text('No records found'))
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            return Card(
                              child: ListTile(
                                title: Text(r['date'] ?? ''),
                                subtitle: Text('Cashier: ${r['cashier'] ?? ''}'),
                                trailing: Text('₱${(r['total'] as double? ?? 0.0).toStringAsFixed(2)}'),
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