// lib/pages/admin_page.dart
import 'package:flutter/material.dart';
import 'staff_list_page.dart';
import 'supplier_list_page.dart';
import 'restock_form_page.dart';
import 'restock_list_page.dart';
import 'adjustment_report_page.dart';
import 'activity_log_page.dart';
import 'inventory_report_page.dart';
import 'profit_report_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Helper widget for navigation tiles
  Widget _buildAdminTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? Colors.black54),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSectionHeader(context, 'Stock & Suppliers'),
          _buildAdminTile(
            context,
            icon: Icons.add_shopping_cart,
            iconColor: Colors.green[700],
            title: 'Receive New Stock',
            page: const RestockFormPage(),
          ),
          _buildAdminTile(
            context,
            icon: Icons.history,
            iconColor: Colors.blue[700],
            title: 'View Past Receipts',
            page: const RestockListPage(),
          ),
          _buildAdminTile(
            context,
            icon: Icons.business,
            title: 'Manage Suppliers',
            page: const SupplierListPage(),
          ),

          _buildSectionHeader(context, 'Reports & Audits'),
          _buildAdminTile(
            context,
            icon: Icons.summarize,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Inventory Report Summary',
            page: const InventoryReportPage(),
          ),
          _buildAdminTile(
            context,
            icon: Icons.trending_up,
            iconColor: Colors.green[700],
            title: 'Profit & Loss Report',
            page: const ProfitReportPage(),
          ),
          _buildAdminTile(
            context,
            icon: Icons.edit_note,
            iconColor: Colors.blueGrey[700],
            title: 'Stock Adjustments Log',
            page: const AdjustmentReportPage(),
          ),
          _buildAdminTile(
            context,
            icon: Icons.receipt_long,
            iconColor: Colors.purple[700],
            title: 'System Activity Log',
            page: const ActivityLogPage(),
          ),
          
          _buildSectionHeader(context, 'Administration'),
          _buildAdminTile(
            context,
            icon: Icons.people,
            title: 'Manage Staff Accounts',
            page: const StaffListPage(),
          ),
        ],
      ),
    );
  }
}