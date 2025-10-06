#include <WiFi.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>

// --- Variabel Global untuk menyimpan data terakhir dari Flutter ---
volatile int latestAtas = 0;
volatile int latestBawah = 0;
volatile int latestKanan = 0;
volatile int latestKiri = 0;

// --- Variabel untuk Timer (menggunakan millis()) ---
unsigned long lastPrintTimeAtas = 0;
unsigned long lastPrintTimeBawah = 0;
unsigned long lastPrintTimeKanan = 0;
unsigned long lastPrintTimeKiri = 0;
const long printInterval = 500; // Interval 0.5 detik (500 milidetik)

const int AMBANG_BATAS = 7;

// --- PENGATURAN HOTSPOT ---
// Atur nama dan password untuk hotspot yang akan dibuat oleh ESP32
const char* ssid = "ESP32-FaceController";
const char* password = "password123";     // Password minimal 8 karakter

WebSocketsServer webSocket = WebSocketsServer(81);

void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_TEXT) {
    DynamicJsonDocument doc(1024);
    deserializeJson(doc, payload);

    // Update variabel global dengan data terbaru
    latestAtas = doc["atas"];
    latestBawah = doc["bawah"];
    latestKanan = doc["kanan"];
    latestKiri = doc["kiri"];
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("Configuring access point...");

  // Mengubah ESP32 menjadi Access Point (Hotspot)
  // HP akan terhubung ke WiFi yang dibuat oleh ESP32 ini
  WiFi.softAP(ssid, password);

  // Dapatkan alamat IP dari ESP32 (defaultnya adalah 192.168.4.1)
  IPAddress myIP = WiFi.softAPIP(); 
  Serial.print("AP IP address: ");
  Serial.println(myIP);

  // Mulai WebSocket Server
  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);
  
  Serial.println("WebSocket server started. Waiting for client...");
}

void loop() {
  // Jaga koneksi WebSocket tetap hidup
  webSocket.loop();

  // Dapatkan waktu saat ini
  unsigned long currentTime = millis();

  // Cek gerakan ATAS
  if (latestAtas > AMBANG_BATAS) {
    if (currentTime - lastPrintTimeAtas >= printInterval) {
      Serial.println("-> LED Atas NYALA");
      lastPrintTimeAtas = currentTime; 
    }
  }

  // Cek gerakan BAWAH
  if (latestBawah > AMBANG_BATAS) {
    if (currentTime - lastPrintTimeBawah >= printInterval) {
      Serial.println("-> LED Bawah NYALA");
      lastPrintTimeBawah = currentTime;
    }
  }

  // Cek gerakan KANAN
  if (latestKanan > AMBANG_BATAS) {
    if (currentTime - lastPrintTimeKanan >= printInterval) {
      Serial.println("-> LED Kanan NYALA");
      lastPrintTimeKanan = currentTime;
    }
  }

  // Cek gerakan KIRI
  if (latestKiri > AMBANG_BATAS) {
    if (currentTime - lastPrintTimeKiri >= printInterval) {
      Serial.println("-> LED Kiri NYALA");
      lastPrintTimeKiri = currentTime;
    }
  }
}