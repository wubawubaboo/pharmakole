import 'package:flutter/material.dart';
import 'inventory_page.dart';
import 'sales_page.dart';
import 'admin_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const InventoryPage(),
    const SalesPage(),
    const AdminPage(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
    const BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Sales'),
    const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
  ];

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
      _visiblePages = [_pages[0], _pages[1]];
      _visibleNavItems = [_navItems[0], _navItems[1]];
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