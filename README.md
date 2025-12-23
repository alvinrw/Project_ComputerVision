# Head Gesture Controlled LED System

A real-time computer vision system that detects head movements using a smartphone camera and controls LEDs via ESP32 over WebSocket. Built with Flutter for the mobile app and Arduino for the ESP32 firmware.

## Overview

This project combines computer vision and IoT to create a hands-free LED control system. The Flutter app detects head gestures (nod up/down, turn left/right) using Google ML Kit's face detection, sends commands via WebSocket to an ESP32, which then controls corresponding LEDs.

**System Flow:**
1. **Flutter App** → Captures video and detects head movements using ML Kit
2. **WebSocket** → Transmits gesture data to ESP32 in real-time
3. **ESP32** → Receives commands and controls LEDs based on detected gestures

## Features

- **Real-time Detection**: Low-latency head gesture recognition
- **Calibration System**: Adapts to different users and positions
- **Wireless Control**: WiFi-based communication between components
- **Smooth Processing**: Built-in smoothing and deadzone filtering
- **Visual Feedback**: On-screen display of detection confidence and connection status

## Hardware Requirements

### Components
- **ESP32 Development Board** (1x)
- **LEDs** (4x - different colors recommended)
- **Resistors** (4x 220Ω or 330Ω)
- **Breadboard** (1x)
- **Jumper Wires**
- **Smartphone** with camera (Android/iOS)

### Wiring Diagram

| LED Function | ESP32 GPIO Pin | LED Color (Suggested) |
|-------------|----------------|----------------------|
| Nod Up      | GPIO 2         | Blue                 |
| Nod Down    | GPIO 4         | Green                |
| Turn Right  | GPIO 16        | Yellow               |
| Turn Left   | GPIO 17        | Red                  |

**Connection:**
```
ESP32 GPIO → Resistor (220Ω) → LED Anode (+) → LED Cathode (-) → GND
```

## Software Requirements

### Flutter App
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Android Studio / VS Code
- Physical device (camera required)

### ESP32 Firmware
- Arduino IDE (1.8.19+) or PlatformIO
- ESP32 Board Support Package

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/alvinrw/Project_ComputerVision.git
cd Project_ComputerVision
```

### 2. ESP32 Setup

#### Install Required Libraries
Open Arduino IDE and install these libraries via Library Manager:
- `WebSocketsServer` by Markus Sattler
- `ArduinoJson` by Benoit Blanchon

#### Upload Firmware
1. Open `App/ESP/compis/compis.ino` in Arduino IDE
2. Select your ESP32 board: **Tools → Board → ESP32 Dev Module**
3. Select the correct COM port: **Tools → Port**
4. Click **Upload**
5. Open Serial Monitor (115200 baud) to verify
6. Note the AP IP address (usually `192.168.4.1`)

#### Configure WiFi (Optional)
Edit these lines in `compis.ino` if needed:
```cpp
const char* ssid = "ESP32-FaceController_kelompok2";
const char* password = "password123";
```

### 3. Flutter App Setup

#### Install Dependencies
```bash
cd App/comvis_app
flutter pub get
```

#### Configure Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access required for head gesture detection</string>
```

#### Build and Run
```bash
# For Android
flutter run

# For iOS (requires macOS)
flutter run -d ios
```

## Usage Guide

### Step 1: Power Up ESP32
1. Connect ESP32 to power (USB or external)
2. Wait for WiFi AP to start (LED on board may blink)
3. Check Serial Monitor for confirmation

### Step 2: Connect to ESP32 WiFi
1. On your smartphone, go to WiFi settings
2. Connect to network: `ESP32-FaceController_kelompok2`
3. Password: `password123`
4. **Note**: You won't have internet while connected to ESP32

### Step 3: Launch App
1. Open the Comvis Project app
2. Tap "Masuk" (Enter) on welcome screen
3. Tap "Mulai Kamera" (Start Camera)
4. Grant camera permissions if prompted

### Step 4: Calibrate
1. Position your face in the camera view
2. Tap "KALIBRASI & SAMBUNGKAN" button
3. Hold your head in a neutral position
4. Wait for calibration to complete (10 frames)
5. Status will show "Terhubung ke ESP!" when ready

### Step 5: Control LEDs
Move your head to control LEDs:
- **Nod Up** → Blue LED lights up
- **Nod Down** → Green LED lights up
- **Turn Right** → Yellow LED lights up
- **Turn Left** → Red LED lights up

**Tips:**
- Make deliberate movements for best detection
- Recalibrate if detection becomes inaccurate
- Ensure good lighting for face detection

## Project Structure

