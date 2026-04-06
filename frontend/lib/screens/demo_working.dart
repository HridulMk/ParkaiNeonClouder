import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:parking_app/services/auth_service.dart';
import 'package:parking_app/services/parking_service.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_map/flutter_map.dart';

class DemoWorkingScreen extends StatefulWidget {
  const DemoWorkingScreen({super.key});

  @override
  State<DemoWorkingScreen> createState() => _DemoWorkingScreenState();
}

class _DemoWorkingScreenState extends State<DemoWorkingScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController(text: 'Demo Parking Space');
  final _locationController = TextEditingController(text: 'Demo City Center');
  final _slotsController = TextEditingController(text: '5');
  final _openTimeController = TextEditingController(text: '08:00:00');
  final _closeTimeController = TextEditingController(text: '22:00:00');
  final _mapController = TextEditingController();

  PlatformFile? _selectedVideo;
  VideoPlayerController? _videoController;
  VideoPlayerController? _processedVideoController;
  String? _processedVideoUrl;
  String? _lastErrorMessage;
  String? _sessionId;
  List<bool> _slotStatus = [];
  bool _spaceCreated = false;
  int? _createdSpaceId;
  bool _videoSaved = false;
  bool _isSubmitting = false;
  bool _isSavingVideo = false;
  bool _isProcessing = false;
  String _statusLabel = '';
  int _occupiedSlots = 0;
  int _freeSlots = 0;
  double _processingProgress = 0;
  Timer? _fakeProgressTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final List<List<Offset>> _polygons = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _slotsController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _mapController.dispose();
    _videoController?.dispose();
    _processedVideoController?.dispose();
    _fakeProgressTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
    if (result != null) {
      setState(() {
        _selectedVideo = result.files.single;
        _processedVideoUrl = null;
        _processedVideoController?.dispose();
        _processedVideoController = null;
        _lastErrorMessage = null;
        _videoSaved = false;
      });
      if (kIsWeb && _selectedVideo?.bytes != null) {
        final dataUrl = Uri.dataFromBytes(
          _selectedVideo!.bytes!,
          mimeType: 'video/mp4',
        ).toString();
        _videoController = VideoPlayerController.networkUrl(Uri.parse(dataUrl));
        await _videoController!.initialize();
        setState(() {});
        _animationController.forward(from: 0.0);
      } else if (!kIsWeb && _selectedVideo?.path != null) {
        _videoController = VideoPlayerController.file(File(_selectedVideo!.path!));
        await _videoController!.initialize();
        setState(() {});
        _animationController.forward(from: 0.0);
      }
    }
  }

  Future<void> _createSpace() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login as vendor/admin to add a parking space.')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    final slots = int.tryParse(_slotsController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        slots == null ||
        slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all required fields before adding the space.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ParkingService.createParkingSpace(
      name: _nameController.text.trim(),
      numberOfSlots: slots,
      location: _locationController.text.trim(),
      openTime: _openTimeController.text.trim(),
      closeTime: _closeTimeController.text.trim(),
      googleMapLink: _mapController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      setState(() {
        _spaceCreated = true;
        _createdSpaceId = result['space']?['id'] as int?;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parking space created! Now upload the CCTV video.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to create parking space')),
      );
    }
  }

 // IMPORTANT

Future<void> _saveVideo() async {
  print("🔥 Save button clicked");

  if (_selectedVideo == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚠️ Please select a video first')),
    );
    return;
  }

  setState(() => _isSavingVideo = true);

  try {
    final result = await ParkingService.saveVideo(
      // ✅ KEY FIX
      videoPath: kIsWeb ? null : _selectedVideo?.path,
      videoBytes: kIsWeb ? _selectedVideo?.bytes : null,
      videoFileName: _selectedVideo?.name,
    );

    print("🔥 API RESULT: $result");

    if (!mounted) return;

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${result['error']}')),
      );
      return;
    }

    setState(() {
      _videoSaved = true;
      _sessionId = result['session_id'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Video saved successfully')),
    );

  } catch (e) {
    print("🔥 ERROR: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Exception: $e')),
    );
  }

  setState(() => _isSavingVideo = false);
}

  Future<void> _savePolygons() async {
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the video first.')),
      );
      return;
    }
    final result = await ParkingService.savePolygons(_polygons, sessionId: _sessionId!);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polygons saved successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save polygons: ${result['error']}')),
      );
    }
  }

