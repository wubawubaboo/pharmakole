import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class SupplierFormPage extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  const SupplierFormPage({super.key, this.supplier});

  bool get isEditing => supplier != null;

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late TextEditingController _name;
  late TextEditingController _contactPerson;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _name = TextEditingController(text: s?['name'] ?? '');
    _contactPerson = TextEditingController(text: s?['contact_person'] ?? '');
    _phone = TextEditingController(text: s?['phone'] ?? '');
    _email = TextEditingController(text: s?['email'] ?? '');
    _address = TextEditingController(text: s?['address'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _contactPerson.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final payload = {
      'id': widget.supplier?['id'],
      'name': _name.text,
      'contact_person': _contactPerson.text,
      'phone': _phone.text,
      'email': _email.text,
      'address': _address.text,
    };

    try {
      final url = widget.isEditing ? ApiConfig.suppliersUpdate : ApiConfig.suppliersCreate;
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': 'local-dev-key'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supplier ${widget.isEditing ? 'updated' : 'created'}!'))
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${res.body}')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Supplier' : 'Add Supplier'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Supplier Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPerson,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveSupplier,
                      child: const Text('Save Supplier'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}