import 'package:flutter/material.dart';
import 'inventory_page.dart';
import 'sales_page.dart';
import 'reports_page.dart';
import 'admin_page.dart'; // <-- NEW
import 'login_page.dart'; // <-- NEW

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  
  // --- MODIFIED: Store pages and items in lists ---
  final List<Widget> _pages = [
    const InventoryPage(),
    const SalesPage(),
    const ReportsPage(),
    const AdminPage(), // <-- NEW: Add admin page
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
    const BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Sales'),
    const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
    const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'), // <-- NEW
  ];

  // --- NEW: Lists to hold the final UI elements based on role ---
  List<Widget> _visiblePages = [];
  List<BottomNavigationBarItem> _visibleNavItems = [];
  
  bool get _isOwner => widget.user['role'] == 'owner';

  @override
  void initState() {
    super.initState();
    
    // --- NEW: Filter pages and nav items based on user role ---
    if (_isOwner) {
      // Owner sees all pages
      _visiblePages = _pages;
      _visibleNavItems = _navItems;
    } else {
      // Staff sees only Inventory, Sales, Reports
      _visiblePages = [_pages[0], _pages[1], _pages[2]];
      _visibleNavItems = [_navItems[0], _navItems[1], _navItems[2]];
    }
  }

  // --- NEW: Logout function ---
  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes behind
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.user['full_name'] ?? 'Cashier'}'),
        // --- NEW: Logout Button ---
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      // --- MODIFIED: Use filtered list of pages ---
      body: _visiblePages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        // --- MODIFIED: Use filtered list of nav items ---
        items: _visibleNavItems,
        // --- NEW: Ensure nav bar items are always visible ---
        type: BottomNavigationBarType.fixed, 
      ),
    );
  }
}