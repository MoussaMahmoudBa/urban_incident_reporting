import 'package:http/http.dart' as http;

class ApiService {
  final String _baseUrl = "http://127.0.0.1:8000/api/";

  Future<http.Response> get(String endpoint) async {
    return await http.get(Uri.parse('$_baseUrl$endpoint'));
  }

  Future<http.Response> post(String endpoint, dynamic data) async {
    return await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
  }
}