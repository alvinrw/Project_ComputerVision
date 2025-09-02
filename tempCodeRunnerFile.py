import cv2
import mediapipe as mp
import time
from collections import deque
import numpy as np
import subprocess
import sys

# --- KONFIGURASI ---
SMOOTHING_FRAMES = 7
DEADZONE_THRESHOLD = 4

mp_face_mesh = mp.solutions.face_mesh
cap = cv2.VideoCapture(0)

# --- Variabel untuk State ---
kalibrasi_selesai = False
waktu_kalibrasi_selesai = 0
mode = "menu"  # "menu" atau "tracking"

# --- Deque untuk smoothing ---
percent_right_hist = deque(maxlen=SMOOTHING_FRAMES)
percent_left_hist = deque(maxlen=SMOOTHING_FRAMES)
percent_up_hist = deque(maxlen=SMOOTHING_FRAMES)
percent_down_hist = deque(maxlen=SMOOTHING_FRAMES)

def draw_menu(image):
    h, w = image.shape[:2]
    
    # Background menu
    overlay = image.copy()
    cv2.rectangle(overlay, (50, 50), (w-50, h-50), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.7, image, 0.3, 0, image)
    
    # Title
    cv2.putText(image, "HEAD TRACKING SYSTEM", (w//2 - 250, 120), 
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 255), 3)
    
    # Menu options
    cv2.putText(image, "1. Tekan 'T' - Test Head Tracking", (w//2 - 200, 220), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    cv2.putText(image, "2. Tekan 'G' - Play Temple Run Game", (w//2 - 200, 270), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    cv2.putText(image, "3. Tekan 'Q' - Quit", (w//2 - 200, 320), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    
    # Instructions
    cv2.putText(image, "Tekan 'M' untuk kembali ke menu dari mode test", (w//2 - 220, h-100), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (150, 150, 150), 2)

def start_game():
    """Menjalankan game Temple Run dalam proses terpisah"""
    try:
        # --- PERBAIKAN --- Pastikan 'temple_run_game.py' ada di folder yang sama
        subprocess.Popen([sys.executable, "temple_run_game.py"])
        print("Game Temple Run dimulai! Jendela game akan muncul terpisah.")
    except FileNotFoundError:
        print("ERROR: File 'temple_run_game.py' tidak ditemukan!")
        print("Pastikan file tersebut ada di folder yang sama dengan file ini.")
        
# --- PERBAIKAN FULL SCREEN ---
WINDOW_NAME = "Head Tracking System"
cv2.namedWindow(WINDOW_NAME, cv2.WND_PROP_FULLSCREEN)
cv2.setWindowProperty(WINDOW_NAME, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

with mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
) as face_mesh:

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1)
        image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(image)
        image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
        h, w, _ = image.shape

        if mode == "menu":
            draw_menu(image)
            
        elif mode == "tracking":
            if results.multi_face_landmarks:
                face_landmarks = results.multi_face_landmarks[0]
                nose = face_landmarks.landmark[1]
                x_n, y_n = int(nose.x * w), int(nose.y * h)

                # --- KALIBRASI ---
                if not kalibrasi_selesai:
                    box_width, box_height = int(w * 0.3), int(h * 0.4)
                    x1, y1 = (w - box_width) // 2, (h - box_height) // 2
                    x2, y2 = x1 + box_width, y1 + box_height

                    cv2.rectangle(image, (x1, y1), (x2, y2), (0, 255, 0), 2)
                    cv2.putText(image, "Posisikan wajah & tunggu...", (x1 - 100, y1 - 20),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

                    if x1 < x_n < x2 and y1 < y_n < y2:
                        kalibrasi_selesai = True
                        waktu_kalibrasi_selesai = time.time()

                # --- TRACKING ---
                else:
                    if time.time() - waktu_kalibrasi_selesai < 2.0:
                        cv2.putText(image, "Kalibrasi Selesai! SIAP!", (w//2-200, h//2),
                                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 3)
                    else:
                        left_eye = face_landmarks.landmark[33]
                        right_eye = face_landmarks.landmark[263]
                        x_le, y_le = int(left_eye.x * w), int(left_eye.y * h)
                        x_re, y_re = int(right_eye.x * w), int(right_eye.y * h)
                        y_coords = [int(p.y * h) for p in face_landmarks.landmark]
                        y_min, y_max = min(y_coords), max(y_coords)

                        x_eye_center = (x_le + x_re) // 2
                        dx = x_n - x_eye_center
                        raw_percent_right = max(0, min(100, int((dx / (w*0.25)) * 100)))
                        raw_percent_left = max(0, min(100, int((-dx / (w*0.25)) * 100)))

                        y_face_center = (y_min + y_max) // 2
                        dy = y_n - y_face_center
                        raw_percent_up = max(0, min(100, int((-dy / (h*0.25)) * 100)))
                        raw_percent_down = max(0, min(100, int((dy / (h*0.25)) * 100)))

                        percent_right_hist.append(raw_percent_right)
                        percent_left_hist.append(raw_percent_left)
                        percent_up_hist.append(raw_percent_up)
                        percent_down_hist.append(raw_percent_down)

                        smooth_percent_right = int(np.mean(percent_right_hist))
                        smooth_percent_left = int(np.mean(percent_left_hist))
                        smooth_percent_up = int(np.mean(percent_up_hist))
                        smooth_percent_down = int(np.mean(percent_down_hist))

                        final_percent_right = smooth_percent_right if smooth_percent_right > DEADZONE_THRESHOLD else 0
                        final_percent_left = smooth_percent_left if smooth_percent_left > DEADZONE_THRESHOLD else 0
                        final_percent_up = smooth_percent_up if smooth_percent_up > DEADZONE_THRESHOLD else 0
                        final_percent_down = smooth_percent_down if smooth_percent_down > DEADZONE_THRESHOLD else 0

                        cv2.putText(image, f"Kanan: {final_percent_right}%  Kiri: {final_percent_left}%",
                                    (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                        cv2.putText(image, f"Atas: {final_percent_up}%  Bawah: {final_percent_down}%",
                                    (50, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)

            else:
                pesan = "Wajah tidak terdeteksi"
                if not kalibrasi_selesai:
                    pesan = "Posisikan wajah di dalam kotak"
                cv2.putText(image, pesan, (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

        cv2.imshow(WINDOW_NAME, image)

        key = cv2.waitKey(5) & 0xFF
        if key == ord('q'):
            break
        elif key == ord('m'):
            mode = "menu"
            kalibrasi_selesai = False
            percent_right_hist.clear(); percent_left_hist.clear(); percent_up_hist.clear(); percent_down_hist.clear()
        elif key == ord('t') and mode == "menu":
            mode = "tracking"
            kalibrasi_selesai = False
        elif key == ord('g') and mode == "menu":
            start_game()
        elif key == ord('r') and mode == "tracking":
            kalibrasi_selesai = False
            percent_right_hist.clear(); percent_left_hist.clear(); percent_up_hist.clear(); percent_down_hist.clear()

cap.release()
cv2.destroyAllWindows()