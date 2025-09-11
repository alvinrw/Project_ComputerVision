import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // [PERUBAHAN 1A] Tambahkan import ini
import 'camera_screen.dart';      // [PERUBAHAN 1B] Dan import ini

class ProjectExplanationScreen extends StatefulWidget {
  // [PERUBAHAN 2] Buat widget ini bisa menerima daftar kamera
  final List<CameraDescription> cameras;
  const ProjectExplanationScreen({super.key, required this.cameras});

  @override
  State<ProjectExplanationScreen> createState() =>
      _ProjectExplanationScreenState();
}

class _ProjectExplanationScreenState extends State<ProjectExplanationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.bounceOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGold = Color(0xFFFFD700);
    const Color darkText = Color(0xFF2C2C2C);
    const Color lightGold = Color(0xFFFFF8DC);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: primaryGold.withOpacity(0.3),
        // Menghapus tombol back karena ini halaman awal setelah main.dart
        // leading: IconButton(
        //   onPressed: () => Navigator.pop(context),
        //   icon: Icon(Icons.arrow_back, color: darkText),
        // ),
        title: Text(
          'Comvis Project',
          style: TextStyle(
            color: darkText,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Row(
            children: [
              Image.asset(
                'assets/main/Ub.png',
                height: 35,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.school, color: primaryGold, size: 35),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/main/lgfilkom.png',
                height: 35,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.computer, color: primaryGold, size: 35),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              lightGold.withOpacity(0.2),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primaryGold.withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryGold.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 80,
                    color: primaryGold,
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  'Deteksi Gerakan Kepala',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                

                const SizedBox(height: 60),

                // Main Button
                ScaleTransition(
                  scale: _buttonScale,
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGold.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGold,
                        foregroundColor: darkText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.videocam, size: 28),
                      // [PERUBAHAN 3] Ganti aksi onPressed
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Kirim data kamera ke CameraScreen
                            builder: (context) => CameraScreen(cameras: widget.cameras),
                          ),
                        );
                      },
                      label: const Text(
                        'Mulai Kamera',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}