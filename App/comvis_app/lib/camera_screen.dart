import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

// Variabel dan fungsi yang sebelumnya di sini, dipindahkan ke dalam _CameraScreenState

class _CameraScreenState extends State<CameraScreen> {
  // --- KONFIGURASI ---
  static const int SMOOTHING_FRAMES = 7;
  static const int DEADZONE_THRESHOLD = 4;

  // --- Variabel WebSocket ---
  // <<< PINDAHKAN KE SINI
  late WebSocketChannel _channel;
  bool _isConnected = false;

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

  // <<< PINDAHKAN FUNGSI KE SINI
  void _connectToESP() {
    try {
     
      final wsUrl = Uri.parse('ws://192.168.43.52:81');
      _channel = WebSocketChannel.connect(wsUrl);

      // Tunggu koneksi berhasil
      _channel.ready.then((_) {
        setState(() {
          _isConnected = true;
          _status = "Terhubung ke ESP! Kalibrasi selesai!";
        });
        
        // Listener untuk pesan dari ESP
        _channel.stream.listen((message) {
          debugPrint('Pesan dari ESP: $message');
        }, onDone: () {
          // Koneksi ditutup
          setState(() {
            _isConnected = false;
            _status = "Koneksi ke ESP terputus";
          });
        }, onError: (error) {
          debugPrint('WebSocket Error: $error');
          setState(() {
            _isConnected = false;
            _status = "Gagal terhubung ke ESP";
          });
        });
      });
    } catch (e) {
      debugPrint("Error saat koneksi: $e");
      setState(() {
        _status = "IP ESP salah atau tidak terjangkau";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);

    _selectedCameraIndex = widget.cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    if (_selectedCameraIndex == -1) {
      _selectedCameraIndex = 0;
    }

    _initializeCamera(_selectedCameraIndex);
  }

  void _initializeCamera(int cameraIndex) {
    // ... (tidak ada perubahan di sini)
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
    // ... (tidak ada perubahan di sini)
    if (widget.cameras.length < 2) return; 

    setState(() {
      _isCameraInitialized = false;
    });

    await _cameraController.stopImageStream();
    await _cameraController.dispose();

    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;

    _resetCalibration();
    _initializeCamera(_selectedCameraIndex);
  }

  void _startCalibration() {
    // <<< PANGGIL FUNGSI KONEKSI DI SINI
    _connectToESP(); // Coba hubungkan ke ESP saat kalibrasi

    setState(() {
      _isCalibrated = true;
      _status = "Mencoba terhubung & kalibrasi...";
      _rightHistory.clear();
      _leftHistory.clear();
      _upHistory.clear();
      _downHistory.clear();
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isConnected) {
        setState(() {
          _status = "";
        });
      }
    });
  }

  void _resetCalibration() {
    // ... (tidak ada perubahan di sini)
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
      // ... (tidak ada perubahan di bagian konversi gambar)
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
          // ... (tidak ada perubahan di kalkulasi persentase)
          final currentNosePos = Point(nose.position.x.toDouble(), nose.position.y.toDouble());
          final eyeCenterX = (leftEye.position.x + rightEye.position.x) / 2;
          final faceBox = face.boundingBox;
          final faceCenterY = faceBox.center.dy;

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

          // <<< TAMBAHKAN INI: Kirim data ke ESP jika terhubung
          if (_isConnected) {
            String dataToSend = 
              '{"kanan": $_turnRightPercent, "kiri": $_turnLeftPercent, "atas": $_nodUpPercent, "bawah": $_nodDownPercent}';
            _channel.sink.add(dataToSend);
          }

          setState(() {});
        }
      } else if (mounted) {
        // ... (tidak ada perubahan di sini)
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
    // <<< TAMBAHKAN INI: Tutup koneksi saat widget dihancurkan
    if (_isConnected) {
      _channel.sink.close();
    }
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan bisa disesuaikan untuk menunjukkan status koneksi
    Color statusColor = Colors.blue.withOpacity(0.8);
    if (_isCalibrated && _isConnected) {
      statusColor = Colors.green.withOpacity(0.8);
    } else if (_isCalibrated && !_isConnected) {
      statusColor = Colors.orange.withOpacity(0.8);
    }

    return Scaffold(
      appBar: AppBar(
        // <<< TAMBAHKAN INI: Indikator status koneksi di AppBar
        title: Text(_isConnected ? "Tersambung" : "Tidak Tersambung"),
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
                        color: statusColor, // <<< Gunakan warna status dinamis
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
                    // ... (tidak ada perubahan di sini)
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
      floatingActionButton: FloatingActionButton.extended( // Tombol selalu ada
              onPressed: _isCalibrated ? _resetCalibration : _startCalibration,
              label: Text(_isCalibrated ? 'Reset' : 'Kalibrasi & Sambungkan'),
              icon: Icon(_isCalibrated ? Icons.refresh : Icons.sensors),
              backgroundColor: _isCalibrated ? Colors.red : Theme.of(context).primaryColor,
            ),
    );
  }
}