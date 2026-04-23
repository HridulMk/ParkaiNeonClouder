import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MultipartUploadFile {
  final String? path;
  final List<int>? bytes;
  final String filename;

  const MultipartUploadFile({
    required this.filename,
    this.path,
    this.bytes,
  });
}

class ApiService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';

  static String get baseUrl {
    if (kIsWeb) return 'https://parkaineonclouder.onrender.com/api';
    // ignore: do_not_use_environment
    return 'https://parkaineonclouder.onrender.com/api';
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _storage.read(key: _accessTokenKey);
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, String>> _multipartHeaders({bool auth = false}) async {
    final headers = <String, String>{};
    if (auth) {
      final token = await _storage.read(key: _accessTokenKey);
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String endpoint, {bool auth = true}) async {
    final response = await http
        .get(Uri.parse('$baseUrl/$endpoint'), headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 60));
    return _processResponse(response);
  }

  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body, bool auth = false, Duration? timeout}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body ?? {}),
        )
        .timeout(timeout ?? const Duration(seconds: 60));
    return _processResponse(response);
  }

  static Future<dynamic> postMultipart(
    String endpoint, {
    Map<String, String>? fields,
    Map<String, MultipartUploadFile>? files,
    bool auth = true,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/$endpoint'));
    request.headers.addAll(await _multipartHeaders(auth: auth));

    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    if (files != null) {
      for (final entry in files.entries) {
        final file = entry.value;
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          request.files.add(
            http.MultipartFile.fromBytes(entry.key, file.bytes!, filename: file.filename),
          );
          continue;
        }
        if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, file.path!, filename: file.filename),
          );
        }
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _processResponse(response);
  }

  static Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/$endpoint'),
          headers: await _headers(auth: true),
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 60));
    return _processResponse(response);
  }

  static Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body, bool auth = true}) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/$endpoint'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 60));
    return _processResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/$endpoint'), headers: await _headers(auth: true))
        .timeout(const Duration(seconds: 60));
    return _processResponse(response);
  }

  static dynamic _processResponse(http.Response response) {
    final body = response.body;

    // Guard against HTML error pages (e.g. Render 502/504 gateway responses)
    dynamic data;
    try {
      data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    } catch (_) {
      // Server returned non-JSON (HTML gateway error page)
      final code = response.statusCode;
      if (code == 502 || code == 503 || code == 504) {
        throw Exception('Server gateway error ($code). The AI analysis may have timed out — try a shorter video.');
      }
      throw Exception('Server returned an unexpected response (status $code).');
    }

    switch (response.statusCode) {
      case 200:
      case 201:
      case 202:
        return data;
      case 400:
        throw Exception(_extractErrorMessage(data) ?? 'Bad request');
      case 401:
        throw Exception('Unauthorized');
      case 403:
        throw Exception('Permission denied');
      case 404:
        throw Exception('Resource not found');
      case 500:
        throw Exception(_extractErrorMessage(data) ?? 'Server error (500) — check Render logs for details.');
      default:
        throw Exception('Something went wrong (${response.statusCode})');
    }
  }

  static String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) return data['detail'].toString();
      if (data['error'] != null) return data['error'].toString();
      if (data['non_field_errors'] is List && (data['non_field_errors'] as List).isNotEmpty) {
        return data['non_field_errors'].first.toString();
      }
    }
    return null;
  }

  static Future<void> storeTokens(String access, String refresh) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  static Future<String?> getAccessToken() async => _storage.read(key: _accessTokenKey);

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
