#!/bin/bash
export TZ="Asia/Ho_Chi_Minh"
APP_PORT="${PORT:-3000}"

export TIKTOK_USERNAME="${TIKTOK_USER:-$TIKTOK_USERNAME}"
export PORT="$APP_PORT"

echo "=== BOT LIVESTREAM TIKTOK 24/7 (CÂU CÁ TIKTOK LIVE) ĐÃ KHỞI ĐỘNG ==="

# 0. Bật PulseAudio
pulseaudio -D --exit-idle-time=-1 || true

# 1. Khởi động Server Game Câu Cá
echo "[1/4] Khởi động Server Game trên cổng $APP_PORT với kênh @$TIKTOK_USERNAME..."
node server/index.js &
sleep 8

# 2. Tạo màn hình ảo 720x1280
echo "[2/4] Khởi tạo màn hình ảo Xvfb 720x1280..."
Xvfb :99 -screen 0 720x1280x24 &
export DISPLAY=:99
sleep 3

# 3. Mở giao diện Hồ Câu (BỎ HOÀN TOÀN transparent ĐỂ HIỆN BẦU TRỜI XANH VÀ MẶT HỒ)
echo "[3/4] Mở giao diện Hồ Câu Cá Full đồ họa..."
chromium --no-sandbox \
         --kiosk \
         --window-size=720,1280 \
         --disable-dev-shm-usage \
         --disable-gpu \
         --js-flags="--max-old-space-size=256" \
         --disable-infobars \
         --lang=vi \
         --disable-features=Translate,OptimizationHints \
         --no-default-browser-check \
         --autoplay-policy=no-user-gesture-required \
         "http://localhost:${APP_PORT}/?mock=0" &
sleep 8

# VÒNG LẶP TREO LIVE 24/7 (HD 720P FULL MÀU SẮC & ÂM THANH)
echo "=== BẮT ĐẦU PHÁT LUỒNG CÂU CÁ LÊN TIKTOK ==="
while true; do
    echo "[$(date)] FFmpeg đang đẩy luồng Câu Cá lên TikTok RTMP..."
    
    ffmpeg -f x11grab -video_size 720x1280 -framerate 30 -i :99.0 \
      -f pulse -i default \
      -c:v libx264 -preset ultrafast -b:v 2500k -maxrate 3000k -bufsize 3000k -threads 2 \
      -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k \
      -f flv "$RTMP_DEST"

    echo "[$(date)] Luồng bị gián đoạn. Tự động kết nối lại sau 5 giây..."
    sleep 5
done
