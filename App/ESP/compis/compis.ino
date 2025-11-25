#include <WiFi.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>

// ==========================================================
// ===             PENETAPAN PIN GPIO UNTUK LED/AKTUATOR             ===
// ==========================================================
// Ubah angka pin (contoh: 2, 4, 16, 17) sesuai dengan rangkaian fisik Anda.
const int PIN_ANGGUK_ATAS = 2; // Contoh: GPIO 2
const int PIN_ANGGUK_BAWAH = 4; // Contoh: GPIO 4
const int PIN_GELENG_KANAN = 16; // Contoh: GPIO 16
const int PIN_GELENG_KIRI = 17; // Contoh: GPIO 17

// --- Variabel Global untuk menyimpan data terakhir dari Flutter ---
volatile int latestAtas = 0; // Angguk Atas
volatile int latestBawah = 0; // Angguk Bawah
volatile int latestKanan = 0; // Geleng Kanan
volatile int latestKiri = 0; // Geleng Kiri

// --- Variabel untuk Timer (menggunakan millis()) ---
unsigned long lastPrintTimeAtas = 0;
unsigned long lastPrintTimeBawah = 0;
unsigned long lastPrintTimeKanan = 0;
unsigned long lastPrintTimeKiri = 0;
const long printInterval = 500; // Interval 0.5 detik (500 milidetik)

// --- AMBANG BATAS DETEKSI ---
const int AMBANG_BATAS = 7;

// --- PENGATURAN HOTSPOT ---
const char* ssid = "ESP32-FaceController_kelompok2";
const char* password = "password123";

WebSocketsServer webSocket = WebSocketsServer(81);

void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_TEXT) {
    DynamicJsonDocument doc(1024); 
    DeserializationError error = deserializeJson(doc, payload);

    if (error) {
      Serial.print(F("deserializeJson() failed: "));
      Serial.println(error.f_str());
      return;
    }

    latestAtas = doc["atas"] | 0; 
    latestBawah = doc["bawah"] | 0; 
    latestKanan = doc["kanan"] | 0; 
    latestKiri = doc["kiri"] | 0; 
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println();
  
  // ==========================================================
  // ===             INISIALISASI PIN SEBAGAI OUTPUT             ===
  // ==========================================================
  pinMode(PIN_ANGGUK_ATAS, OUTPUT);
  pinMode(PIN_ANGGUK_BAWAH, OUTPUT);
  pinMode(PIN_GELENG_KANAN, OUTPUT);
  pinMode(PIN_GELENG_KIRI, OUTPUT);

  // Pastikan semua LED/aktuator mati saat startup
  digitalWrite(PIN_ANGGUK_ATAS, LOW);
  digitalWrite(PIN_ANGGUK_BAWAH, LOW);
  digitalWrite(PIN_GELENG_KANAN, LOW);
  digitalWrite(PIN_GELENG_KIRI, LOW);

  // Inisialisasi WiFi dan WebSocket Server
  Serial.println("Configuring access point...");
  WiFi.softAP(ssid, password);
  IPAddress myIP = WiFi.softAPIP(); 
  Serial.print("AP IP address: ");
  Serial.println(myIP);
  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);
  Serial.println("WebSocket server started. Waiting for Flutter client...");
}

void loop() {
  webSocket.loop();
  unsigned long currentTime = millis();

  // --- LOGIKA KONTROL/AKSI ---

  // 1. Angguk Atas
  if (latestAtas > AMBANG_BATAS) {
    digitalWrite(PIN_ANGGUK_ATAS, HIGH); // NYALAKAN LED/Aktuator
    if (currentTime - lastPrintTimeAtas >= printInterval) {
      Serial.print("✅ ANGGUK ATAS: "); Serial.println(latestAtas); 
      lastPrintTimeAtas = currentTime; 
    }
  } else {
    digitalWrite(PIN_ANGGUK_ATAS, LOW); // MATIKAN jika di bawah ambang batas
  }

  // 2. Angguk Bawah
  if (latestBawah > AMBANG_BATAS) {
    digitalWrite(PIN_ANGGUK_BAWAH, HIGH); // NYALAKAN LED/Aktuator
    if (currentTime - lastPrintTimeBawah >= printInterval) {
      Serial.print("✅ ANGGUK BAWAH: "); Serial.println(latestBawah);
      lastPrintTimeBawah = currentTime;
    }
  } else {
    digitalWrite(PIN_ANGGUK_BAWAH, LOW); // MATIKAN
  }

  // 3. Geleng Kanan
  if (latestKanan > AMBANG_BATAS) {
    digitalWrite(PIN_GELENG_KANAN, HIGH); // NYALAKAN LED/Aktuator
    if (currentTime - lastPrintTimeKanan >= printInterval) {
      Serial.print("➡️ GELENG KANAN: "); Serial.println(latestKanan); 
      lastPrintTimeKanan = currentTime;
    }
  } else {
    digitalWrite(PIN_GELENG_KANAN, LOW); // MATIKAN
  }

  // 4. Geleng Kiri
  if (latestKiri > AMBANG_BATAS) {
    digitalWrite(PIN_GELENG_KIRI, HIGH); // NYALAKAN LED/Aktuator
    if (currentTime - lastPrintTimeKiri >= printInterval) {
      Serial.print("⬅️ GELENG KIRI: "); Serial.println(latestKiri); 
      lastPrintTimeKiri = currentTime;
    }
  } else {
    digitalWrite(PIN_GELENG_KIRI, LOW); // MATIKAN
  }
}