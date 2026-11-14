#!/bin/bash
export TZ="Asia/Ho_Chi_Minh"
APP_PORT="${PORT:-3000}"

echo "=== BOT LIVESTREAM TIKTOK 24/7 (CHÙA LINH ỨNG) ĐÃ KHỞI ĐỘNG ==="

# 0. Khởi động PulseAudio để bắt âm thanh tiếng gõ mõ, tụng kinh
pulseaudio -D --exit-idle-time=-1 || true

# 1. Khởi động Server Web Chùa Online
echo "[1/4] Khởi động Server Node.js trên cổng $APP_PORT..."
node server.js &
sleep 8

# 2. Tạo màn hình ảo tỉ lệ dọc Full HD 1080x1920
echo "[2/4] Khởi tạo màn hình ảo Xvfb Full HD..."
Xvfb :99 -screen 0 1080x1920x24 &
export DISPLAY=:99
sleep 3

# 3. Mở giao diện Chánh Điện trên Chromium không viền, phóng to bảng 1.25x và tắt Google Dịch
echo "[3/4] Mở giao diện Chánh Điện Full HD..."
chromium --no-sandbox \
         --kiosk \
         --window-size=1080,1920 \
         --disable-infobars \
         --disable-features=Translate \
         --no-default-browser-check \
         --force-device-scale-factor=1.25 \
         --autoplay-policy=no-user-gesture-required \
         "http://localhost:${APP_PORT}/?obs=1" &
sleep 8

# 4. Tự động kết nối với tài khoản TikTok của bạn
if [ -n "$TIKTOK_USER" ]; then
    echo "[4/4] Đang kết nối tới phòng Live của: @$TIKTOK_USER..."
    curl -s -X POST "http://localhost:${APP_PORT}/api/tiktok/connect" \
         -H "Content-Type: application/json" \
         -d "{\"username\": \"$TIKTOK_USER\"}" || true
fi

# VÒNG LẶP TREO LIVE 24/7 (FULL HD 1080p + ÂM THANH TIẾNG MÕ TỤNG KINH)
echo "=== BẮT ĐẦU PHÁT LUỒNG VIDEO 1080P + AUDIO LÊN TIKTOK ==="
while true; do
    echo "[$(date)] FFmpeg đang đẩy luồng Full HD lên TikTok RTMP..."
    
    ffmpeg -f x11grab -video_size 1080x1920 -framerate 30 -i :99.0 \
      -f pulse -i default \
      -c:v libx264 -preset veryfast -b:v 4500k -maxrate 5000k -bufsize 8000k \
      -pix_fmt yuv420p -g 60 -c:a aac -b:a 160k \
      -f flv "$RTMP_DEST"

    echo "[$(date)] Luồng bị gián đoạn. Tự động kết nối lại sau 5 giây..."
    sleep 5
done