Future<void> _submitDemo() async {
  if (!_spaceCreated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please add a parking space first.')),
    );
    return;
  }

  if (_sessionId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please save the video and polygons first.')),
    );
    return;
  }

  print("🚀 Starting analysis for session: $_sessionId");

  setState(() {
    _isSubmitting = true;
    _isProcessing = true;
    _processingProgress = 0;
    _statusLabel = 'Starting AI analysis...';
    _lastErrorMessage = null;
  });

  try {
    final jobFuture = ParkingService.runAnalysisAndWait(_sessionId!);

    // 🔥 Fake progress (safe)
    final stages = [
      {'label': 'Initializing YOLO model...', 'target': 0.15, 'ms': 800},
      {'label': 'Loading video frames...', 'target': 0.30, 'ms': 700},
      {'label': 'Detecting vehicles...', 'target': 0.50, 'ms': 1200},
      {'label': 'Analyzing parking zones...', 'target': 0.68, 'ms': 1000},
      {'label': 'Counting occupancy...', 'target': 0.82, 'ms': 900},
      {'label': 'Generating output video...', 'target': 0.93, 'ms': 800},
      {'label': 'Finalizing results...', 'target': 0.98, 'ms': 600},
    ];

    for (final stage in stages) {
      if (!mounted || !_isProcessing) break;

      final label = stage['label'] as String;
      final target = stage['target'] as double;
      final ms = stage['ms'] as int;

      setState(() => _statusLabel = label);

      const steps = 20;
      final stepMs = ms ~/ steps;
      final start = _processingProgress;

      for (int i = 1; i <= steps; i++) {
        await Future.delayed(Duration(milliseconds: stepMs));

        if (!mounted || !_isProcessing) break;

        setState(() {
          _processingProgress = start + (target - start) * (i / steps);
        });
      }
    }

    // 🔥 Wait for backend result
    final result = await jobFuture;

    print("🔥 ANALYSIS RESULT: $result");

    if (!mounted) return;

    // ❌ ERROR CASE
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Analysis failed');
    }

    setState(() => _processingProgress = 1.0);
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final outputUrl = result['outputVideoUrl'] as String?;

    VideoPlayerController? newController;

    if (outputUrl != null && outputUrl.isNotEmpty) {
      _processedVideoUrl = outputUrl;

      try {
        print("🎥 Loading video: $outputUrl");

        newController = VideoPlayerController.networkUrl(Uri.parse(outputUrl));
        await newController.initialize();

        print("✅ Video loaded successfully");

      } catch (e) {
        print("❌ Video load failed: $e");

        // Show more detailed error
        String errorMsg = 'Video generated but failed to load in app';
        if (e.toString().contains('Format')) {
          errorMsg += ' (unsupported video format)';
        } else if (e.toString().contains('Network')) {
          errorMsg += ' (network error)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } else {
      throw Exception("No output video URL received");
    }

    if (!mounted) return;

    final occupied = result['occupied'] ?? 0;
    final free = result['free'] ?? 0;
    final total = result['total'] ?? 0;

    setState(() {
      _isProcessing = false;
      _isSubmitting = false;
      _statusLabel = '';
      _occupiedSlots = occupied;
      _freeSlots = free;
      _slotStatus = List.generate(total, (i) => i < occupied);

      if (newController != null) {
        _processedVideoController?.dispose();
        _processedVideoController = newController;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ AI analysis complete!')),
    );

  } catch (e) {
    print("❌ ERROR in submitDemo: $e");

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isProcessing = false;
      _processingProgress = 0;
      _statusLabel = '';
      _lastErrorMessage = e.toString().replaceFirst('Exception: ', '');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ ${_lastErrorMessage!}')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue.withOpacity(0.1), Colors.cyan.withOpacity(0.1)],
                    ),
                  ),
                  child: const FlexibleSpaceBar(
                    title: Text(
                      'AI Parking Demo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    centerTitle: true,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIntroCard(),
                      const SizedBox(height: 24),
                      _buildFormCard(),
                      const SizedBox(height: 16),
                      _buildAddSpaceButton(),
                      const SizedBox(height: 24),
                      _buildVideoUploadSection(),
                      if (_selectedVideo != null) _buildVideoPreview(),
                      if (_selectedVideo != null) _buildSaveVideoButton(),
                      if (_selectedVideo != null) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Mark Parking Slots',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPolygonEditor(),
                        const SizedBox(height: 16),
                        _buildSavePolygonsButton(),
                      ],
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      if (_processedVideoUrl != null || _processedVideoController != null)
                        const SizedBox(height: 24),
                      if (_processedVideoUrl != null || _processedVideoController != null)
                        _buildResultsCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy, color: Colors.cyan[400], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Experience AI-Powered Parking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload a CCTV video and watch our AI model analyze parking slots in real-time. It detects vehicles, counts occupied and free spaces, and provides instant insights.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Parking Space Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_spaceCreated) ...[
                const SizedBox(width: 8),
                Icon(Icons.lock, color: Colors.white38, size: 16),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_nameController, 'Parking Space Name', Icons.local_parking),
          const SizedBox(height: 12),
          _buildTextField(_locationController, 'Location', Icons.location_on),
          const SizedBox(height: 12),
          _buildTextField(_slotsController, 'Number of Slots', Icons.grid_view, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_openTimeController, 'Open Time', Icons.access_time)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_closeTimeController, 'Close Time', Icons.access_time)),
            ],
          ),
          const SizedBox(height: 12),
          _buildLocationSection(),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pickLocationOnMap,
            icon: const Icon(Icons.map),
            label: Text(_pickedLatLng == null ? 'Pick Location on Map' : 'Location Picked ✓ (tap to change)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _pickedLatLng == null ? Colors.cyan[700] : Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_pickedLatLng != null) ...[
          const SizedBox(height: 6),
          Text(
            'Lat: ${_pickedLatLng!.latitude.toStringAsFixed(6)}, Lng: ${_pickedLatLng!.longitude.toStringAsFixed(6)}',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        _buildTextField(_mapController, 'Or paste Google Maps link', Icons.link),
      ],
    );
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.of(context).push<ll.LatLng>(
      MaterialPageRoute(builder: (_) => _LocationPickerScreen(initial: _pickedLatLng)),
    );
    if (result != null) {
      setState(() {
        _pickedLatLng = result;
        _locationController.text = '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
        _mapController.text = 'https://www.google.com/maps?q=${result.latitude},${result.longitude}';
      });
    }
  }

  ll.LatLng? _pickedLatLng;

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_spaceCreated,
      style: TextStyle(color: _spaceCreated ? Colors.white38 : Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.cyan[400]),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.cyan, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildVideoUploadSection() {
    return Opacity(
      opacity: _spaceCreated ? 1.0 : 0.4,
      child: AbsorbPointer(
        absorbing: !_spaceCreated,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(Icons.videocam, color: Colors.cyan[400], size: 48),
              const SizedBox(height: 12),
              const Text(
                'Upload CCTV Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a video file to analyze parking occupancy',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_selectedVideo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Selected file: ${_selectedVideo!.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (!_spaceCreated)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Add a parking space first to enable video upload',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              'Selected: ${_selectedVideo!.name}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (_videoController != null && _videoController!.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            if (_videoController != null && _videoController!.value.isInitialized)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                      icon: Icon(
                        _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.cyan,
                          bufferedColor: Colors.cyanAccent,
                          backgroundColor: Colors.white24,
                        ),
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

  Widget _buildProcessedVideoPlayer() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie_filter, color: Colors.cyan[400]),
              const SizedBox(width: 8),
              const Text(
                'Processed Simulation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_processedVideoController != null && _processedVideoController!.value.isInitialized) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _processedVideoController!.value.aspectRatio,
                child: VideoPlayer(_processedVideoController!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _processedVideoController!.value.isPlaying
                            ? _processedVideoController!.pause()
                            : _processedVideoController!.play();
                      });
                    },
                    icon: Icon(
                      _processedVideoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _processedVideoController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.cyan,
                        bufferedColor: Colors.cyanAccent,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_processedVideoUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI processing complete! Video generated successfully.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Try to load video again
                            try {
                              final controller = VideoPlayerController.networkUrl(Uri.parse(_processedVideoUrl!));
                              await controller.initialize();
                              setState(() {
                                _processedVideoController?.dispose();
                                _processedVideoController = controller;
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to load video: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Load Video'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (_processedVideoUrl != null) {
                              final uri = Uri.parse(_processedVideoUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open video')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Open Video'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Video URL:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _processedVideoUrl!,
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveVideoButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: _videoSaved
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.withOpacity(0.15),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Video saved to server!',
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _videoSaved = false),
                      child: const Text('Re-save', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              )
            : ElevatedButton.icon(
                onPressed: _isSavingVideo ? null : _saveVideo,
                icon: _isSavingVideo
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt),
                label: Text(_isSavingVideo ? 'Saving...' : 'Save Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }

  Widget _buildAddSpaceButton() {
    if (_spaceCreated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.green.withOpacity(0.15),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Parking space created successfully!',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _spaceCreated = false;
                _createdSpaceId = null;
              }),
              child: const Text('Edit', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _createSpace,
        icon: _isSubmitting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_business),
        label: Text(_isSubmitting ? 'Creating...' : 'Add Parking Space'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSavePolygonsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _polygons.isEmpty ? null : _savePolygons,
        icon: const Icon(Icons.save),
        label: const Text('Save Polygons'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
  final isDisabled = _isSubmitting || _isProcessing || _sessionId == null;

  return SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: isDisabled ? null : _submitDemo,
          icon: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow),
          label: _isProcessing
              ? const Text('Processing with AI...')
              : Text(_isSubmitting ? 'Starting...' : 'Run AI Analysis'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),

        // 🔥 Processing UI
        if (_isProcessing) ...[
          const SizedBox(height: 12),

          Text(
            '$_statusLabel  ${(_processingProgress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _processingProgress.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
              minHeight: 6,
            ),
          ),
        ],

        // 🔥 ERROR UI (Improved)
        if (_lastErrorMessage != null && !_isProcessing) ...[
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastErrorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildResultsCard() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white.withOpacity(0.1),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(Icons.movie_filter, color: Colors.cyan[400], size: 28),
            const SizedBox(width: 12),
            const Text(
              'AI Analysis Results',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_processedVideoController != null && _processedVideoController!.value.isInitialized)
          _buildProcessedVideoPlayer()
        else if (_processedVideoUrl != null)
          _buildProcessedVideoPlayer()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.05),
            ),
            child: const Text(
              'Processed video output will appear here after AI analysis completes.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
      ],
    ),
  );
}

  Widget _buildPolygonEditor() {
    final width = MediaQuery.of(context).size.width - 40;

    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Container(
        width: width,
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.2),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Text(
          'Load a video to mark parking zones',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final videoSize = _videoController!.value.size;
    final displayHeight = width / videoSize.width * videoSize.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: width,
          height: displayHeight,
          child: PolygonEditor(
            polygons: _polygons,
            slotStatus: _slotStatus,
            onChanged: (polys) => setState(() {}),
            background: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _polygons.isEmpty ? 'Tap to add points' : '${_polygons.length} zone(s) defined',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LocationPickerScreen extends StatefulWidget {
  final ll.LatLng? initial;
  const _LocationPickerScreen({this.initial});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  ll.LatLng? _picked;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final center = _picked ?? const ll.LatLng(3.1390, 101.6869);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          if (_picked != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _picked),
              child: const Text('Confirm', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              onTap: (_, latlng) => setState(() => _picked = latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.parking_app',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (_picked != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lat: ${_picked!.latitude.toStringAsFixed(6)}, Lng: ${_picked!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: const Text('Tap on the map to pin the parking location', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PolygonEditor extends StatefulWidget {
  final List<List<Offset>> polygons;
  final ValueChanged<List<List<Offset>>> onChanged;
  final Widget background;
  final List<bool> slotStatus;

  const PolygonEditor({
    super.key,
    required this.polygons,
    required this.onChanged,
    required this.background,
    this.slotStatus = const [],
  });

  @override
  State<PolygonEditor> createState() => _PolygonEditorState();
}

class _PolygonEditorState extends State<PolygonEditor> {
  List<List<Offset>> get _polygons => widget.polygons;
  List<Offset> _currentPolygon = [];

  void _handleTap(TapUpDetails details) {
    final localPos = details.localPosition;
    setState(() {
      _currentPolygon.add(localPos);
    });
  }

  void _finishPolygon() {
    if (_currentPolygon.length < 3) return;
    setState(() {
      _polygons.add(List<Offset>.from(_currentPolygon));
      _currentPolygon = [];
    });
    widget.onChanged(_polygons);
  }

  void _undoLastPoint() {
    if (_currentPolygon.isNotEmpty) {
      setState(() {
        _currentPolygon.removeLast();
      });
    }
  }

  void _clearAll() {
    setState(() {
      _polygons.clear();
      _currentPolygon.clear();
    });
    widget.onChanged(_polygons);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 0.7,
            maxScale: 4.0,
            child: GestureDetector(
              onTapUp: _handleTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.background,
                    CustomPaint(
                      painter: _PolygonPainter(
                        polygons: _polygons,
                        currentPolygon: _currentPolygon,
                        slotStatus: widget.slotStatus,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: _finishPolygon,
              child: const Text('Finish Polygon'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _undoLastPoint,
              child: const Text('Undo Point'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear All'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolygonPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final List<Offset> currentPolygon;
  final List<bool> slotStatus; // true = occupied, false = free

  _PolygonPainter({
    required this.polygons,
    required this.currentPolygon,
    required this.slotStatus,
  });

 @override
void paint(Canvas canvas, Size size) {
  for (int i = 0; i < polygons.length; i++) {
    final poly = polygons[i];

    if (poly.length < 2) continue;

    // ✅ Get slot status safely
    final isOccupied =
        (i < slotStatus.length) ? slotStatus[i] : false;

    // ✅ Dynamic color based on AI result
    final fillPaint = Paint()
      ..color = isOccupied
          ? Colors.red.withOpacity(0.4)
          : Colors.green.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isOccupied ? Colors.red : Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()..addPolygon(poly, true);

canvas.drawPath(path, fillPaint);
canvas.drawPath(path, borderPaint);

// ✅ Calculate center of polygon
double centerX = 0;
double centerY = 0;

for (final p in poly) {
  centerX += p.dx;
  centerY += p.dy;
}

centerX /= poly.length;
centerY /= poly.length;

// ✅ Draw slot number text
final textPainter = TextPainter(
  text: TextSpan(
    text: 'S${i + 1}', // Slot number
    style: TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
  ),
  textDirection: TextDirection.ltr,
);

textPainter.layout();

// Center text
final offset = Offset(
  centerX - textPainter.width / 2,
  centerY - textPainter.height / 2,
);

textPainter.paint(canvas, offset);
  }

  // ✏️ Drawing current polygon (while user is marking)
  if (currentPolygon.isNotEmpty) {
    final path = Path()..addPolygon(currentPolygon, false);

    final currentPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, currentPaint);

    for (final p in currentPolygon) {
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF38BDF8));
    }
  }
}

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) {
    return oldDelegate.polygons != polygons ||
        oldDelegate.currentPolygon != currentPolygon ||
        oldDelegate.slotStatus != slotStatus;
  }
}
