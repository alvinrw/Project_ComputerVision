import cv2
import mediapipe as mp
import numpy as np
import random
import time
from collections import deque

# --- KONFIGURASI GAME ---
# --- PERBAIKAN SENSITIVITAS ---
SMOOTHING_FRAMES = 5
DEADZONE_THRESHOLD = 5  # Turunkan dari 8 ke 5 agar lebih responsif
SENSITIVITY = 3.5       # Naikkan dari 2.0 ke 3.5 agar player bergerak lebih lincah

# --- KONFIGURASI HEAD TRACKING ---
mp_face_mesh = mp.solutions.face_mesh
cap = cv2.VideoCapture(0)

# --- VARIABEL GAME ---
class TempleRunGame:
    def __init__(self):
        self.player_x = 400  # Posisi horizontal player disesuaikan dengan resolusi layar
        self.player_y = 600  # Posisi vertikal player
        self.score = 0
        self.speed = 5
        self.game_over = False
        self.kalibrasi_selesai = False
        self.waktu_kalibrasi = 0
        
        self.obstacles = []
        self.coins = []
        
        self.percent_right_hist = deque(maxlen=SMOOTHING_FRAMES)
        self.percent_left_hist = deque(maxlen=SMOOTHING_FRAMES)
        self.percent_up_hist = deque(maxlen=SMOOTHING_FRAMES)
        self.percent_down_hist = deque(maxlen=SMOOTHING_FRAMES)
        
        self.generate_initial_objects()
        
    def generate_initial_objects(self):
        # Generate obstacles
        for i in range(5):
            y = -i * 250 - 100
            lane = random.choice([150, 400, 650]) # Disesuaikan dengan posisi lane
            self.obstacles.append([lane, y, 80, 80])

        # Generate coins
        for i in range(10):
            y = -i * 120 - 50
            lane = random.choice([150, 400, 650])
            coin_overlap = any(abs(obs[1] - y) < 100 and obs[0] == lane for obs in self.obstacles)
            if not coin_overlap:
                self.coins.append([lane, y, 30, 30])
    
    def update_objects(self, h):
        for obs in self.obstacles:
            obs[1] += self.speed
        for coin in self.coins:
            coin[1] += self.speed
            
        self.obstacles = [obs for obs in self.obstacles if obs[1] < h + 50]
        self.coins = [coin for coin in self.coins if coin[1] < h + 50]
        
        if len(self.obstacles) < 5:
            y = min([obs[1] for obs in self.obstacles] or [0]) - random.randint(200, 400)
            lane = random.choice([150, 400, 650])
            self.obstacles.append([lane, y, 80, 80])
            
        if len(self.coins) < 8:
            y = min([coin[1] for coin in self.coins] or [0]) - random.randint(150, 300)
            lane = random.choice([150, 400, 650])
            coin_overlap = any(abs(obs[1] - y) < 100 and obs[0] == lane for obs in self.obstacles)
            if not coin_overlap:
                self.coins.append([lane, y, 30, 30])
    
    def check_collisions(self):
        player_rect = (self.player_x - 30, self.player_y - 30, 60, 60)
        
        for obs in self.obstacles:
            obs_rect = (obs[0] - obs[2]//2, obs[1] - obs[3]//2, obs[2], obs[3])
            if (player_rect[0] < obs_rect[0] + obs_rect[2] and
                player_rect[0] + player_rect[2] > obs_rect[0] and
                player_rect[1] < obs_rect[1] + obs_rect[3] and
                player_rect[1] + player_rect[3] > obs_rect[1]):
                self.game_over = True
                
        for coin in self.coins[:]:
            coin_rect = (coin[0] - coin[2]//2, coin[1] - coin[3]//2, coin[2], coin[3])
            if (player_rect[0] < coin_rect[0] + coin_rect[2] and
                player_rect[0] + player_rect[2] > coin_rect[0] and
                player_rect[1] < coin_rect[1] + coin_rect[3] and
                player_rect[1] + player_rect[3] > coin_rect[1]):
                self.coins.remove(coin)
                self.score += 10
    
    def update_player_position(self, head_data, w, h):
        if head_data:
            left_move, right_move, _, _ = head_data
            
            # Gerakan horizontal, /5 untuk membuatnya lebih cepat
            if right_move > 0:
                self.player_x += SENSITIVITY * (right_move / 5)
            elif left_move > 0:
                self.player_x -= SENSITIVITY * (left_move / 5)
            
            self.player_x = max(150, min(650, self.player_x)) # Batasi posisi player di lane
            self.player_y = h - 150 # Posisi player tetap di bawah
    
    def draw_game(self, image):
        h, w, _ = image.shape
        
        # Area game utama
        game_area_x_start = 100
        game_area_width = 600
        
        cv2.rectangle(image, (game_area_x_start, 0), (game_area_x_start + game_area_width, h), (50, 50, 50), -1)
        
        for i in range(1, 3):
            x = game_area_x_start + i * (game_area_width // 3)
            cv2.line(image, (x, 0), (x, h), (255, 255, 255), 2)
        
        for obs in self.obstacles:
            cv2.rectangle(image, (int(obs[0] - obs[2]//2), int(obs[1] - obs[3]//2)), 
                          (int(obs[0] + obs[2]//2), int(obs[1] + obs[3]//2)), (0, 0, 255), -1)
        
        for coin in self.coins:
            cv2.circle(image, (int(coin[0]), int(coin[1])), 15, (0, 255, 255), -1)
        
        cv2.circle(image, (int(self.player_x), int(self.player_y)), 30, (0, 255, 0), -1)
        cv2.circle(image, (int(self.player_x), int(self.player_y)), 30, (255, 255, 255), 3)
        
        # Info Panel di kanan
        info_panel_x = game_area_x_start + game_area_width + 50
        cv2.putText(image, f"Score: {self.score}", (info_panel_x, 100), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        cv2.putText(image, f"Speed: {int(self.speed)}", (info_panel_x, 150), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        cv2.putText(image, "ESC: Keluar", (info_panel_x, h - 150), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 1)
        cv2.putText(image, "R: Reset", (info_panel_x, h - 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 1)
        
        if self.game_over:
            overlay = image.copy()
            cv2.rectangle(overlay, (w//2-200, h//2-100), (w//2+200, h//2+100), (0, 0, 0), -1)
            cv2.addWeighted(overlay, 0.8, image, 0.2, 0, image)
            cv2.putText(image, "GAME OVER!", (w//2-120, h//2-20), cv2.FONT_HERSHEY_SIMPLEX, 1.5, (0, 0, 255), 3)
            cv2.putText(image, f"Final Score: {self.score}", (w//2-100, h//2+20), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
            cv2.putText(image, "Tekan 'R' untuk main lagi", (w//2-150, h//2+60), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 0), 2)

# --- MAIN GAME LOOP ---
game = TempleRunGame()

# --- PERBAIKAN FULL SCREEN ---
WINDOW_NAME = "Temple Run - Head Tracking"
cv2.namedWindow(WINDOW_NAME, cv2.WND_PROP_FULLSCREEN)
cv2.setWindowProperty(WINDOW_NAME, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

with mp_face_mesh.FaceMesh(
    max_num_faces=1, refine_landmarks=True, min_detection_confidence=0.5, min_tracking_confidence=0.5
) as face_mesh:
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break

        frame = cv2.flip(frame, 1)
        h, w, _ = frame.shape
        
        # Buat background hitam untuk keseluruhan jendela
        image = np.zeros((h, w, 3), dtype=np.uint8)
        
        results = face_mesh.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        
        head_data = None
        if results.multi_face_landmarks:
            face_landmarks = results.multi_face_landmarks[0]
            nose = face_landmarks.landmark[1]
            x_n, y_n = int(nose.x * w), int(nose.y * h)

            if not game.kalibrasi_selesai:
                box_w, box_h = int(w * 0.2), int(h * 0.3)
                x1, y1 = (w - box_w) // 2, (h - box_h) // 2
                cv2.rectangle(image, (x1, y1), (x1+box_w, y1+box_h), (0, 255, 0), 3)
                cv2.putText(image, "Posisikan wajah di kotak", (x1 - 50, y1 - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                if x1 < x_n < x1+box_w and y1 < y_n < y1+box_h:
                    game.kalibrasi_selesai = True
                    game.waktu_kalibrasi = time.time()
            else:
                if time.time() - game.waktu_kalibrasi < 1.5:
                    cv2.putText(image, "GET READY!", (w//2 - 150, h//2), cv2.FONT_HERSHEY_SIMPLEX, 2, (0, 255, 0), 3)
                else:
                    left_eye = face_landmarks.landmark[33]
                    right_eye = face_landmarks.landmark[263]
                    x_le, x_re = int(left_eye.x * w), int(right_eye.x * w)
                    x_eye_center = (x_le + x_re) // 2
                    
                    # --- PERBAIKAN SENSITIVITAS --- (divisor lebih kecil)
                    dx = x_n - x_eye_center
                    raw_percent_right = max(0, min(100, int((dx / (w*0.12)) * 100)))
                    raw_percent_left = max(0, min(100, int((-dx / (w*0.12)) * 100)))

                    game.percent_right_hist.append(raw_percent_right)
                    game.percent_left_hist.append(raw_percent_left)
                    
                    smooth_percent_right = int(np.mean(game.percent_right_hist))
                    smooth_percent_left = int(np.mean(game.percent_left_hist))
                    
                    final_right = smooth_percent_right if smooth_percent_right > DEADZONE_THRESHOLD else 0
                    final_left = smooth_percent_left if smooth_percent_left > DEADZONE_THRESHOLD else 0
                    
                    head_data = (final_left, final_right, 0, 0) # Up/down tidak dipakai di game ini
                    
                    if not game.game_over:
                        game.update_player_position(head_data, w, h)
                        game.update_objects(h)
                        game.check_collisions()
                        
                        if game.score > 0 and game.score % 50 == 0:
                            game.speed = min(game.speed + 0.05, 15)

        game.draw_game(image)
        cv2.imshow(WINDOW_NAME, image)

        key = cv2.waitKey(5) & 0xFF
        if key == 27: break
        elif key == ord('r'):
            if game.game_over:
                game = TempleRunGame()
            game.kalibrasi_selesai = False

cap.release()
cv2.destroyAllWindows()