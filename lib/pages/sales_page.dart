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
  final List<Map<String, dynamic>> _cart = [];
  bool _loading = false;
  bool _isSenior = false;
  bool _isPWD = false;

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(productsUrl), headers: {'X-API-KEY': 'local-dev-key'});
      if (mounted) {
        setState(() => _loading = false);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          
          // --- FIX: Robustly parse the JSON response ---
          if (body is Map<String, dynamic> && body.containsKey('data') && body['data'] is List) {
            final list = body['data'];
            setState(() => _products = List<dynamic>.from(list));
          } else if (body is List) {
            setState(() => _products = List<dynamic>.from(body));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load products: Unexpected format.')));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load products')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _addToCart(dynamic product) {
    final idx = _cart.indexWhere((c) => c['product_id'] == product['id']);
    if (idx >= 0) {
      setState(() => _cart[idx]['quantity'] += 1);
    } else {
      setState(() => _cart.add({
            'product_id': product['id'],
            'name': product['name'],
            'unit_price': (product['unit_price'] ?? product['price'] ?? 0),
            'quantity': 1
          }));
    }
  }

  // Robust total calculation
  double get _subtotal => _cart.fold(0.0, (s, it) => s + ((double.tryParse(it['unit_price'].toString()) ?? 0.0) * it['quantity']));
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
              'total_price': ((double.tryParse(c['unit_price'].toString()) ?? 0.0) * c['quantity'])
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
        setState(() {
          _cart.clear();
          _isSenior = false;
          _isPWD = false;
        });
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
          final unitPrice = double.tryParse(it['unit_price'].toString()) ?? 0.0;
          return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Expanded(child: pw.Text('${it['name']} x${it['quantity']}')),
            pw.Text('₱${(unitPrice * it['quantity']).toStringAsFixed(2)}')
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
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    final productsList = _loading
        ? const Center(child: CircularProgressIndicator())
        : _products.isEmpty
          ? const Center(child: Text("No products available."))
          : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _products.length,
            itemBuilder: (context, i) {
              final p = _products[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p['name'] ?? 'No name', style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('₱${(double.tryParse(p['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)}'),
                  onTap: () => _addToCart(p),
                ),
              );
            },
          );

    final cartWidget = Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Column(
          children: [
            CheckboxListTile(
              title: const Text('Senior Discount'),
              value: _isSenior,
              onChanged: (v) => setState(() => _isSenior = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            CheckboxListTile(
              title: const Text('PWD Discount'),
              value: _isPWD,
              onChanged: (v) => setState(() => _isPWD = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('Cart is empty'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _cart.length,
                  itemBuilder: (context, i) {
                    final c = _cart[i];
                    return ListTile(
                      title: Text(c['name']),
                      subtitle: Text('₱${(double.tryParse(c['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)} x ${c['quantity']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() => _cart.removeAt(i)),
                      ),
                    );
                  },
                ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Subtotal:'),
                Text('₱${_subtotal.toStringAsFixed(2)}'),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Discount:'),
                Text('₱${_discount.toStringAsFixed(2)}'),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Tax:'),
                Text('₱${_tax.toStringAsFixed(2)}'),
              ]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('₱${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton(
            onPressed: _checkout,
            child: const Text('Checkout & Print'),
          ),
        ),
      ],
    );

    return isSmallScreen
        ? Column(children: [
            Expanded(flex: 3, child: productsList), 
            Expanded(flex: 4, child: cartWidget),    
          ])
        : Row(children: [
            Expanded(flex: 2, child: productsList),
            const VerticalDivider(width: 1),
            Expanded(flex: 1, child: cartWidget),
          ]);
  }
}
