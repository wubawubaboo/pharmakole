// lib/pages/checkout_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data'; // For thermal printing

// --- PDF/PRINTING IMPORTS (for fallback) ---
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// --- THERMAL IMPORTS ---
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// --- ### MODIFICATION IS HERE ### ---
import 'package:bluetooth_thermal_printer_plus/bluetooth_thermal_printer_plus.dart'; 
// --- ### END OF MODIFICATION ### ---

import '../api_config.dart';
import '../cart_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _cartService = CartService();

  // The class name 'BlueThermalPrinter' is the same in the new package
  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  // BluetoothDevice? _printerDevice; 


  // ... _editCartItem function remains exactly the same ...
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
    // ... (This top part of _checkout remains the same) ...
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
      'cashier': 'Cashier 1', 
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
        
        // --- Fallback Logic ---
        bool isConnected = await printer.isConnected ?? false;
        
        final printData = {
          'saleId': saleId?.toString() ?? '',
          'cart': _cartService.cart,
          'subtotal': _cartService.subtotal,
          'discount': _cartService.discount,
          'tax': _cartService.tax,
          'total': _cartService.total,
          'isSenior': _cartService.isSenior,
          'isPwd': _cartService.isPWD,
        };

        if (isConnected) {
          // 1. If connected, print to thermal
          await _printToThermalPrinter(
            saleId: printData['saleId'] as String,
            cart: printData['cart'] as List<Map<String, dynamic>>,
            subtotal: printData['subtotal'] as double,
            discount: printData['discount'] as double,
            tax: printData['tax'] as double,
            total: printData['total'] as double,
            isSenior: printData['isSenior'] as bool,
            isPwd: printData['isPwd'] as bool,
          );
        } else {
          // 2. If not connected, fall back to PDF
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Printer not connected. Generating PDF...'),
            ));
          }
          await _printToPdfReceipt(
            saleId: printData['saleId'] as String,
            cart: printData['cart'] as List<Map<String, dynamic>>,
            subtotal: printData['subtotal'] as double,
            discount: printData['discount'] as double,
            tax: printData['tax'] as double,
            total: printData['total'] as double,
            isSenior: printData['isSenior'] as bool,
            isPwd: printData['isPwd'] as bool,
          );
        }
        
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

  // --- THERMAL PRINTER FUNCTION (NO CHANGES) ---
  Future<void> _printToThermalPrinter({
    required String saleId,
    required List<Map<String, dynamic>> cart,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required bool isSenior,
    required bool isPwd,
  }) async {

    // 1. GENERATE THE RECEIPT DATA (THE "FORMATTING")
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final date = DateTime.now();
    final dateString = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';

    bytes += generator.text('PHARMAKOLE DRUGMART', styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.text('OFFICIAL RECEIPT', styles: PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    
    bytes += generator.text('Receipt #: $saleId', styles: PosStyles(align: PosAlign.left));
    bytes += generator.text('Date: $dateString', styles: PosStyles(align: PosAlign.left));
    bytes += generator.hr();

    // Table Header
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: 'Total', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);
    
    // Table Items
    for (final it in cart) {
      final unitPrice = double.tryParse(it['unit_price'].toString()) ?? 0.0;
      final itemTotal = (unitPrice * it['quantity']).toStringAsFixed(2);
      bytes += generator.row([
        PosColumn(text: it['name'], width: 6),
        PosColumn(text: it['quantity'].toString(), width: 2, styles: PosStyles(align: PosAlign.center)),
        PosColumn(text: 'P$itemTotal', width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();

    // Summary
    bytes += generator.row([
      PosColumn(text: 'Subtotal:', width: 6, styles: PosStyles(align: PosAlign.right)),
      PosColumn(text: 'P${subtotal.toStringAsFixed(2)}', width: 6, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Discount: ${isSenior ? '(Sen)' : isPwd ? '(PWD)' : ''}', width: 6, styles: PosStyles(align: PosAlign.right)),
      PosColumn(text: 'P${discount.toStringAsFixed(2)}', width: 6, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Tax (12%):', width: 6, styles: PosStyles(align: PosAlign.right)),
      PosColumn(text: 'P${tax.toStringAsFixed(2)}', width: 6, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL:', width: 6, styles: PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
      PosColumn(text: 'P${total.toStringAsFixed(2)}', width: 6, styles: PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);
    bytes += generator.feed(1);
    bytes += generator.text('Thank you!', styles: PosStyles(align: PosAlign.center));
    bytes += generator.text('THIS IS NOT AN OFFICIAL RECEIPT', styles: PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();


    // 2. SEND THE DATA TO THE PRINTER
    // You MUST implement the printer connection logic (e.g., in a settings page)
    // for this to work.
    
    try {
      // Send the generated bytes to the connected printer
      await printer.writeBytes(Uint8List.fromList(bytes));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Print complete!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print Error: $e')));
    }
  }


  // --- PDF FALLBACK FUNCTION (NO CHANGES) ---
  Future<void> _printToPdfReceipt({
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
    
    final PdfPageFormat format = PdfPageFormat(
      57 * PdfPageFormat.mm, // 57mm width
      300 * PdfPageFormat.mm, // 30cm height
      marginAll: 5 * PdfPageFormat.mm, // 5mm margins
    );

    final date = DateTime.now();
    final dateString = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    
    pdf.addPage(pw.Page(
      pageFormat: format, 
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
            }).toList(),
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

    // This will open the "Save as PDF" dialog
    await Printing.layoutPdf(
      format: format, // Pass our custom format
      onLayout: (PdfPageFormat osFormat) async => pdf.save()
    );
  }


  @override
  Widget build(BuildContext context) {
    // ... The build method remains exactly the same ...
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