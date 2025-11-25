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

class _CameraScreenState extends State<CameraScreen> {
  // --- KONFIGURASI ---
  static const int SMOOTHING_FRAMES = 7;
  static const int DEADZONE_THRESHOLD = 4;
  static const double MAX_YAW_DEGREE = 35.0; 
  static const double VERTICAL_SCALE_FACTOR = 0.25;
  static const int CALIBRATION_FRAMES = 10; // Jumlah frame untuk kalibrasi

  // --- Variabel WebSocket ---
  late WebSocketChannel _channel;
  bool _isConnected = false;

  // --- Variabel Kamera & Deteksi ---
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  late FaceDetector _faceDetector;
  bool _isProcessing = false;
  late int _selectedCameraIndex;

  // --- Variabel Kalibrasi ---
  bool _isCalibrated = false;
  bool _isCalibrating = false; // Status sedang kalibrasi
  int _calibrationFrameCount = 0;
  
  // NILAI REFERENSI KALIBRASI (posisi netral user)
  double _calibratedYaw = 0.0;
  double _calibratedNoseY = 0.0;
  
  // Untuk mengumpulkan data saat kalibrasi
  final List<double> _calibrationYawSamples = [];
  final List<double> _calibrationNoseYSamples = [];

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
  String _status = "Hubungkan WiFi ke ESP & tekan tombol kalibrasi";
  int _processingTimeMs = 0;

