#!/bin/bash
export TZ="Asia/Ho_Chi_Minh"
APP_PORT="${PORT:-3000}"

echo "=== BOT LIVESTREAM TIKTOK 24/7 (CHÙA LINH ỨNG) ĐÃ KHỞI ĐỘNG ==="

# 1. Khởi động Server Web Chùa Online
echo "[1/4] Khởi động Server Node.js trên cổng $APP_PORT..."
node server.js &
sleep 8

# 2. Tạo màn hình ảo tỉ lệ dọc 9:16 (720x1280)
echo "[2/4] Khởi tạo màn hình ảo Xvfb..."
Xvfb :99 -screen 0 720x1280x24 &
export DISPLAY=:99
sleep 3

# 3. Mở giao diện Chánh Điện trên Chromium không viền
echo "[3/4] Mở giao diện Chánh Điện OBS sạch trên cổng $APP_PORT..."
chromium --no-sandbox \
         --kiosk \
         --window-size=720,1280 \
         --disable-infobars \
         "http://localhost:${APP_PORT}/?obs=1" &
sleep 8

# 4. Tự động kết nối với tài khoản TikTok của bạn
if [ -n "$TIKTOK_USER" ]; then
    echo "[4/4] Đang kết nối tới phòng Live của: @$TIKTOK_USER..."
    curl -s -X POST "http://localhost:${APP_PORT}/api/tiktok/connect" \
         -H "Content-Type: application/json" \
         -d "{\"username\": \"$TIKTOK_USER\"}" || true
fi

# VÒNG LẶP TREO LIVE 24/7 (TỰ ĐỘNG PHÁT LẠI NẾU RỚT MẠNG)
echo "=== BẮT ĐẦU PHÁT LUỒNG VIDEO 24/7 LÊN TIKTOK ==="
while true; do
    echo "[$(date)] FFmpeg đang đẩy luồng video lên TikTok RTMP..."
    
    ffmpeg -f x11grab -video_size 720x1280 -framerate 30 -i :99.0 \
      -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
      -c:v libx264 -preset veryfast -b:v 2500k -maxrate 3000k -bufsize 5000k \
      -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k \
      -f flv "$RTMP_DEST"

    echo "[$(date)] Luồng bị gián đoạn. Tự động kết nối lại sau 5 giây..."
    sleep 5
done
