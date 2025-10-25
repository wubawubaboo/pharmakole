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
        
        await _printThermalReceipt(
          saleId: saleId?.toString() ?? '',
          cart: _cartService.cart,
          subtotal: _cartService.subtotal,
          discount: _cartService.discount,
          tax: _cartService.tax,
          total: _cartService.total,
          isSenior: _cartService.isSenior,
          isPwd: _cartService.isPWD,
        );
        
        setState(() => _cartService.clear());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale recorded')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale failed: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout error: $e')));
    }
  }

  Future<void> _printThermalReceipt({
    required String saleId,
    required List<Map<String, dynamic>> cart,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required bool isSenior,
    required bool isPwd,
  }) async {
    final pdf = pw.Document();
    
    // --- MODIFICATION IS HERE ---
    // Instead of PdfPageFormat.roll57, we define a custom format
    // 57mm wide, 300mm tall (very long), with 5mm margins
    // This gives the OS a finite size to default to.
    final PdfPageFormat format = PdfPageFormat(
      57 * PdfPageFormat.mm, // 57mm width
      300 * PdfPageFormat.mm, // 30cm height (long enough for most receipts)
      marginAll: 5 * PdfPageFormat.mm, // 5mm margins
    );
    // --- END OF MODIFICATION ---

    final date = DateTime.now();
    final dateString = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';

    pdf.addPage(pw.Page(
      pageFormat: format, // Use our new custom format
      build: (pw.Context ctx) {
        // Define text styles for the receipt
        final baseStyle = pw.TextStyle(fontSize: 8, font: pw.Font.courier());
        final boldStyle = pw.TextStyle(fontSize: 8, font: pw.Font.courierBold());
        final titleStyle = pw.TextStyle(fontSize: 12, font: pw.Font.courierBold());

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start, 
          children: [
            pw.Center(child: pw.Text('PHARMAKOLE DRUGMART', style: titleStyle)),
            pw.SizedBox(height: 5),
            pw.Center(child: pw.Text('OFFICIAL RECEIPT', style: baseStyle)),
            pw.SizedBox(height: 10),
            
            pw.Text('Receipt #: $saleId', style: baseStyle),
            pw.Text('Date: $dateString', style: baseStyle),
            pw.SizedBox(height: 5),
            pw.Divider(height: 1, borderStyle: pw.BorderStyle.dashed),

            // Table Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(flex: 4, child: pw.Text('Item', style: boldStyle)),
                pw.Expanded(flex: 1, child: pw.Text('Qty', style: boldStyle, textAlign: pw.TextAlign.right)),
                pw.Expanded(flex: 2, child: pw.Text('Total', style: boldStyle, textAlign: pw.TextAlign.right)),
              ]
            ),
            pw.Divider(height: 1, borderStyle: pw.BorderStyle.dashed),

            // Items
            ...cart.map((it) {
              final unitPrice = double.tryParse(it['unit_price'].toString()) ?? 0.0;
              final itemTotal = (unitPrice * it['quantity']).toStringAsFixed(2);
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 4, child: pw.Text(it['name'], style: baseStyle)),
                  pw.Expanded(flex: 1, child: pw.Text(it['quantity'].toString(), style: baseStyle, textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('P$itemTotal', style: baseStyle, textAlign: pw.TextAlign.right)),
                ]
              );
            }),
            pw.Divider(height: 1, borderStyle: pw.BorderStyle.dashed),

            // Summary
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Subtotal:', style: baseStyle),
              pw.Text('P${subtotal.toStringAsFixed(2)}', style: baseStyle),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Discount: ${isSenior ? '(Sen)' : isPwd ? '(PWD)' : ''}', style: baseStyle),
              pw.Text('P${discount.toStringAsFixed(2)}', style: baseStyle),
            ]),
             pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Tax (12%):', style: baseStyle),
              pw.Text('P${tax.toStringAsFixed(2)}', style: baseStyle),
            ]),
            pw.Divider(height: 1),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL:', style: boldStyle),
              pw.Text('P${total.toStringAsFixed(2)}', style: boldStyle),
            ]),
            pw.SizedBox(height: 15),
            pw.Center(child: pw.Text('Thank you!', style: baseStyle)),
            pw.SizedBox(height: 5),
            pw.Center(child: pw.Text('THIS IS NOT AN OFFICIAL RECEIPT', style: baseStyle)),
        ]);
      }
    ));

    await Printing.layoutPdf(
      format: format, // Pass our new custom format
      onLayout: (PdfPageFormat osFormat) async => pdf.save()
    );
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
                        subtitle: Text('P${(double.tryParse(c['unit_price'].toString()) ?? 0.0).toStringAsFixed(2)} x ${c['quantity']}'),
                        onTap: () => _editCartItem(i),
                        trailing: Text(
                          'P${((double.tryParse(c['unit_price'].toString()) ?? 0.0) * c['quantity']).toStringAsFixed(2)}',
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
                  Text('P${_cartService.subtotal.toStringAsFixed(2)}'),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Discount:'),
                  Text('P${_cartService.discount.toStringAsFixed(2)}'),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Tax:'),
                  Text('P${_cartService.tax.toStringAsFixed(2)}'),
                ]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('P${_cartService.total.toStringAsFixed(2)}',
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