// lib/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.254.112/pharma/api';

  // User Endpoints
  static const String login = '$baseUrl/users/login';
  static const String usersList = '$baseUrl/users/list';
  static const String usersCreate = '$baseUrl/users/create';
  static const String usersUpdate = '$baseUrl/users/update';
  static const String usersDelete = '$baseUrl/users/delete';

  // Suppliers Endpoints
  static const String suppliersList = '$baseUrl/suppliers/list';
  static const String suppliersCreate = '$baseUrl/suppliers/create';
  static const String suppliersUpdate = '$baseUrl/suppliers/update';
  static const String suppliersDelete = '$baseUrl/suppliers/delete';
  
  // Restock Endpoints
  static const String restockReceive = '$baseUrl/restock/receive';
  static const String restockList = '$baseUrl/restock/list';
  static const String restockDetails = '$baseUrl/restock/details';
  
  // Inventory Endpoints
  static const String inventoryList = '$baseUrl/inventory/list';
  static const String inventoryCreate = '$baseUrl/inventory/create';
  static const String inventoryUpdate = '$baseUrl/inventory/update';
  static const String inventoryDelete = '$baseUrl/inventory/delete';
  static const String inventoryLowStock = '$baseUrl/inventory/low';
  static const String inventoryNearExpiry = '$baseUrl/inventory/expiry';

  // Sales Endpoints
  static const String salesCreate = '$baseUrl/sales/create';

  // Reports Endpoints
  static const String reportsSummary = '$baseUrl/reports/summary';
  static const String reportsDaily = '$baseUrl/reports/daily';
}