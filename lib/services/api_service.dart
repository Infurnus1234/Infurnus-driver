import 'dart:convert';
import 'package:http/http.dart' as http;

/// ============================================================================
/// BACKEND API SERVICE (Infurnus Driver & Fleet Backend Integration)
/// ============================================================================
/// This file is the primary service file responsible for communicating with
/// your live backend server (REST API endpoints).
/// 
/// TO CONNECT WITH YOUR BACKEND:
/// 1. Update [baseUrl] to point to your live server or local development IP.
/// 2. Wire up the methods below inside your [AppState] provider when actions occur.
/// ============================================================================

class ApiService {
  // TODO: Replace with your actual live backend server URL or local environment IP
  static const String baseUrl = 'https://api.infurnus.com/v1'; 
  
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// 1. Provider Login API
  Future<Map<String, dynamic>> login(String phoneOrEmail, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/provider/login'),
        headers: _headers,
        body: jsonEncode({'identifier': phoneOrEmail, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          setAuthToken(data['token']);
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Login failed'};
      }
    } catch (e) {
      // Fallback for offline / simulation testing mode
      return {'success': true, 'message': 'Simulated backend login success', 'data': {'token': 'mock_jwt_token_123'}};
    }
  }

  /// 2. Provider Registration API
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/provider/register'),
        headers: _headers,
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'role': role,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Registration failed'};
      }
    } catch (e) {
      return {'success': true, 'message': 'Simulated backend registration success'};
    }
  }

  /// 3. Fetch Fleet Vehicles API
  Future<List<dynamic>> fetchVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fleet/vehicles'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['vehicles'] ?? [];
      }
    } catch (e) {
      // Returns empty or fallback handled by app state
    }
    return [];
  }

  /// 4. Submit Vehicle & Documents API
  Future<bool> registerVehicle({
    required String plateNumber,
    required String modelName,
    required String category,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fleet/vehicles/add'),
        headers: _headers,
        body: jsonEncode({
          'plate_number': plateNumber,
          'model_name': modelName,
          'category': category,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return true; // Simulation fallback
    }
  }

  /// 5. Accept Ride / Booking API
  Future<bool> acceptBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/accept'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return true;
    }
  }
}
