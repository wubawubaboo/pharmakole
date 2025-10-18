// lib/pages/admin_page.dart
import 'package:flutter/material.dart';
import 'staff_list_page.dart';
import 'inventory_alerts_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'User Management',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Staff Accounts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffListPage()),
                );
              },
            ),
          ),
          const Divider(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'Inventory Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.warning, color: Colors.orange[700]),
              title: const Text('Low Stock Alerts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryAlertsPage(alertType: 'low_stock')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.event_busy, color: Colors.red[700]),
              title: const Text('Near Expiry Alerts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryAlertsPage(alertType: 'near_expiry')),
                );
              },
            ),
          ),
          // You can add more admin-level reports here
        ],
      ),
    );
  }
}