  void _connectToESP() {
    try {
      final wsUrl = Uri.parse('ws://192.168.4.1:81');
      _channel = WebSocketChannel.connect(wsUrl);

      _channel.ready.then((_) {
        setState(() {
          _isConnected = true;
          _status = "Terhubung ke ESP! Siap digunakan!";
        });
        
        _channel.stream.listen((message) {
          debugPrint('Pesan dari ESP: $message');
        }, onDone: () {
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
        _status = "Pastikan WiFi HP sudah terhubung ke ESP";
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
    _connectToESP(); 

    setState(() {
      _isCalibrating = true; // Mulai proses kalibrasi
      _isCalibrated = false;
      _calibrationFrameCount = 0;
      _calibrationYawSamples.clear();
      _calibrationNoseYSamples.clear();
      _status = "Kalibrasi... Tahan posisi kepala netral!";
      _rightHistory.clear();
      _leftHistory.clear();
      _upHistory.clear();
      _downHistory.clear();
    });
  }

  void _finishCalibration() {
    // Hitung rata-rata dari sample kalibrasi
    if (_calibrationYawSamples.isNotEmpty && _calibrationNoseYSamples.isNotEmpty) {
      _calibratedYaw = _calibrationYawSamples.reduce((a, b) => a + b) / _calibrationYawSamples.length;
      _calibratedNoseY = _calibrationNoseYSamples.reduce((a, b) => a + b) / _calibrationNoseYSamples.length;
      
      setState(() {
        _isCalibrating = false;
        _isCalibrated = true;
        _status = "Kalibrasi selesai! Silakan gunakan";
      });

      // Clear status setelah 2 detik
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isCalibrated) {
          setState(() {
            _status = "";
          });
        }
      });
    } else {
      setState(() {
        _isCalibrating = false;
        _status = "Kalibrasi gagal! Wajah tidak terdeteksi";
      });
    }
  }

  void _resetCalibration() {
    setState(() {
      _isCalibrated = false;
      _isCalibrating = false;
      _calibratedYaw = 0.0;
      _calibratedNoseY = 0.0;
      _calibrationYawSamples.clear();
      _calibrationNoseYSamples.clear();
      _status = "Hubungkan WiFi ke ESP & tekan tombol kalibrasi";
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

    final stopwatch = Stopwatch()..start(); 

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

      stopwatch.stop(); 
      _processingTimeMs = stopwatch.elapsedMilliseconds; 

      if (mounted && faces.isNotEmpty) {
        final Face face = faces.first;
        final FaceLandmark? nose = face.landmarks[FaceLandmarkType.noseBase];

        if (nose != null) {
          final double yawAngle = face.headEulerAngleZ ?? 0.0;
          final currentNosePos = Point(nose.position.x.toDouble(), nose.position.y.toDouble());
          final faceBox = face.boundingBox;
          final faceCenterY = faceBox.center.dy;
          final double dy = currentNosePos.y - faceCenterY;

          // === MODE KALIBRASI: Kumpulkan data ===
          if (_isCalibrating) {
            _calibrationYawSamples.add(yawAngle);
            _calibrationNoseYSamples.add(dy);
            _calibrationFrameCount++;

            setState(() {
              _status = "Kalibrasi $_calibrationFrameCount/$CALIBRATION_FRAMES...";
            });

            if (_calibrationFrameCount >= CALIBRATION_FRAMES) {
              _finishCalibration();
            }
          }
          // === MODE NORMAL: Hitung gerakan relatif terhadap kalibrasi ===
          else if (_isCalibrated) {
            final screenHeight = image.height.toDouble();

            // HITUNG PERUBAHAN RELATIF TERHADAP POSISI KALIBRASI
            final double relativeYaw = yawAngle - _calibratedYaw;
            final double relativeDy = dy - _calibratedNoseY;

            // --- PENGHITUNGAN PERSENTASE GELENG (KANAN/KIRI) ---
            final rawRightPercent = (relativeYaw > 0) 
                ? ((relativeYaw / MAX_YAW_DEGREE) * 100).clamp(0, 100).toInt() 
                : 0;
            
            final rawLeftPercent = (relativeYaw < 0) 
                ? ((relativeYaw.abs() / MAX_YAW_DEGREE) * 100).clamp(0, 100).toInt() 
                : 0;

            // --- PENGHITUNGAN PERSENTASE ANGGUK (ATAS/BAWAH) ---
            final rawUpPercent = (relativeDy < 0) 
                ? ((relativeDy.abs() / (screenHeight * VERTICAL_SCALE_FACTOR)) * 100).clamp(0, 100).toInt() 
                : 0;
                
            final rawDownPercent = (relativeDy > 0) 
                ? ((relativeDy / (screenHeight * VERTICAL_SCALE_FACTOR)) * 100).clamp(0, 100).toInt() 
                : 0;

            // --- Smoothing ---
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

            // Kirim data ke ESP jika terhubung
            if (_isConnected) {
              String dataToSend = 
                '{"kanan": $_turnRightPercent, "kiri": $_turnLeftPercent, "atas": $_nodUpPercent, "bawah": $_nodDownPercent}';
              _channel.sink.add(dataToSend);
            }

            setState(() {});
          }
        }
      } else if (mounted) {
        setState(() {
          _status = _isCalibrating 
              ? "Posisikan wajah untuk kalibrasi" 
              : (_isCalibrated ? "Wajah tidak terdeteksi" : "Posisikan wajah di dalam area");
        });
      }
    } catch (e) {
      debugPrint("Error di _processCameraImage: $e");
      stopwatch.stop();
      _processingTimeMs = stopwatch.elapsedMilliseconds; 
      setState(() {});
    }

    _isProcessing = false;
  }

  @override
  void dispose() {
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
    Color statusColor = Colors.blue.withOpacity(0.8);
    if (_isCalibrated && _isConnected) {
      statusColor = Colors.green.withOpacity(0.8);
    } else if (_isCalibrated && !_isConnected) {
      statusColor = Colors.orange.withOpacity(0.8);
    } else if (_isCalibrating) {
      statusColor = Colors.purple.withOpacity(0.8);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isConnected ? "Tersambung" : "Tidak Tersambung"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
            tooltip: 'Ganti Kamera',
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
                        color: statusColor, 
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
                    bottom: 80, 
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Frame Time: $_processingTimeMs ms",
                            style: const TextStyle(
                                color: Colors.cyanAccent, 
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Geleng Kanan: $_turnRightPercent%   Geleng Kiri: $_turnLeftPercent%",
                            style: const TextStyle(
                                color: Colors.yellow, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Angguk Atas: $_nodUpPercent%   Angguk Bawah: $_nodDownPercent%",
                            style: const TextStyle(
                                color: Colors.yellow, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevatedButton.icon( 
                      onPressed: (_isCalibrated || _isCalibrating) ? _resetCalibration : _startCalibration,
                      icon: Icon((_isCalibrated || _isCalibrating) ? Icons.refresh : Icons.sensors),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text(
                          (_isCalibrated || _isCalibrating) ? 'RESET KALIBRASI' : 'KALIBRASI & SAMBUNGKAN',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isCalibrated || _isCalibrating) ? Colors.red.shade700 : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}