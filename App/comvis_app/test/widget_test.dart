import 'package:flutter_test/flutter_test.dart';
import 'package:comvis_app/main.dart';
import 'package:camera/camera.dart';

void main() {
  testWidgets('App starts without crashing and shows HomeScreen', (WidgetTester tester) async {
    // [PERBAIKAN] 
    // Sediakan daftar kamera palsu (kosong) untuk kebutuhan tes,
    // karena MyApp() sekarang wajib menerima data ini.
    final List<CameraDescription> cameras = [];

    // Bangun aplikasi dengan memberikan argumen 'cameras' yang dibutuhkan.
    await tester.pumpWidget(MyApp(cameras: cameras));

    // Verifikasi bahwa halaman pembukamu (HomeScreen) berhasil muncul.
    // Kita tidak lagi mencari angka '0' atau '1'.
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}