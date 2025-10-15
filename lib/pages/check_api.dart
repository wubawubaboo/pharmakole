import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> checkApiConnection() async {
  const String apiUrl = 'http://192.168.5.129/pharma/api/ping.php'; // replace with your own IP

  try {
    final response = await http.get(Uri.parse(apiUrl)).timeout(
      const Duration(seconds: 5),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ API connected: ${data['message']}');
    } else {
      print('⚠️ API responded with status: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Could not connect to API: $e');
  }
}
