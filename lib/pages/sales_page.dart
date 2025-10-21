// lib/pages/sales_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../cart_service.dart';
import 'checkout_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final String productsUrl = ApiConfig.inventoryList;
  List<dynamic> _products = [];
  bool _loading = false;

  // --- NEW: Search controller ---
  final _searchController = TextEditingController();
  
  // --- NEW: Cart service instance ---
  final _cartService = CartService();

  Future<void> _loadProducts({String query = ''}) async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse('$productsUrl?q=$query');
      final res = await http.get(url, headers: {'X-API-KEY': 'local-dev-key'});
      if (mounted) {
        setState(() => _loading = false);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          
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

  // --- MODIFIED: Add to service instead of local state ---
  void _addToCart(dynamic product) {
    _cartService.add(product);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added ${product['name']} to cart.'),
      duration: const Duration(seconds: 1),
    ));
  }
  
  // --- NEW: Navigate to checkout page ---
  void _goToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(() {
      _loadProducts(query: _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- NEW: Cart Button with Badge ---
  Widget _buildCartButton() {
    return ValueListenableBuilder<int>(
      valueListenable: _cartService.itemCount,
      builder: (context, count, child) {
        return Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          child: IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _goToCheckout,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    
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

    // --- MODIFIED: Full-screen scaffold layout ---
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          _buildCartButton(),
        ],
      ),
      body: Column(
        children: [
          // --- NEW: Search Bar ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Products',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          // --- NEW: Product list in Expanded ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadProducts(query: _searchController.text),
              child: productsList,
            ),
          ),
        ],
      ),
    );
  }
}