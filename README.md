# Project Computer Vision: Kontrol LED dengan Gerakan Kepala

Sistem Computer Vision untuk mendeteksi gerakan kepala secara real-time dan menggunakannya untuk mengontrol lampu LED melalui ESP32, dihubungkan dengan WebSocket.

---

## 🎯 Tentang Proyek
Proyek ini menggabungkan Computer Vision dan IoT untuk menciptakan interaksi fisik dari gerakan digital. Aplikasi Flutter mendeteksi gerakan kepala menggunakan Google ML Kit, mengirim data ke server Python, yang kemudian memerintahkan ESP32 untuk menyalakan LED yang sesuai.

**Alur utama:**
1.  **Aplikasi Flutter**: Menggunakan kamera untuk menangkap video dan mendeteksi gerakan kepala (atas, bawah, kiri, kanan) dengan Google ML Kit.
2.  **WebSocket Client**: Aplikasi mengirimkan sinyal gerakan (`"UP"`, `"DOWN"`, dll.) ke server melalui WebSocket.
3.  **Server Python**: Berperan sebagai jembatan, menerima sinyal dari aplikasi dan meneruskannya ke ESP32.
4.  **ESP32**: Menerima perintah dari server dan menyalakan LED yang telah diprogram sesuai arah gerakan.

---

## ✨ Fitur
-   **Deteksi Real-Time**: Mendeteksi gerakan kepala dengan latensi rendah.
-   **Kontrol Nirkabel**: Menggunakan Wi-Fi untuk komunikasi antara semua komponen.
-   **Multi-Platform**: Aplikasi berjalan di Android/iOS, server di PC, dan firmware di mikrokontroler.
-   **Visualisasi Fisik**: Memberikan output nyata (cahaya LED) dari input digital (gerakan kepala).
-   **Efisien**: Memanfaatkan Google ML Kit yang dioptimalkan untuk perangkat mobile.

---

## 🛠️ Spesifikasi Teknis
* **Hardware**: ESP32, LED, Resistor, Project Board, dan Kamera (Ponsel/Webcam).
* **Aplikasi Mobile**: Flutter (Dart).
* **Backend Server**: Python.
* **Firmware**: C++ (Arduino Framework).
* **AI/ML Model**: Google ML Kit (Face Detection).
* **Protokol Komunikasi**: WebSocket.

---

## 🚀 Persiapan dan Instalasi

### 1. Clone Repository
```bash
git clone [https://github.com/alvinrw/Project_ComputerVision.git](https://github.com/alvinrw/Project_ComputerVision.git)
cd Project_ComputerVision
```

2. Instalasi Dependensi
A. Python
```bash
pip install -r requirements.txt
```

B. Flutter
```bash
flutter pub get
```

