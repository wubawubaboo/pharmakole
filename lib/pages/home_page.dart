import 'package:flutter/material.dart';
import 'inventory_page.dart';
import 'sales_page.dart';
import 'admin_page.dart';
import 'login_page.dart';
import '../cart_service.dart';

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

  late List<Widget> _visiblePages;
  late List<BottomNavigationBarItem> _visibleNavItems;
  
  bool get _isOwner => widget.user['role'] == 'owner';

  @override
  void initState() {
    super.initState();
    
    if (_isOwner) {
      _visiblePages = _pages;
      _visibleNavItems = _navItems;
    } else {
      _visiblePages = [_pages[0], _pages[1]];
      _visibleNavItems = [_navItems[0], _navItems[1]];
    }
  }

  void _logout() {
    CartService().clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.user['full_name'] ?? 'Cashier'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _visiblePages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: _visibleNavItems,
        type: BottomNavigationBarType.fixed, 
      ),
    );
  }
}