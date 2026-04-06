import cv2
import json
import os
import numpy as np
from ultralytics import YOLO
import cvzone
import datetime

# -------------------- INIT --------------------
model = YOLO('best.pt')
names = model.names

cap = cv2.VideoCapture("vid1.mp4")
frame_count = 0

# ✅ Ensure output folder exists
os.makedirs("output", exist_ok=True)

# ✅ Generate unique filename
timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
output_path = f"output/output_{timestamp}.mp4"

# ✅ Use MP4 codec (more stable)
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, 20.0, (1020, 500))

if not out.isOpened():
    print("❌ VideoWriter failed to open")
else:
    print(f"✅ Saving video to: {output_path}")

# -------------------- POLYGON SETUP --------------------
polygon_points = []
polygons = []
polygon_file = "polygons.json"

# Load saved polygons
if os.path.exists(polygon_file):
    try:
        with open(polygon_file, 'r') as f:
            polygons = json.load(f)
    except:
        polygons = []

def save_polygons():
    with open(polygon_file, 'w') as f:
        json.dump(polygons, f)

# Mouse click to draw polygon
def RGB(event, x, y, flags, param):
    global polygon_points, polygons
    if event == cv2.EVENT_LBUTTONDOWN:
        polygon_points.append((x, y))

        if len(polygon_points) == 4:
            polygons.append(polygon_points.copy())
            save_polygons()
            polygon_points.clear()

cv2.namedWindow("RGB")
cv2.setMouseCallback("RGB", RGB)

# -------------------- PROCESS LOOP --------------------
results = None

while True:
    ret, frame = cap.read()
    if not ret:
        print("✅ Video processing finished")
        break

    frame_count += 1
    frame = cv2.resize(frame, (1020, 500))

    # Run YOLO every 3rd frame
    if frame_count % 3 == 0:
        results = model.track(frame, persist=True)

    # Draw polygons
    for poly in polygons:
        pts = np.array(poly, np.int32).reshape((-1, 1, 2))
        cv2.polylines(frame, [pts], True, (0, 255, 0), 2)

    occupied_zones = 0

    # Detection logic
    if results is not None and results[0].boxes is not None:
        boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)

        for box in boxes:
            x1, y1, x2, y2 = box
            cx = int((x1 + x2) / 2)
            cy = int((y1 + y2) / 2)

            for poly in polygons:
                pts = np.array(poly, np.int32).reshape((-1, 1, 2))

                if cv2.pointPolygonTest(pts, (cx, cy), False) >= 0:
                    cv2.circle(frame, (cx, cy), 4, (255, 0, 255), -1)
                    cv2.polylines(frame, [pts], True, (0, 0, 255), 2)
                    occupied_zones += 1
                    break

    total_zones = len(polygons)
    free_zones = total_zones - occupied_zones

    cvzone.putTextRect(frame, f'FREE: {free_zones}', (30, 40), 2, 2)
    cvzone.putTextRect(frame, f'OCC: {occupied_zones}', (30, 120), 2, 2)

    # Draw current polygon points
    for pt in polygon_points:
        cv2.circle(frame, pt, 5, (0, 0, 255), -1)

    cv2.imshow("RGB", frame)

    # ✅ SAVE FRAME
    out.write(frame)

    key = cv2.waitKey(1) & 0xFF

    if key == 27:  # ESC
        print("🛑 Stopped by user")
        break

    elif key == ord('r') and polygons:
        polygons.pop()
        save_polygons()
        print("↩️ Last polygon removed")

# -------------------- CLEANUP --------------------
cap.release()
out.release()
cv2.destroyAllWindows()

print(f"🎉 Video saved successfully at: {output_path}")