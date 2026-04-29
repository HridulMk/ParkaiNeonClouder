// lib/services/admin_service.dart
import 'api_service.dart';

class AdminService {
  // Helper to safely extract list from response
  static List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic>) {
      final results = response['results'];
      if (results is List) return results;
    }
    return <dynamic>[];
  }

  // Helper to safely convert to Map
  static Map<String, dynamic> _toMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response);
    }
    return {};
  }

  // ==================== METRICS ====================
  static Future<Map<String, dynamic>> getAdminMetrics() async {
    try {
      final response = await ApiService.get('auth/admin/metrics/', auth: true);
      return _toMap(response);
    } catch (e) {
      rethrow; // Let the UI handle the error
    }
  }

  static Future<Map<String, dynamic>> getAnalyticsOverview({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String>[];
    if (startDate != null && startDate.isNotEmpty) params.add('start_date=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('end_date=$endDate');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await ApiService.get('analytics/overview/$query', auth: true);
    return _toMap(response);
  }

  static Future<Map<String, dynamic>> getAppRevenue({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String>[];
    if (startDate != null && startDate.isNotEmpty) params.add('start_date=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('end_date=$endDate');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await ApiService.get('analytics/app-revenue/$query', auth: true);
    return _toMap(response);
  }

  // ==================== SETTINGS ====================
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await ApiService.get('auth/admin/settings/', auth: true);
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateSettings({
    required String commissionPercentage,
  }) async {
    try {
      final response = await ApiService.patch(
        'auth/admin/settings/',
        auth: true,
        body: {'commission_percentage': commissionPercentage},
      );
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== USERS ====================
  static Future<List<dynamic>> getUsers({
    String? userType,
    String? status,
  }) async {
    try {
      final params = <String>[];
      if (userType != null && userType.isNotEmpty) params.add('user_type=$userType');
      if (status != null && status.isNotEmpty) params.add('status=$status');

      final query = params.isEmpty ? '' : '?${params.join('&')}';
      final response = await ApiService.get('users/$query', auth: true);
      return _extractList(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> body) async {
    try {
      final response = await ApiService.post('users/', auth: true, body: body);
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> body) async {
    try {
      final response = await ApiService.patch('users/$userId/', auth: true, body: body);
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> approveUser(int userId) async {
    try {
      final response = await ApiService.post('users/$userId/approve/', auth: true);
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> rejectUser(int userId, {String? reason}) async {
    try {
      final response = await ApiService.post(
        'users/$userId/reject/',
        auth: true,
        body: {'reason': reason ?? 'Rejected by administrator.'},
      );
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteUser(int userId) async {
    try {
      await ApiService.delete('users/$userId/');
    } catch (e) {
      rethrow;
    }
  }

  // ==================== SPACES ====================
  static Future<List<dynamic>> getSpaces() async {
    try {
      final response = await ApiService.get('spaces/', auth: true);
      return _extractList(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateSpace(int spaceId, Map<String, dynamic> body) async {
    try {
      final response = await ApiService.patch('spaces/$spaceId/', auth: true, body: body);
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createSpace(Map<String, String> fields) async {
    try {
      final response = await ApiService.postMultipart(
        'spaces/create-space/',
        auth: true,
        fields: fields,
      );
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteSpace(int spaceId) async {
    try {
      await ApiService.delete('spaces/$spaceId/delete/');
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> setSpaceActive(int spaceId, bool active) async {
    try {
      final endpoint = active ? 'spaces/$spaceId/activate/' : 'spaces/$spaceId/deactivate/';
      final response = await ApiService.post(endpoint, auth: true);
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== RESERVATIONS ====================
  static Future<List<dynamic>> getReservations() async {
    try {
      final response = await ApiService.get('reservations/', auth: true);
      return _extractList(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> cancelReservation(int reservationId, String reason) async {
    try {
      final response = await ApiService.post(
        'reservations/$reservationId/cancel/',
        auth: true,
        body: {'cancellation_reason': reason},
      );
      return _toMap(response);
    } catch (e) {
      rethrow;
    }
  }
}
