import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:async'; // For TimeoutException
import '../models/parking_space.dart';

class AuthService {
  // Base URL depends on platform
  static String get baseUrl {
    // default to localhost for desktop/web
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    if (Platform.isIOS) {
      return 'http://localhost:8000/api';
    }
    // Windows, Mac, Linux
    return 'http://localhost:8000/api';
  }
// class AuthService {
//   // Base URL depends on platform
//   static String get baseUrl {
//     // default to localhost for desktop/web
//     if (kIsWeb) {
//       return 'https://parkaimap-1.onrender.com/api';
//     }
//     if (Platform.isAndroid) {
//       return 'https://parkaimap-1.onrender.com/api';
//     }
//     if (Platform.isIOS) {
//       return 'https://parkaimap-1.onrender.com/api';
//     }
//     // Windows, Mac, Linux
//     return 'https://parkaimap-1.onrender.com/api';
//   }

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_data';

  // Helper: Perform HTTP request with timeout and error classification
  static Future<http.Response> _performRequest(
    Future<http.Response> Function() request, {
    String method = 'GET',
  }) async {
    try {
      // Check connection first
      final isReachable = await checkBackendConnection();
      if (!isReachable) {
        throw SocketException('Backend unreachable');
      }

      // Execute with 60s timeout for render wake up
      return await request().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Request timed out', const Duration(seconds: 60)),
      );
    } catch (e) {
      if (e is SocketException || e is TimeoutException) {
        debugPrint('Network error in $method: $e');
        rethrow;  // Bubble up for LoginScreen to catch
      }
      rethrow;
    }
  }

  // Register a new user
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String fullName,
    required String phone,
    required String userType,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final response = await _performRequest(
        () => http.post(
          Uri.parse('$baseUrl/auth/register/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'email': email,
            'full_name': fullName,
            'phone': phone,
            'user_type': userType,
            'password': password,
            'password_confirm': passwordConfirm,
          }),
        ),
        method: 'POST',
      );

      final data = jsonDecode(response.body);
      debugPrint('Register response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        // Classify server errors
        String msg = _extractErrorMessage(data);
        String? errorCode;
        if (response.statusCode >= 500) {
          errorCode = 'NET_001';  // Backend down
          msg = 'Backend error during registration';
        }
        return {'success': false, 'error': msg, 'errorCode': errorCode, 'errors': data};
      }
    } on FormatException {
      debugPrint('FormatException in register: Invalid response JSON');
      return {'success': false, 'error': 'Invalid server response', 'errorCode': 'NET_002'};
    } catch (e) {
      // Non-network errors (e.g., validation) return map; network already rethrown
      debugPrint('Unexpected register error: $e');
      return {'success': false, 'error': 'Registration error: $e'};
    }
  }

  // Register security personnel
  static Future<Map<String, dynamic>> registerSecurity({
    required String username,
    required String email,
    required String fullName,
    required String phone,
    required int parkingSpaceId,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final response = await _performRequest(
        () => http.post(
          Uri.parse('$baseUrl/auth/register/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'email': email,
            'full_name': fullName,
            'phone': phone,
            'user_type': 'security',
            'assigned_parking_space': parkingSpaceId,
            'password': password,
            'password_confirm': passwordConfirm,
          }),
        ),
        method: 'POST',
      );

      final data = jsonDecode(response.body);
      debugPrint('Security register response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        String msg = _extractErrorMessage(data);
        String? errorCode;
        if (response.statusCode >= 500) {
          errorCode = 'NET_001';
          msg = 'Backend error during security registration';
        }
        return {'success': false, 'error': msg, 'errorCode': errorCode, 'errors': data};
      }
    } on FormatException {
      debugPrint('FormatException in security register: Invalid response JSON');
      return {'success': false, 'error': 'Invalid server response', 'errorCode': 'NET_002'};
    } catch (e) {
      debugPrint('Unexpected security register error: $e');
      return {'success': false, 'error': 'Security registration error: $e'};
    }
  }

  // Get parking spaces for security registration
  static Future<List<ParkingSpace>> getParkingSpacesForSecurity() async {
    try {
      final response = await _performRequest(
        () => http.get(
          Uri.parse('$baseUrl/auth/parking-spaces-for-security/'),
          headers: {'Content-Type': 'application/json'},
        ),
        method: 'GET',
      );

      final data = jsonDecode(response.body);
      debugPrint('Parking spaces response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> spacesJson = data;
        return spacesJson.map((json) => ParkingSpace.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load parking spaces: ${response.statusCode}');
      }
    } on FormatException {
      debugPrint('FormatException in getParkingSpacesForSecurity: Invalid response JSON');
      throw Exception('Invalid server response');
    } catch (e) {
      debugPrint('Unexpected getParkingSpacesForSecurity error: $e');
      rethrow;
    }
  }

  // Register vendor with document uploads
  static Future<Map<String, dynamic>> registerVendor({
    required String username,
    required String email,
    required String fullName,
    required String phone,
    required String address,
    required String companyName,
    required String landOwnerName,
    required String password,
    required String passwordConfirm,
    File? landTaxReceipt,
    File? licenseDocument,
    File? governmentId,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/register/'),
      );

      // Add text fields
      request.fields.addAll({
        'username': username,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'user_type': 'vendor',
        'password': password,
        'password_confirm': passwordConfirm,
        'address': address,
        'company_name': companyName,
        'land_owner_name': landOwnerName,
      });

      // Add file fields if provided
      if (landTaxReceipt != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'land_tax_receipt',
          landTaxReceipt.path,
        ));
      }
      if (licenseDocument != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'license_document',
          licenseDocument.path,
        ));
      }
      if (governmentId != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'government_id',
          governmentId.path,
        ));
      }

      // Check connection first
      final isReachable = await checkBackendConnection();
      if (!isReachable) {
        throw SocketException('Backend unreachable');
      }

      // Execute with timeout
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Request timed out', const Duration(seconds: 60)),
      );

      var response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      debugPrint('Vendor register response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        String msg = _extractErrorMessage(data);
        String? errorCode;
        if (response.statusCode >= 500) {
          errorCode = 'NET_001';
          msg = 'Backend error during vendor registration';
        }
        return {'success': false, 'error': msg, 'errorCode': errorCode, 'errors': data};
      }
    } on FormatException {
      debugPrint('FormatException in vendor register: Invalid response JSON');
      return {'success': false, 'error': 'Invalid server response', 'errorCode': 'NET_002'};
    } catch (e) {
      debugPrint('Unexpected vendor register error: $e');
      return {'success': false, 'error': 'Vendor registration error: $e'};
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _performRequest(
        () => http.post(
          Uri.parse('$baseUrl/auth/token/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        ),
        method: 'POST',
      );

      final data = jsonDecode(response.body);
      debugPrint('Login response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        // Store tokens
        await _storage.write(key: _tokenKey, value: data['access']);
        await _storage.write(key: _refreshTokenKey, value: data['refresh']);

        // Get user profile
        final userData = await getUserProfile();
        if (userData['success']) {
          await _storage.write(key: _userKey, value: jsonEncode(userData['user']));
        }

        return {'success': true, 'data': data};
      } else {
        // Classify server errors
        String message = _extractErrorMessage(data);
        String? errorCode;
        if (response.statusCode >= 500) {
          errorCode = 'NET_001';  // Backend down
          message = 'Backend error during login';
        } else if (response.statusCode == 401) {
          if (data['detail'] != null || data['non_field_errors'] != null) {
            // Keep backend message
          } else {
            message = 'Invalid credentials';
          }
        }
        return {'success': false, 'error': message, 'errorCode': errorCode};
      }
    } on FormatException {
      debugPrint('FormatException in login: Invalid response JSON');
      return {'success': false, 'error': 'Invalid server response', 'errorCode': 'NET_002'};
    } catch (e) {
      // Non-network errors return map; network rethrown above
      debugPrint('Unexpected login error: $e');
      return {'success': false, 'error': 'Login error: $e'};
    }
  }

  // Helper: Extract readable message from error data
  static String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      if (data.containsKey('detail')) return data['detail'];
      if (data.containsKey('non_field_errors')) return (data['non_field_errors'] as List).join(' ');
      if (data.containsKey('username')) return (data['username'] as List).join(' ');
      if (data.containsKey('email')) return (data['email'] as List).join(' ');
    }
    return 'Operation failed';
  }

  // Get user profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'No token found'};
      }

      final response = await _performRequest(
        () => http.get(
          Uri.parse('$baseUrl/users/profile/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
        method: 'GET',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'user': data};
      } else {
        return {'success': false, 'error': _extractErrorMessage(data)};
      }
    } on FormatException {
      debugPrint('FormatException in getUserProfile: Invalid response JSON');
      return {'success': false, 'error': 'Invalid server response', 'errorCode': 'NET_002'};
    } catch (e) {
      // Network rethrown; others mapped
      debugPrint('Unexpected profile error: $e');
      return {'success': false, 'error': 'Profile fetch error: $e'};
    }
  }

  // Refresh token
  static Future<Map<String, dynamic>> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        return {'success': false, 'error': 'No refresh token found'};
      }

      final response = await _performRequest(
        () => http.post(
          Uri.parse('$baseUrl/auth/token/refresh/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': refreshToken}),
        ),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _storage.write(key: _tokenKey, value: data['access']);
        return {'success': true, 'token': data['access']};
      } else {
        // Token refresh failed, logout user
        await logout();
        return {'success': false, 'error': 'Session expired'};
      }
    } on FormatException {
      debugPrint('FormatException in refreshToken: Invalid response JSON');
      await logout();
      return {'success': false, 'error': 'Invalid server response', 'errorCode': 'NET_002'};
    } catch (e) {
      debugPrint('Unexpected refresh error: $e');
      await logout();
      return {'success': false, 'error': 'Refresh error: $e'};
    }
  }

  // Logout user
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }

  // Get stored token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Get stored user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final userData = await _storage.read(key: _userKey);
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Get user type
  static Future<String?> getUserType() async {
    final userData = await getUserData();
    return userData?['user_type'];
  }

  // Get admin dashboard metrics
  static Future<Map<String, dynamic>> getAdminMetrics() async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'error': 'Authentication required.'};
    }

    try {
      final response = await _performRequest(
        () => http.get(
          Uri.parse('$baseUrl/auth/admin/metrics/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
        method: 'GET',
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'error': _extractErrorMessage(data),
        'status': response.statusCode,
      };
    } on FormatException {
      debugPrint('FormatException in getAdminMetrics: Invalid response JSON');
      return {'success': false, 'error': 'Invalid server response', 'errorCode': 'NET_002'};
    } catch (e) {
      debugPrint('Unexpected getAdminMetrics error: $e');
      return {'success': false, 'error': 'Admin metrics fetch error: $e'};
    }
  }

  // Check if backend is reachable (enhanced with timeout)
  static Future<bool> checkBackendConnection() async {
    try {
      final url = baseUrl.replaceAll('/api', '/');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      final isSuccess = response.statusCode < 500;
      debugPrint('Backend ping: ${isSuccess ? 'Reachable' : 'Unreachable (${response.statusCode})'}');
      return isSuccess;
    } catch (e) {
      debugPrint('Backend ping failed: $e');
      return false;
    }
  }
}