```
Projek_comvis/
├── App/
│   ├── ESP/
│   │   └── compis/
│   │       └── compis.ino          # ESP32 firmware
│   └── comvis_app/                 # Flutter application
│       ├── lib/
│       │   ├── main.dart           # App entry point
│       │   ├── front.dart          # Welcome screen
│       │   └── camera_screen.dart  # Main detection screen
│       ├── android/                # Android config
│       ├── ios/                    # iOS config
│       └── pubspec.yaml            # Dependencies
└── README.md                       # This file
```

## Configuration

### Detection Parameters

Edit `camera_screen.dart` to adjust sensitivity:

```dart
// Smoothing (higher = smoother but slower response)
static const int SMOOTHING_FRAMES = 7;

// Deadzone (higher = less sensitive)
static const int DEADZONE_THRESHOLD = 4;

// Maximum rotation angle for left/right
static const double MAX_YAW_DEGREE = 35.0;

// Vertical sensitivity (lower = more sensitive)
static const double VERTICAL_SCALE_FACTOR = 0.25;

// Calibration samples
static const int CALIBRATION_FRAMES = 10;
```

### ESP32 Parameters

Edit `compis.ino` to adjust:

```cpp
// Detection threshold (lower = more sensitive)
const int THRESHOLD = 7;

// Serial print interval (milliseconds)
const long PRINT_INTERVAL = 500;

// WebSocket port
WebSocketsServer webSocket = WebSocketsServer(81);
```

## Troubleshooting

### ESP32 Issues

**Problem**: ESP32 not creating WiFi AP
- **Solution**: Check power supply, try pressing reset button, verify code upload

**Problem**: Can't connect to ESP32 WiFi
- **Solution**: Ensure ESP32 is powered, check SSID/password, restart ESP32

**Problem**: LEDs not responding
- **Solution**: Verify wiring, check GPIO pin numbers in code, test LEDs individually

### Flutter App Issues

**Problem**: Camera not working
- **Solution**: Grant camera permissions, restart app, check device compatibility

**Problem**: "Tidak Tersambung" (Not Connected)
- **Solution**: Verify phone is connected to ESP32 WiFi, check IP address (should be 192.168.4.1)

**Problem**: Detection not accurate
- **Solution**: Recalibrate, ensure good lighting, adjust sensitivity parameters

**Problem**: App crashes on startup
- **Solution**: Rebuild app (`flutter clean && flutter pub get && flutter run`)

### General Issues

**Problem**: High latency
- **Solution**: Reduce `SMOOTHING_FRAMES`, ensure strong WiFi signal, close other apps

**Problem**: False detections
- **Solution**: Increase `DEADZONE_THRESHOLD`, recalibrate, improve lighting

## Testing

### Test ESP32 Independently
```cpp
// Add to loop() for testing
digitalWrite(PIN_NOD_UP, HIGH);
delay(1000);
digitalWrite(PIN_NOD_UP, LOW);
```

### Test WebSocket Connection
Use a WebSocket client tool to send test data:
```json
{"atas": 10, "bawah": 0, "kanan": 0, "kiri": 0}
```

## Technical Details

### Face Detection
- **Library**: Google ML Kit Face Detection
- **Mode**: Fast performance mode
- **Features**: Landmarks enabled (nose position tracking)
- **Processing**: Asynchronous image stream processing

### Gesture Calculation
1. Detect face and nose position using ML Kit
2. Calculate head rotation (yaw angle) and vertical position
3. Compare with calibrated neutral position
4. Apply smoothing filter to reduce jitter
5. Apply deadzone threshold to prevent false triggers
6. Convert to percentage (0-100%)
7. Send via WebSocket if above threshold

### Communication Protocol
- **Protocol**: WebSocket (RFC 6455)
- **Format**: JSON
- **Payload**: `{"atas": int, "bawah": int, "kanan": int, "kiri": int}`
- **Values**: 0-100 (percentage of maximum movement)

## License

This project is created for educational purposes as part of a Computer Vision course project at Universitas Brawijaya, Faculty of Computer Science.

## Contributors

**Kelompok 2** - Computer Vision Project
- Universitas Brawijaya
- Fakultas Ilmu Komputer (FILKOM)

## Acknowledgments

- Google ML Kit for face detection capabilities
- ESP32 community for WebSocket libraries
- Flutter team for excellent mobile framework

## Support

For issues and questions:
1. Check the Troubleshooting section above
2. Review code comments in source files
3. Test components individually
4. Verify all connections and configurations

---

**Note**: This is an educational project. For production use, consider adding error handling, security features, and optimizations.
