# Project_ComputerVision
Sistem Computer Vision untuk mendeteksi gerakan kepala dan mengontrol LED melalui ESP32 menggunakan Google ML Kit dan WebSocket.

## Tentang Proyek
Proyek ini menggabungkan Computer Vision dan IoT untuk mendeteksi pergerakan kepala dan mentransformasi gerakan tersebut menjadi kontrol LED di ESP32 secara real-time.

**Alur utama:**
1.  Kamera menangkap gerakan kepala.
2.  Proses menggunakan Google ML Kit di Aplikasi Flutter.
3.  Data gerakan dikirim via WebSocket ke backend Python.
4.  Backend mengirim sinyal ke firmware ESP32.
5.  ESP32 menyalakan LED sesuai pergerakan.

**Tujuan proyek:**
* Belajar integrasi Computer Vision, Machine Learning, dan IoT.
* Membuat visualisasi pergerakan kepala ke output fisik (LED).
* Membangun sistem real-time yang berjalan di berbagai platform (Aplikasi, PC, dan ESP32).

---

## Fitur ✨
- Deteksi pergerakan kepala (atas, bawah, kiri, kanan) menggunakan kamera.
- Transformasi data gerakan menjadi sinyal kontrol untuk LED.
- Kontrol ESP32 secara nirkabel dan real-time menggunakan WebSocket.
- Dukungan skrip pengujian di laptop sebelum di-deploy ke perangkat fisik.
- Menggunakan Google ML Kit untuk deteksi wajah dan gerakan yang efisien.

---

## Spesifikasi Teknis 🛠️
* **Hardware**: ESP32, beberapa buah LED, dan kamera (webcam laptop atau ponsel).
* **Aplikasi Mobile**: Flutter (Dart) untuk antarmuka pengguna dan pengiriman data.
* **Backend Server**: Python dengan library `websockets`.
* **Firmware**: C++ (Arduino) untuk ESP32.
* **AI/ML Model**: Google ML Kit (Face Detection).
* **Protokol Jaringan**: WebSocket melalui jaringan Wi-Fi 2.4 GHz.

---


