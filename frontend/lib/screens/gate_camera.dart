import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class GateCameraScreen extends StatefulWidget {
  const GateCameraScreen({super.key});

  @override
  State<GateCameraScreen> createState() => _GateCameraScreenState();
}

class _GateCameraScreenState extends State<GateCameraScreen> {
  File? _selectedImage;
  String? _vehicleNumber;
  String? _vehicleType;
  bool _processing = false;
  String? _error;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _vehicleNumber = null;
          _vehicleType = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _captureImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _vehicleNumber = null;
          _vehicleType = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to capture image: $e';
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) {
      setState(() {
        _error = 'Please select an image first';
      });
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.163:8000/api/vehicle/process-image/'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          _selectedImage!.path,
        ),
      );

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        setState(() {
          _vehicleNumber = jsonResponse['vehicle_number']?.toString() ?? 'Not detected';
          _vehicleType = jsonResponse['vehicle_type']?.toString() ?? 'Not detected';
          _processing = false;
        });
      } else {
        setState(() {
          _error = jsonResponse['error'] ?? 'Failed to process image';
          _processing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error processing image: $e';
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Gate Camera - Vehicle Detection', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Selection Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vehicle Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Image Preview
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white10,
                      ),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No image selected',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Upload/Capture Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _captureImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Process Button
            if (_selectedImage != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _processImage,
                  icon: _processing
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black.withOpacity(0.7),
                            ),
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _processing ? 'Processing...' : 'Process Image',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: Colors.cyanAccent.withOpacity(0.5),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // Error Message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // Results Section
            if (_vehicleNumber != null || _vehicleType != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Detection Results',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Vehicle Number
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle Number',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _vehicleNumber ?? 'Not detected',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied: $_vehicleNumber'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy, color: Colors.white54),
                                iconSize: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Vehicle Type
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle Type',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _vehicleType ?? 'Not detected',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              textBaseline: TextBaseline.alphabetic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_vehicleNumber == null && _vehicleType == null && _selectedImage == null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white54,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Upload or capture a vehicle image to extract vehicle number and type using AI detection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
