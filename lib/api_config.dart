// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.5.129/pharma/api';

  // User Endpoints
  static const String login = '$baseUrl/users/login';

  // Inventory Endpoints
  static const String inventoryList = '$baseUrl/inventory/list';

  // Sales Endpoints
  static const String salesCreate = '$baseUrl/sales/create';

  // Reports Endpoints
  static const String reportsSummary = '$baseUrl/reports/summary';
  static const String reportsDaily = '$baseUrl/reports/daily';
}