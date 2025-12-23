#include <WiFi.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>

// GPIO Pin Configuration
const int PIN_NOD_UP = 2;
const int PIN_NOD_DOWN = 4;
const int PIN_TURN_RIGHT = 16;
const int PIN_TURN_LEFT = 17;

// Movement data from Flutter app
volatile int latestUp = 0;
volatile int latestDown = 0;
volatile int latestRight = 0;
volatile int latestLeft = 0;

// Serial print timing control
unsigned long lastPrintUp = 0;
unsigned long lastPrintDown = 0;
unsigned long lastPrintRight = 0;
unsigned long lastPrintLeft = 0;
const long PRINT_INTERVAL = 500;

// Detection threshold
const int THRESHOLD = 7;

// WiFi Access Point credentials
const char* ssid = "ESP32-FaceController_kelompok2";
const char* password = "password123";

WebSocketsServer webSocket = WebSocketsServer(81);

void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_TEXT) {
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, payload);

    if (error) {
      Serial.print(F("JSON parse error: "));
      Serial.println(error.f_str());
      return;
    }

    latestUp = doc["atas"] | 0;
    latestDown = doc["bawah"] | 0;
    latestRight = doc["kanan"] | 0;
    latestLeft = doc["kiri"] | 0;
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println();
  
  // Initialize GPIO pins as outputs
  pinMode(PIN_NOD_UP, OUTPUT);
  pinMode(PIN_NOD_DOWN, OUTPUT);
  pinMode(PIN_TURN_RIGHT, OUTPUT);
  pinMode(PIN_TURN_LEFT, OUTPUT);

  // Turn off all LEDs at startup
  digitalWrite(PIN_NOD_UP, LOW);
  digitalWrite(PIN_NOD_DOWN, LOW);
  digitalWrite(PIN_TURN_RIGHT, LOW);
  digitalWrite(PIN_TURN_LEFT, LOW);

  // Start WiFi Access Point
  Serial.println("Starting WiFi AP...");
  WiFi.softAP(ssid, password);
  IPAddress ip = WiFi.softAPIP();
  Serial.print("AP IP: ");
  Serial.println(ip);
  
  // Start WebSocket server
  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);
  Serial.println("WebSocket server ready");
}

void loop() {
  webSocket.loop();
  unsigned long now = millis();

  // Nod Up
  if (latestUp > THRESHOLD) {
    digitalWrite(PIN_NOD_UP, HIGH);
    if (now - lastPrintUp >= PRINT_INTERVAL) {
      Serial.print("Nod Up: ");
      Serial.println(latestUp);
      lastPrintUp = now;
    }
  } else {
    digitalWrite(PIN_NOD_UP, LOW);
  }

  // Nod Down
  if (latestDown > THRESHOLD) {
    digitalWrite(PIN_NOD_DOWN, HIGH);
    if (now - lastPrintDown >= PRINT_INTERVAL) {
      Serial.print("Nod Down: ");
      Serial.println(latestDown);
      lastPrintDown = now;
    }
  } else {
    digitalWrite(PIN_NOD_DOWN, LOW);
  }

  // Turn Right
  if (latestRight > THRESHOLD) {
    digitalWrite(PIN_TURN_RIGHT, HIGH);
    if (now - lastPrintRight >= PRINT_INTERVAL) {
      Serial.print("Turn Right: ");
      Serial.println(latestRight);
      lastPrintRight = now;
    }
  } else {
    digitalWrite(PIN_TURN_RIGHT, LOW);
  }

  // Turn Left
  if (latestLeft > THRESHOLD) {
    digitalWrite(PIN_TURN_LEFT, HIGH);
    if (now - lastPrintLeft >= PRINT_INTERVAL) {
      Serial.print("Turn Left: ");
      Serial.println(latestLeft);
      lastPrintLeft = now;
    }
  } else {
    digitalWrite(PIN_TURN_LEFT, LOW);
  }
}