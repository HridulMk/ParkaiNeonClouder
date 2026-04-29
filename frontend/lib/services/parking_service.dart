import 'dart:convert';
import 'dart:ui';

import '../models/parking_slot.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;

class ParkingService {
  static List<dynamic> _normalizeListResponse(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic> && response['results'] is List) {
      return response['results'] as List<dynamic>;
    }
    return <dynamic>[];
  }

  static Future<List<dynamic>> getParkingSpaces() async {
    try {
      final response = await ApiService.get('spaces/', auth: true);
      return _normalizeListResponse(response);
    } catch (e) {
      throw Exception('Failed to load parking spaces: $e');
    }
  }

  static Future<List<dynamic>> getSlots(int spaceId) async {
    try {
      final response = await ApiService.get('slots/?space=$spaceId', auth: true);
      return _normalizeListResponse(response);
    } catch (e) {
      throw Exception('Failed to load parking slots: $e');
    }
  }

  static Future<List<ParkingSlot>> getParkingSlots() async {
    try {
      final response = await ApiService.get('slots/', auth: true);
      final rows = _normalizeListResponse(response);
      return rows.map((slotData) => ParkingSlot.fromJson(slotData as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load all parking slots: $e');
    }
  }

  static Future<Map<String, dynamic>> reserveSlot({
    required int spaceId, 
    required int slotId,
    required String vehicleNumber,
    required String vehicleType,
    required String? expectedCheckinTime,
    required int? estimatedDurationMins,
  }) async {
    try {
      final response = await ApiService.post('spaces/$spaceId/slots/$slotId/book/', auth: true, body: {
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
        if (expectedCheckinTime != null) 'expected_checkin_time': expectedCheckinTime,
        if (estimatedDurationMins != null) 'estimated_duration_mins': estimatedDurationMins.toString(),
      });
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<List<dynamic>> getReservations() async {
    try {
      final response = await ApiService.get('reservations/', auth: true);
      return _normalizeListResponse(response);
    } catch (e) {
      throw Exception('Failed to fetch reservations: $e');
    }
  }

  static Future<Map<String, dynamic>> payReservation(int reservationId) async {
    try {
      final response = await ApiService.post('reservations/$reservationId/pay_booking/', auth: true);
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<String> getReservationQrUrl(int reservationId) async {
    try {
      final response = await ApiService.get('reservations/$reservationId/qr/', auth: true);
      final url = response['qr_image_url']?.toString() ?? '';
      if (url.isEmpty) throw Exception('QR image not available');
      return url;
    } catch (e) {
      throw Exception('Failed to get QR URL: $e');
    }
  }

  static Future<List<int>> getReservationQrImageBytes(int reservationId) async {
    final url = await getReservationQrUrl(reservationId);
    final token = await ApiService.getAccessToken();
    final response = await http.get(
      Uri.parse(url),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    if (response.statusCode != 200) throw Exception('Failed to download QR image');
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> scanQrCode(String qrCode) async {
    try {
      final response = await ApiService.post(
        'reservations/scan/',
        auth: true,
        body: {'qr_code': qrCode},
      );
      return {
        'success': true,
        'action': response['action'],
        'message': response['message'],
        'reservation': response['reservation'],
      };
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> checkIn(int reservationId) async {
    try {
      final response = await ApiService.post('reservations/$reservationId/checkin/', auth: true);
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> checkOut(int reservationId) async {
    try {
      final response = await ApiService.post('reservations/$reservationId/checkout/', auth: true);
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> payFinal(int reservationId) async {
    try {
      final response = await ApiService.post('reservations/$reservationId/pay_final/', auth: true);
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await ApiService.get('wallet/me/', auth: true);
      return {'success': true, 'wallet': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> topUpWallet(double amount) async {
    try {
      final response = await ApiService.post('wallet/topup/', auth: true, body: {'amount': amount.toStringAsFixed(2)});
      return {'success': true, 'wallet': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> payBookingWithWallet(int reservationId) async {
    try {
      final response = await ApiService.post('wallet/pay-booking/$reservationId/', auth: true);
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> payFinalWithWallet(int reservationId) async {
    try {
      final response = await ApiService.post('wallet/pay-final/$reservationId/', auth: true);
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> cancelReservation(int reservationId, {String? cancellationReason}) async {
    try {
      final body = cancellationReason != null ? {'cancellation_reason': cancellationReason} : <String, dynamic>{};
      final response = await ApiService.post('reservations/$reservationId/cancel/', auth: true, body: body);
      return {'success': true, 'reservation': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> updateParkingSpace({
    required int spaceId,
    String? openTime,
    String? closeTime,
    String? name,
    String? location,
    String? googleMapLink,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (openTime != null) body['open_time'] = openTime;
      if (closeTime != null) body['close_time'] = closeTime;
      if (name != null) body['name'] = name;
      if (location != null) body['location'] = location;
      if (googleMapLink != null) body['google_map_link'] = googleMapLink;
      final response = await ApiService.patch('spaces/$spaceId/', auth: true, body: body);
      return {'success': true, 'space': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> deleteParkingSpace(int spaceId) async {
    try {
      await ApiService.delete('spaces/$spaceId/delete/');
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> createParkingSpace({
    required String name,
    required int numberOfSlots,
    required String location,
    required String openTime,
    required String closeTime,
    String? googleMapLink,
    String? imagePath,
    List<int>? imageBytes,
    String? imageFileName,
    String? cctvVideoPath,
    List<int>? cctvVideoBytes,
    String? cctvVideoFileName,
    int? vendorId,
  }) async {
    try {
      final files = <String, MultipartUploadFile>{};

      if ((imageBytes != null && imageBytes.isNotEmpty) || (imagePath != null && imagePath.isNotEmpty)) {
        files['parking_image'] = MultipartUploadFile(
          filename: imageFileName ?? 'parking_image.jpg',
          path: imagePath,
          bytes: imageBytes,
        );
      }

      if ((cctvVideoBytes != null && cctvVideoBytes.isNotEmpty) || (cctvVideoPath != null && cctvVideoPath.isNotEmpty)) {
        files['cctv_video'] = MultipartUploadFile(
          filename: cctvVideoFileName ?? 'cctv_video.mp4',
          path: cctvVideoPath,
          bytes: cctvVideoBytes,
        );
      }

      final fields = <String, String>{
        'name': name,
        'number_of_slots': numberOfSlots.toString(),
        'location': location,
        'open_time': openTime,
        'close_time': closeTime,
        'google_map_link': googleMapLink ?? '',
      };

      if (vendorId != null) {
        fields['vendor'] = vendorId.toString();
      }

      final response = await ApiService.postMultipart(
        'spaces/create-space/',
        auth: true,
        fields: fields,
        files: files,
      );
      return {'success': true, 'space': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

 static Future<Map<String, dynamic>> saveVideo({
  String? videoPath,
  List<int>? videoBytes,
  String? videoFileName,
}) async {
  try {
    if ((videoBytes == null || videoBytes.isEmpty) &&
        (videoPath == null || videoPath.isEmpty)) {
      return {'success': false, 'error': 'No video selected'};
    }

    final files = <String, MultipartUploadFile>{};

    // ✅ SEND ONLY ONE (IMPORTANT)
    if (videoBytes != null && videoBytes.isNotEmpty) {
      files['video'] = MultipartUploadFile(
        filename: videoFileName ?? 'video.mp4',
        bytes: videoBytes,
      );
    } else if (videoPath != null && videoPath.isNotEmpty) {
      files['video'] = MultipartUploadFile(
        filename: videoFileName ?? 'video.mp4',
        path: videoPath,
      );
    }

    final response = await ApiService.postMultipart(
      'parking-lot/save-video/',
      auth: true,
      files: files,
    );

    print("🔥 RESPONSE: $response");

    if (response is Map<String, dynamic> && response['success'] == true) {
      return {
        'success': true,
        'size': response['size'],
        'session_id': response['session_id'],
        'video_url': response['video_url'], 
      };
    }

    return {
      'success': false,
      'error': response?.toString() ?? 'Unexpected response'
    };
  } catch (e) {
    return {
      'success': false,
      'error': e.toString().replaceFirst('Exception: ', '')
    };
  }
}

  static Future<Map<String, dynamic>> savePolygons(List<List<Offset>> polygons, {
    required String sessionId,
    required String videoUrl,
    double displayWidth = 0,
    double displayHeight = 0,
  }) async {
    try {
      final payloadPolygons = polygons
          .map((poly) => poly.map((p) => [p.dx, p.dy]).toList())
          .toList();
      final fields = <String, String>{
        'session_id': sessionId,
        'video_url': videoUrl,
        'polygons': jsonEncode(payloadPolygons),
        'display_width': displayWidth.toString(),
        'display_height': displayHeight.toString(),
      };
      final response = await ApiService.postMultipart(
        'parking-lot/polygons/',
        auth: true,
        fields: fields,
      );
      if (response is Map<String, dynamic>) {
        return {
          'success': true,
          'polygons': response['polygons'],
          'polygon_url': response['polygon_url'],
        };
      }
      return {'success': false, 'error': 'Unexpected response from server'};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> loadPolygons({required String sessionId}) async {
    try {
      final response = await ApiService.get(
        'parking-lot/polygons/?session_id=$sessionId',
        auth: true,
      );
      if (response is Map<String, dynamic> && response['polygons'] is List) {
        final polygonsData = response['polygons'] as List;
        final polygons = polygonsData
            .map((poly) => (poly as List)
                .map((point) => Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()))
                .toList())
            .toList();
        return {'success': true, 'polygons': polygons};
      }
      return {'success': false, 'error': 'Unexpected response from server'};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static String _normalizeMediaUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final base = ApiService.baseUrl.replaceFirst('/api', '');
    return '$base${url.startsWith('/') ? '' : '/'}$url';
  }

  static Future<Map<String, dynamic>> runAnalysisAndWait(
    String sessionId,
    String videoUrl, {
    String? polygonUrl,
  }) async {
    try {
      print("\u1f680 Running analysis for session: $sessionId");

      final body = <String, dynamic>{
        'session_id': sessionId,
        'video_url': videoUrl,
        if (polygonUrl != null) 'polygon_url': polygonUrl,
      };

      final response = await ApiService.post(
        'parking-lot/run-analysis/',
        auth: true,
        body: body,
        timeout: const Duration(minutes: 5),
      );

      print("\uD83D\uDD25 RAW RESPONSE: $response");

      if (response is! Map<String, dynamic>) {
        return {'success': false, 'error': 'Invalid server response'};
      }

      if (response['success'] == false) {
        return {'success': false, 'error': response['error'] ?? 'Server error occurred'};
      }

      var outputUrl = response['output_video_url']?.toString();

      if (outputUrl == null || outputUrl.isEmpty) {
        return {'success': false, 'error': 'Output video not generated'};
      }

      if (!outputUrl.startsWith('http')) {
        outputUrl = _normalizeMediaUrl(outputUrl);
      }

      return {
        'success': true,
        'outputVideoUrl': outputUrl,
        'occupied': response['occupied'] ?? 0,
        'free': response['free'] ?? 0,
        'total': response['total'] ?? 0,
        'fps': (response['fps'] ?? 20.0).toDouble(),
        'frameData': List<int>.from(response['frame_data'] ?? []),
      };
    } catch (e) {
      print("\u274C ERROR in runAnalysis: $e");
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }



  static Future<List<dynamic>> getUsers() async {
    final response = await ApiService.get('users/', auth: true);
    return _normalizeListResponse(response);
  }

  static Future<Map<String, dynamic>> updateUserStatus(int userId, bool isActive) async {
    try {
      final response = await ApiService.patch('users/$userId/', auth: true, body: {'is_active': isActive});
      return {'success': true, 'user': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> setSpaceActive(int spaceId, bool isActive) async {
    try {
      final endpoint = isActive ? 'spaces/$spaceId/activate/' : 'spaces/$spaceId/deactivate/';
      final response = await ApiService.post(endpoint, auth: true);
      return {'success': true, 'data': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<List<dynamic>> getVehicleLogs() async {
    try {
      final response = await ApiService.get('vehicle-logs/', auth: true);
      return _normalizeListResponse(response);
    } catch (e) {
      throw Exception('Failed to load vehicle logs: $e');
    }
  }

  static Future<Map<String, dynamic>> createVehicleLog({
    required int spaceId,
    required String vehicleNumber,
    String? vehicleType,
    int? slotId,
  }) async {
    try {
      final body = <String, dynamic>{
        'space': spaceId,
        'vehicle_number': vehicleNumber,
        'check_in_time': DateTime.now().toIso8601String(),
      };
      if (vehicleType != null) body['vehicle_type'] = vehicleType;
      if (slotId != null) body['slot'] = slotId;

      final response = await ApiService.post('vehicle-logs/', auth: true, body: body);
      return {'success': true, 'log': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> checkOutVehicle(int logId) async {
    try {
      final response = await ApiService.post('vehicle-logs/$logId/check_out/', auth: true);
      return {'success': true, 'log': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> setSlotActive(int slotId, bool isActive) async {
    try {
      final endpoint = isActive ? 'slots/$slotId/activate/' : 'slots/$slotId/deactivate/';
      final response = await ApiService.post(endpoint, auth: true);
      return {'success': true, 'data': response};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> processVehicleImage({
    required List<int> imageBytes,
    required String imageFileName,
  }) async {
    try {
      final response = await ApiService.postMultipart(
        'vehicle/process-image/',
        auth: true,
        files: {
          'image': MultipartUploadFile(
            filename: imageFileName,
            bytes: imageBytes,
          ),
        },
      );
      return {
        'success': true,
        'vehicle_number': response['vehicle_number']?.toString() ?? 'NOT_DETECTED',
        'vehicle_type': response['vehicle_type']?.toString() ?? 'UNKNOWN',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }
}
