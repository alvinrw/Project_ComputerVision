import cv2
import mediapipe as mp
import time
from collections import deque
import numpy as np

# --- KONFIGURASI ---
# Untuk Smoothing: menyimpan N frame terakhir. Makin besar, makin mulus tapi ada sedikit delay.
SMOOTHING_FRAMES = 7
# Untuk Deadzone: gerakan di bawah threshold ini akan dianggap 0.
DEADZONE_THRESHOLD = 4  # artinya 4%

mp_face_mesh = mp_face_mesh = mp.solutions.face_mesh
cap = cv2.VideoCapture(0)

# --- Variabel untuk State Kalibrasi ---
kalibrasi_selesai = False
waktu_kalibrasi_selesai = 0

# --- Deque untuk menyimpan data N frame terakhir (untuk smoothing) ---
# deque adalah list spesial yang efisien untuk menambah/menghapus data dari ujung
percent_right_hist = deque(maxlen=SMOOTHING_FRAMES)
percent_left_hist = deque(maxlen=SMOOTHING_FRAMES)
percent_up_hist = deque(maxlen=SMOOTHING_FRAMES)
percent_down_hist = deque(maxlen=SMOOTHING_FRAMES)


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

        if results.multi_face_landmarks:
            face_landmarks = results.multi_face_landmarks[0]
            nose = face_landmarks.landmark[1]
            x_n, y_n = int(nose.x * w), int(nose.y * h)

            # --- JIKA KALIBRASI BELUM SELESAI ---
            if not kalibrasi_selesai:
                box_width, box_height = int(w * 0.3), int(h * 0.4)
                x1, y1 = (w - box_width) // 2, (h - box_height) // 2
                x2, y2 = x1 + box_width, y1 + box_height

                cv2.rectangle(image, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(image, "Posisikan wajah & tekan 'r' utk kalibrasi ulang", (x1 - 100, y1 - 20),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

                if x1 < x_n < x2 and y1 < y_n < y2:
                    kalibrasi_selesai = True
                    waktu_kalibrasi_selesai = time.time()

            # --- JIKA KALIBRASI SUDAH SELESAI ---
            else:
                if time.time() - waktu_kalibrasi_selesai < 2.0:
                    cv2.putText(image, "Kalibrasi Selesai! SIAP!", (50, 50),
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                else:
                    # 1. HITUNG PERSENTASE MENTAH
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

                    # 2. LAKUKAN SMOOTHING
                    percent_right_hist.append(raw_percent_right)
                    percent_left_hist.append(raw_percent_left)
                    percent_up_hist.append(raw_percent_up)
                    percent_down_hist.append(raw_percent_down)

                    smooth_percent_right = int(np.mean(percent_right_hist))
                    smooth_percent_left = int(np.mean(percent_left_hist))
                    smooth_percent_up = int(np.mean(percent_up_hist))
                    smooth_percent_down = int(np.mean(percent_down_hist))

                    # 3. TERAPKAN DEADZONE
                    final_percent_right = smooth_percent_right if smooth_percent_right > DEADZONE_THRESHOLD else 0
                    final_percent_left = smooth_percent_left if smooth_percent_left > DEADZONE_THRESHOLD else 0
                    final_percent_up = smooth_percent_up if smooth_percent_up > DEADZONE_THRESHOLD else 0
                    final_percent_down = smooth_percent_down if smooth_percent_down > DEADZONE_THRESHOLD else 0

                    # 4. TAMPILKAN HASIL FINAL
                    cv2.putText(image, f"Kanan: {final_percent_right}%  Kiri: {final_percent_left}%",
                                (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                    cv2.putText(image, f"Atas: {final_percent_up}%  Bawah: {final_percent_down}%",
                                (50, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)

        else:
            pesan = "Wajah tidak terdeteksi"
            if not kalibrasi_selesai:
                pesan = "Posisikan wajah di dalam kotak"
            cv2.putText(image, pesan, (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

        cv2.imshow("Deteksi Gerakan Kepala Pro", image)

        # --- KONTROL KEYBOARD ---
        key = cv2.waitKey(5) & 0xFF
        if key == ord('q'): # Tekan 'q' untuk keluar
            break
        if key == ord('r'): # Tekan 'r' untuk reset kalibrasi
            kalibrasi_selesai = False
            # Mengosongkan history agar smoothing tidak terpengaruh data lama
            percent_right_hist.clear()
            percent_left_hist.clear()
            percent_up_hist.clear()
            percent_down_hist.clear()


cap.release()
cv2.destroyAllWindows()