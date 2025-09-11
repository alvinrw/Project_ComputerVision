import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';


class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // --- KONFIGURASI ---
  static const int SMOOTHING_FRAMES = 7;
  static const int DEADZONE_THRESHOLD = 4;

  // --- Variabel Kamera & Deteksi ---
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  late FaceDetector _faceDetector;
  bool _isProcessing = false;

  // Variabel untuk menyimpan index kamera yang dipilih
  late int _selectedCameraIndex;

  // --- Variabel Kalibrasi ---
  bool _isCalibrated = false;

  // --- Variabel untuk Smoothing ---
  final Queue<int> _rightHistory = Queue<int>();
  final Queue<int> _leftHistory = Queue<int>();
  final Queue<int> _upHistory = Queue<int>();
  final Queue<int> _downHistory = Queue<int>();

  // --- Variabel untuk Tampilan ---
  int _turnRightPercent = 0;
  int _turnLeftPercent = 0;
  int _nodUpPercent = 0;
  int _nodDownPercent = 0;
  String _status = "Posisikan wajah & tekan tombol kalibrasi";

  @override
  void initState() {
    super.initState();
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);

    // Cari index kamera depan sebagai default
    _selectedCameraIndex = widget.cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    // Jika tidak ada kamera depan, gunakan kamera pertama (biasanya belakang)
    if (_selectedCameraIndex == -1) {
      _selectedCameraIndex = 0;
    }

    // Panggil fungsi inisialisasi kamera
    _initializeCamera(_selectedCameraIndex);
  }

  void _initializeCamera(int cameraIndex) {
    final camera = widget.cameras[cameraIndex];

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _cameraController.initialize().then((_) {
      if (!mounted) return;
      _cameraController.startImageStream(_processCameraImage);
      setState(() {
        _isCameraInitialized = true;
      });
    }).catchError((error) {
      debugPrint("Gagal initialize kamera: $error");
    });
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return; // Jangan lakukan apa-apa jika cuma ada 1 kamera

    // Tampilkan loading
    setState(() {
      _isCameraInitialized = false;
    });

    // Hentikan dan buang controller lama
    await _cameraController.stopImageStream();
    await _cameraController.dispose();

    // Ganti index kamera ke kamera berikutnya
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;

    // Reset kalibrasi saat ganti kamera
    _resetCalibration();

    // Inisialisasi kamera baru
    _initializeCamera(_selectedCameraIndex);
  }

  void _startCalibration() {
    setState(() {
      _isCalibrated = true;
      _status = "Kalibrasi Selesai! SIAP!";
      _rightHistory.clear();
      _leftHistory.clear();
      _upHistory.clear();
      _downHistory.clear();
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _status = "";
        });
      }
    });
  }

  void _resetCalibration() {
    setState(() {
      _isCalibrated = false;
      _status = "Posisikan wajah & tekan tombol kalibrasi";
      _turnRightPercent = 0;
      _turnLeftPercent = 0;
      _nodUpPercent = 0;
      _nodDownPercent = 0;
      _rightHistory.clear();
      _leftHistory.clear();
      _upHistory.clear();
      _downHistory.clear();
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = widget.cameras[_selectedCameraIndex];
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
      
      InputImageMetadata metadata;
      if (camera.lensDirection == CameraLensDirection.front) {
        final rotation = _cameraController.value.deviceOrientation;
        final turns = rotation.index.toDouble();
        
        metadata = InputImageMetadata(
            size: imageSize,
            rotation: InputImageRotationValue.fromRawValue((camera.sensorOrientation + (turns * 90).toInt()) % 360) ?? InputImageRotation.rotation0deg,
            format: inputImageFormat,
            bytesPerRow: image.planes[0].bytesPerRow,
        );
      } else {
         metadata = InputImageMetadata(
            size: imageSize,
            rotation: imageRotation,
            format: inputImageFormat,
            bytesPerRow: image.planes[0].bytesPerRow,
        );
      }
      
      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (mounted && faces.isNotEmpty) {
        final Face face = faces.first;
        final FaceLandmark? nose = face.landmarks[FaceLandmarkType.noseBase];
        final FaceLandmark? leftEye = face.landmarks[FaceLandmarkType.leftEye];
        final FaceLandmark? rightEye = face.landmarks[FaceLandmarkType.rightEye];

        if (nose != null && leftEye != null && rightEye != null && _isCalibrated) {
          final currentNosePos = Point(nose.position.x.toDouble(), nose.position.y.toDouble());
          final eyeCenterX = (leftEye.position.x + rightEye.position.x) / 2;
          final faceBox = face.boundingBox;
          final faceCenterY = faceBox.center.dy;

          // <<< INI PERUBAHANNYA: Logika dx dibalik untuk menyesuaikan dengan mirror kamera depan
          final double dx = eyeCenterX - currentNosePos.x;
          final double dy = currentNosePos.y - faceCenterY;

          final screenWidth = image.width.toDouble();
          final screenHeight = image.height.toDouble();

          final rawRightPercent = (dx > 0) ? ((dx / (screenWidth * 0.25)) * 100).clamp(0, 100).toInt() : 0;
          final rawLeftPercent = (dx < 0) ? ((dx.abs() / (screenWidth * 0.25)) * 100).clamp(0, 100).toInt() : 0;
          final rawUpPercent = (dy < 0) ? ((dy.abs() / (screenHeight * 0.25)) * 100).clamp(0, 100).toInt() : 0;
          final rawDownPercent = (dy > 0) ? ((dy / (screenHeight * 0.25)) * 100).clamp(0, 100).toInt() : 0;

          _rightHistory.add(rawRightPercent);
          _leftHistory.add(rawLeftPercent);
          _upHistory.add(rawUpPercent);
          _downHistory.add(rawDownPercent);

          if (_rightHistory.length > SMOOTHING_FRAMES) _rightHistory.removeFirst();
          if (_leftHistory.length > SMOOTHING_FRAMES) _leftHistory.removeFirst();
          if (_upHistory.length > SMOOTHING_FRAMES) _upHistory.removeFirst();
          if (_downHistory.length > SMOOTHING_FRAMES) _downHistory.removeFirst();

          final smoothRight = _rightHistory.isEmpty ? 0 : (_rightHistory.reduce((a, b) => a + b) / _rightHistory.length).round();
          final smoothLeft = _leftHistory.isEmpty ? 0 : (_leftHistory.reduce((a, b) => a + b) / _leftHistory.length).round();
          final smoothUp = _upHistory.isEmpty ? 0 : (_upHistory.reduce((a, b) => a + b) / _upHistory.length).round();
          final smoothDown = _downHistory.isEmpty ? 0 : (_downHistory.reduce((a, b) => a + b) / _downHistory.length).round();

          _turnRightPercent = smoothRight > DEADZONE_THRESHOLD ? smoothRight : 0;
          _turnLeftPercent = smoothLeft > DEADZONE_THRESHOLD ? smoothLeft : 0;
          _nodUpPercent = smoothUp > DEADZONE_THRESHOLD ? smoothUp : 0;
          _nodDownPercent = smoothDown > DEADZONE_THRESHOLD ? smoothDown : 0;

          setState(() {});
        }
      } else if (mounted) {
        setState(() {
          _status = _isCalibrated ? "Wajah tidak terdeteksi" : "Posisikan wajah di dalam area";
        });
      }
    } catch (e) {
      debugPrint("Error di _processCameraImage: $e");
    }

    _isProcessing = false;
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deteksi Gerakan Kepala"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
            tooltip: 'Ganti Kamera',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetCalibration,
            tooltip: 'Reset Kalibrasi',
          ),
        ],
      ),
      body: _isCameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController),
                if (_status.isNotEmpty)
                  Positioned(
                    top: 50,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isCalibrated
                            ? Colors.green.withOpacity(0.8)
                            : Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (_isCalibrated)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Kanan: $_turnRightPercent%   Kiri: $_turnLeftPercent%",
                            style: const TextStyle(
                                color: Colors.yellow, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Atas: $_nodUpPercent%   Bawah: $_nodDownPercent%",
                            style: const TextStyle(
                                color: Colors.yellow, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: !_isCalibrated
          ? FloatingActionButton.extended(
              onPressed: _startCalibration,
              label: const Text('Kalibrasi'),
              icon: const Icon(Icons.center_focus_strong),
            )
          : null,
    );
  }
}