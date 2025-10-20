// lib/pages/supplier_list_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'supplier_form_page.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  List<dynamic> _suppliers = [];
  bool _loading = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _searchController.addListener(() {
      _fetchSuppliers(query: _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers({String query = ''}) async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse('${ApiConfig.suppliersList}?q=$query');
      final res = await http.get(
        url,
        headers: {'X-API-KEY': 'local-dev-key'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _suppliers = body['data'] ?? []);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load suppliers: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _editSupplier(Map<String, dynamic> supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierFormPage(supplier: supplier)),
    ).then((_) => _fetchSuppliers(query: _searchController.text)); // Refresh list
  }

  void _addSupplier() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupplierFormPage()),
    ).then((_) => _fetchSuppliers(query: _searchController.text)); // Refresh list
  }

  Future<void> _deleteSupplier(String id) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this supplier?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.suppliersDelete),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode({'id': id}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier deleted')));
        _fetchSuppliers(query: _searchController.text); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Suppliers'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSupplier,
        tooltip: 'Add Supplier',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Suppliers',
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _fetchSuppliers(query: _searchController.text),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _suppliers.length,
                      itemBuilder: (context, i) {
                        final s = _suppliers[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(s['name'] ?? ''),
                            subtitle: Text(s['contact_person'] ?? s['phone'] ?? 'No contact'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                              onPressed: () => _deleteSupplier(s['id'].toString()),
                            ),
                            onTap: () => _editSupplier(s),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}