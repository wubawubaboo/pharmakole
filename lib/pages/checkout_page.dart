// lib/pages/checkout_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../api_config.dart';
import '../cart_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _cartService = CartService();

  // --- Show dialog to edit cart item quantity ---
  void _editCartItem(int index) {
    final item = _cartService.cart[index];
    final qtyController = TextEditingController(text: item['quantity'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${item['name']}'),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _cartService.remove(index));
              Navigator.of(ctx).pop();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(qtyController.text) ?? 0;
              setState(() => _cartService.updateQuantity(index, newQty));
              Navigator.of(ctx).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout() async {
    if (_cartService.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }
    final items = _cartService.cart
        .map((c) => {
              'product_id': c['product_id'],
              'name': c['name'],
              'quantity': c['quantity'],
              'unit_price': c['unit_price'],
              'total_price': ((double.tryParse(c['unit_price'].toString()) ?? 0.0) * c['quantity'])
            })
        .toList();
    final payload = {
      'cashier': 'Cashier 1', // You could pass the logged in user's name here
      'items': items,
      'discount': _cartService.discount,
      'senior': (_cartService.isSenior ? 1 : 0),
      'pwd': (_cartService.isPWD ? 1 : 0)
    };

    try {
      final res = await http.post(Uri.parse(ApiConfig.salesCreate),
          headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
          body: jsonEncode(payload));
          
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final saleId = body['sale_id'] ?? body['id'];
        await _printReceiptLocally(saleId?.toString() ?? '');
        
        setState(() => _cartService.clear());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale recorded')));
        Navigator.of(context).pop(); // Go back to sales page
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale failed: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout error: $e')));
    }
  }

  Future<void> _printReceiptLocally(String saleId) async {
    final pdf = pw.Document();
    
    // Copy cart and totals at time of printing
    final cartCopy = List<Map<String, dynamic>>.from(_cartService.cart);
    final subtotal = _cartService.subtotal;
    final discount = _cartService.discount;
    final tax = _cartService.tax;
    final total = _cartService.total;
    final isSenior = _cartService.isSenior;
    final isPwd = _cartService.isPWD;

    pdf.addPage(pw.Page(build: (pw.Context ctx) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('PHARMAKOLE DRUGMART', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Receipt: $saleId'),
        pw.Divider(),
        pw.Column(children: cartCopy.map((it) {
          final unitPrice = double.tryParse(it['unit_price'].toString()) ?? 0.0;
          return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Expanded(child: pw.Text('${it['name']} x${it['quantity']}')),
            pw.Text('₱${(unitPrice * it['quantity']).toStringAsFixed(2)}')
          ]);
        }).toList()),
        pw.Divider(),
        pw.Text('Subtotal: ₱${subtotal.toStringAsFixed(2)}'),
        pw.Text('Discount: ₱${discount.toStringAsFixed(2)} ${isSenior ? '(Senior)' : isPwd ? '(PWD)' : ''}'),
        pw.Text('Tax: ₱${tax.toStringAsFixed(2)}'),
        pw.Text('Total: ₱${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Thank you!'),
      ]);
    }));

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Column(
        children: [
          Column(
            children: [
              CheckboxListTile(
                title: const Text('Senior Discount'),
                value: _cartService.isSenior,
                onChanged: (v) => setState(() => _cartService.isSenior = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              CheckboxListTile(
                title: const Text('PWD Discount'),
                value: _cartService.isPWD,
                onChanged: (v) => setState(() => _cartService.isPWD = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _cartService.cart.isEmpty
                ? const Center(child: Text('Cart is empty'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _cartService.cart.length,
                    itemBuilder: (context, i) {
                      final c = _cartService.cart[i];
                      return ListTile(
                        title: Text(c['name']),
                        subtitle: Text('₱${(double.tryParse(c['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)} x ${c['quantity']}'),
                        onTap: () => _editCartItem(i),
                        trailing: Text(
                          '₱${((double.tryParse(c['unit_price'].toString()) ?? 0.0) * c['quantity']).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                  Text('₱${_cartService.subtotal.toStringAsFixed(2)}'),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Discount:'),
                  Text('₱${_cartService.discount.toStringAsFixed(2)}'),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Tax:'),
                  Text('₱${_cartService.tax.toStringAsFixed(2)}'),
                ]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₱${_cartService.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      ),
    );
  }
}