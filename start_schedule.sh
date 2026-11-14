#!/bin/bash
export TZ="Asia/Ho_Chi_Minh"
APP_PORT="${PORT:-3000}"

# Gán username TikTok cho game câu cá
export TIKTOK_USERNAME="${TIKTOK_USER:-$TIKTOK_USERNAME}"
export PORT="$APP_PORT"

echo "=== BOT LIVESTREAM TIKTOK 24/7 (CÂU CÁ TIKTOK LIVE) ĐÃ KHỞI ĐỘNG ==="

# 0. Bật PulseAudio để bắt âm thanh tiếng cá đớp mồi, giật cá, nhạc nền
pulseaudio -D --exit-idle-time=-1 || true

# 1. Khởi động Server Game Câu Cá
echo "[1/4] Khởi động Server Game trên cổng $APP_PORT với kênh @$TIKTOK_USERNAME..."
node server/index.js &
sleep 8

# 2. Tạo màn hình ảo Full HD 1080x1920 chuẩn dọc TikTok
echo "[2/4] Khởi tạo màn hình ảo Xvfb Full HD..."
Xvfb :99 -screen 0 1080x1920x24 &
export DISPLAY=:99
sleep 3

# 3. Mở giao diện Hồ Câu trên Chromium Full HD (chế độ OBS sạch)
echo "[3/4] Mở giao diện Hồ Câu Cá Full HD..."
chromium --no-sandbox \
         --kiosk \
         --window-size=1080,1920 \
         --disable-infobars \
         --disable-features=Translate \
         --autoplay-policy=no-user-gesture-required \
         "http://localhost:${APP_PORT}/?transparent=1&mock=0" &
sleep 8

# VÒNG LẶP TREO LIVE 24/7 (FULL HD 1080P + ÂM THANH TIẾNG GIẬT CÁ & DU THUYỀN VIP)
echo "=== BẮT ĐẦU PHÁT LUỒNG CÂU CÁ 1080P LÊN TIKTOK ==="
while true; do
    echo "[$(date)] FFmpeg đang đẩy luồng Câu Cá lên TikTok RTMP..."
    
    ffmpeg -f x11grab -video_size 1080x1920 -framerate 30 -i :99.0 \
      -f pulse -i default \
      -c:v libx264 -preset veryfast -b:v 4500k -maxrate 5000k -bufsize 8000k \
      -pix_fmt yuv420p -g 60 -c:a aac -b:a 160k \
      -f flv "$RTMP_DEST"

    echo "[$(date)] Luồng bị gián đoạn. Tự động kết nối lại sau 5 giây..."
    sleep 5
done
