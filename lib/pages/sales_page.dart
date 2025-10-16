// lib/pages/sales_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../api_config.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final String productsUrl = ApiConfig.inventoryList;
  final String salesCreateUrl = ApiConfig.salesCreate;

  List<dynamic> _products = [];
  List<Map<String, dynamic>> _cart = [];
  bool _loading = false;
  bool _isSenior = false;
  bool _isPWD = false;

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(productsUrl), headers: {'X-API-KEY': 'local-dev-key'});
      setState(() => _loading = false);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['data'] ?? body;
        setState(() => _products = List<dynamic>.from(list));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load products')));
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _addToCart(dynamic product) {
    final idx = _cart.indexWhere((c) => c['id'] == product['id']);
    if (idx >= 0) {
      setState(() => _cart[idx]['qty'] += 1);
    } else {
      setState(() => _cart.add({
            'product_id': product['id'],
            'name': product['name'],
            'unit_price': (product['unit_price'] ?? product['price'] ?? 0),
            'quantity': 1
          }));
    }
  }

  double get _subtotal => _cart.fold(0.0, (s, it) => s + (it['unit_price'] * it['quantity']));
  double get _discountRate => (_isSenior || _isPWD) ? 0.20 : 0.0;
  double get _discount => _subtotal * _discountRate;
  double get _tax => (_subtotal - _discount) * 0.12;
  double get _total => (_subtotal - _discount) + _tax;

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }
    final items = _cart
        .map((c) => {
              'product_id': c['product_id'],
              'name': c['name'],
              'quantity': c['quantity'],
              'unit_price': c['unit_price'],
              'total_price': (c['unit_price'] * c['quantity'])
            })
        .toList();
    final payload = {
      'cashier': 'Cashier 1',
      'items': items,
      'discount': _discount,
      'senior': (_isSenior ? 1 : 0),
      'pwd': (_isPWD ? 1 : 0)
    };

    try {
      final res = await http.post(Uri.parse(salesCreateUrl),
          headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
          body: jsonEncode(payload));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final saleId = body['sale_id'] ?? body['id'];
        await _printReceiptLocally(saleId?.toString() ?? '');
        setState(() => _cart.clear());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale recorded')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale failed: ${res.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout error: $e')));
    }
  }

  Future<void> _printReceiptLocally(String saleId) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context ctx) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('PHARMAKOLE DRUGMART', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Receipt: $saleId'),
        pw.Divider(),
        pw.Column(children: _cart.map((it) {
          return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Expanded(child: pw.Text('${it['name']} x${it['quantity']}')),
            pw.Text('₱${(it['unit_price'] * it['quantity']).toStringAsFixed(2)}')
          ]);
        }).toList()),
        pw.Divider(),
        pw.Text('Subtotal: ₱${_subtotal.toStringAsFixed(2)}'),
        pw.Text('Discount: ₱${_discount.toStringAsFixed(2)} ${_isSenior ? '(Senior)' : _isPWD ? '(PWD)' : ''}'),
        pw.Text('Tax: ₱${_tax.toStringAsFixed(2)}'),
        pw.Text('Total: ₱${_total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Thank you!'),
      ]);
    }));

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Products list
        Expanded(
          flex: 2,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final p = _products[i];
                    return Card(
                      child: ListTile(
                        title: Text(p['name'] ?? 'No name'),
                        subtitle: Text('₱${(p['unit_price'] ?? 0).toString()}'),
                        onTap: () => _addToCart(p),
                      ),
                    );
                  },
                ),
        ),
        const VerticalDivider(width: 1),
        // Cart and checkout
        Expanded(
          flex: 1,
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(8), child: Text('Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Checkbox(value: _isSenior, onChanged: (v) => setState(() => _isSenior = v ?? false)),
                const Text('Senior'),
                const SizedBox(width: 12),
                Checkbox(value: _isPWD, onChanged: (v) => setState(() => _isPWD = v ?? false)),
                const Text('PWD'),
              ]),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _cart.length,
                  itemBuilder: (context, i) {
                    final c = _cart[i];
                    return ListTile(
                      title: Text(c['name']),
                      subtitle: Text('₱${c['unit_price']} x ${c['quantity']}'),
                      trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _cart.removeAt(i))),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Subtotal: ₱${_subtotal.toStringAsFixed(2)}'),
                  Text('Discount: ₱${_discount.toStringAsFixed(2)}'),
                  Text('Tax: ₱${_tax.toStringAsFixed(2)}'),
                  Text('Total: ₱${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
              Padding(padding: const EdgeInsets.all(8), child: ElevatedButton(onPressed: _checkout, child: const Text('Checkout & Print'))),
            ],
          ),
        ),
      ],
    );
  }
}
