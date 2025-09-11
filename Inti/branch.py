import cv2
import mediapipe as mp
import time
from collections import deque
import numpy as np

# --- KONFIGURASI ---
SMOOTHING_FRAMES = 7
DEADZONE_THRESHOLD = 5
CALIBRATION_TIME = 3

# --- KONFIGURASI WARNING ---
TURN_THRESHOLD_PERCENT = 17
NOD_THRESHOLD_PERCENT = 9
DEVIATION_DURATION_SECONDS = 2
WARNING_WINDOW_SECONDS = 60
WARNING_COUNT_THRESHOLD = 3

# --- Inisialisasi MediaPipe ---
mp_drawing = mp.solutions.drawing_utils
mp_face_mesh = mp.solutions.face_mesh
mp_face_detection = mp.solutions.face_detection

# Inisialisasi model
face_mesh = mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)
face_detector = mp_face_detection.FaceDetection(min_detection_confidence=0.7)

cap = cv2.VideoCapture(0)

# --- Variabel Status & Kalibrasi ---
is_calibrating = False
is_calibrated = False
calibration_start_time = 0
baseline_nose = (0, 0)
baseline_face_center = (0, 0)

# --- Deque untuk smoothing & history pelanggaran ---
dx_hist = deque(maxlen=SMOOTHING_FRAMES)
dy_hist = deque(maxlen=SMOOTHING_FRAMES)
event_timestamps = deque()

# --- Variabel untuk melacak durasi gerakan ---
deviation_start_time = None
violations_logged_this_deviation = 0

# --- Fungsi untuk memulai kalibrasi ---
def start_calibration():
    global is_calibrating, is_calibrated, calibration_start_time, event_timestamps, violations_logged_this_deviation
    is_calibrating, is_calibrated = True, False
    calibration_start_time = time.time()
    dx_hist.clear(); dy_hist.clear(); event_timestamps.clear()
    violations_logged_this_deviation = 0
    print("\n===== MEMULAI KALIBRASI BARU =====")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret: break

    frame = cv2.flip(frame, 1)
    h, w, _ = frame.shape
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    mesh_results = face_mesh.process(rgb_frame)
    detection_results = face_detector.process(rgb_frame)

    # Peringatan Multi-Wajah (selalu aktif)
    if detection_results.detections and len(detection_results.detections) > 1:
        cv2.putText(frame, "!!! LEBIH DARI 1 WAJAH !!!", (w // 2 - 300, h // 2 - 50),
                    cv2.FONT_HERSHEY_DUPLEX, 1.5, (0, 0, 255), 3)

    if not is_calibrated and not is_calibrating:
        cv2.putText(frame, "Tekan 'c' untuk memulai kalibrasi", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)

    if mesh_results.multi_face_landmarks:
        face_landmarks = mesh_results.multi_face_landmarks[0]
        
        # --- [PERUBAHAN] BAGIAN INI DIJADIKAN KOMENTAR UNTUK MENGHILANGKAN JARING WAJAH ---
        # mp_drawing.draw_landmarks(
        #     image=frame, landmark_list=face_landmarks,
        #     connections=mp_face_mesh.FACEMESH_TESSELATION,
        #     landmark_drawing_spec=None,
        #     connection_drawing_spec=mp_drawing.DrawingSpec(thickness=1, circle_radius=1, color=(0,255,0)))
        # ------------------------------------------------------------------------------

        nose = face_landmarks.landmark[1]
        x_n, y_n = int(nose.x * w), int(nose.y * h)
        y_coords = [int(p.y * h) for p in face_landmarks.landmark]
        y_face_center = (min(y_coords) + max(y_coords)) // 2

        if is_calibrating:
            elapsed_time = time.time() - calibration_start_time
            cv2.putText(frame, f"Tahan Posisi... {CALIBRATION_TIME - int(elapsed_time)}", (50, 100), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
            
            if elapsed_time <= CALIBRATION_TIME:
                dx_hist.append(x_n); dy_hist.append(y_face_center)
            else:
                if dx_hist and dy_hist:
                    baseline_nose = (int(np.mean(dx_hist)), 0)
                    baseline_face_center = (0, int(np.mean(dy_hist)))
                    is_calibrated = True
                    print("===== KALIBRASI BERHASIL! =====")
                is_calibrating = False
                dx_hist.clear(); dy_hist.clear()

        elif is_calibrated:
            dx_smooth = np.mean(dx_hist) if dx_hist else 0
            dy_smooth = np.mean(dy_hist) if dy_hist else 0
            final_right = max(0, int(((x_n - baseline_nose[0]) / (w * 0.4)) * 100))
            final_left = max(0, int((-(x_n - baseline_nose[0]) / (w * 0.4)) * 100))
            final_up = max(0, int((-(y_face_center - baseline_face_center[1]) / (h * 0.4)) * 100))
            final_down = max(0, int(((y_face_center - baseline_face_center[1]) / (h * 0.4)) * 100))

            is_turning = final_right > TURN_THRESHOLD_PERCENT or final_left > TURN_THRESHOLD_PERCENT
            is_nodding = final_up > NOD_THRESHOLD_PERCENT or final_down > NOD_THRESHOLD_PERCENT
            is_deviating = is_turning or is_nodding

            if is_deviating:
                if deviation_start_time is None: deviation_start_time = time.time()
                elapsed_time = time.time() - deviation_start_time
                completed_intervals = int(elapsed_time / DEVIATION_DURATION_SECONDS)
                if completed_intervals > violations_logged_this_deviation:
                    event_timestamps.append(time.time())
                    violations_logged_this_deviation = completed_intervals
                    
                    # --- LOG DI TERMINAL ---
                    direction = ""
                    if is_turning: direction = f"Menoleh ke {'KANAN' if final_right > final_left else 'KIRI'}"
                    elif is_nodding: direction = f"Menunduk ke {'ATAS' if final_up > final_down else 'BAWAH'}"
                    print(f"--> PELANGGARAN #{len(event_timestamps)} terdeteksi: {direction}")
            else:
                deviation_start_time = None; violations_logged_this_deviation = 0

            current_time = time.time()
            while event_timestamps and event_timestamps[0] < current_time - WARNING_WINDOW_SECONDS:
                event_timestamps.popleft()
            if len(event_timestamps) >= WARNING_COUNT_THRESHOLD:
                cv2.putText(frame, "!!! WARNING !!!", (w // 2 - 200, h // 2), cv2.FONT_HERSHEY_TRIPLEX, 2, (0, 0, 255), 3)

            cv2.putText(frame, f"Kanan: {final_right}% | Kiri: {final_left}%", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            cv2.putText(frame, f"Atas: {final_up}% | Bawah: {final_down}%", (50, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            cv2.putText(frame, f"Pelanggaran (1 mnt): {len(event_timestamps)}", (50, h-30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
            cv2.putText(frame, "Tekan 'c' untuk re-kalibrasi", (w - 350, h - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

    else:
        # --- PERINGATAN WAJAH HILANG ---
        if is_calibrated: # Hanya munculkan jika kalibrasi sudah selesai
            cv2.putText(frame, "!!! WAJAH HILANG !!!", (w // 2 - 250, h // 2),
                        cv2.FONT_HERSHEY_DUPLEX, 1.5, (0, 165, 255), 3)

    cv2.imshow("Sistem Pengawasan Ujian Pro", frame)

    key = cv2.waitKey(5) & 0xFF
    if key == ord('q'): break
    if key == ord('c'): start_calibration()

cap.release()
face_mesh.close()
face_detector.close()
cv2.destroyAllWindows()