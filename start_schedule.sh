#!/bin/bash
export TZ="Asia/Ho_Chi_Minh"

echo "=== BOT HẸN GIỜ LIVESTREAM TIKTOK (18:00 - 22:00 VN) ĐÃ KHỞI ĐỘNG ==="

while true; do
    CURRENT_HOUR=$(date +%H)
    CURRENT_MIN=$(date +%M)

    # Khung giờ 18h00 - 21h59
    if [ "$CURRENT_HOUR" -ge 18 ] && [ "$CURRENT_HOUR" -lt 22 ]; then
        echo "[$(date)] >>> Đang trong khung giờ vàng (18h-22h) -> Bắt đầu phát live!"

        # 1. Bật Server Chùa
        if ! pgrep -f "node server.js" > /dev/null; then
            node server.js &
            sleep 6
        fi

        # 2. Bật màn hình ảo chuẩn 9:16 (720x1280)
        if ! pgrep -f "Xvfb" > /dev/null; then
            Xvfb :99 -screen 0 720x1280x24 &
            export DISPLAY=:99
            chromium --no-sandbox --kiosk --window-size=720,1280 "http://localhost:3000/?obs=1" &
            sleep 5
        fi

        # 3. Kết nối kênh TikTok của bạn nếu có cài đặt TIKTOK_USER
        if [ -n "$TIKTOK_USER" ]; then
            curl -s -X POST http://localhost:3000/api/tiktok/connect \
                 -H "Content-Type: application/json" \
                 -d "{\"username\": \"$TIKTOK_USER\"}" || true
        fi

        # 4. Phát luồng FFmpeg lên TikTok
        if ! pgrep -f "ffmpeg" > /dev/null; then
            echo "[$(date)] Đang đẩy luồng video lên TikTok RTMP..."
            ffmpeg -f x11grab -video_size 720x1280 -framerate 30 -i :99.0 \
              -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
              -c:v libx264 -preset veryfast -b:v 2500k \
              -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k \
              -f flv "$RTMP_DEST" &
        fi

    else
        # Ngoài khung giờ -> Tắt sạch tiến trình để nghỉ ngơi và tiết kiệm giờ
        if pgrep -f "ffmpeg" > /dev/null || pgrep -f "chromium" > /dev/null; then
            echo "[$(date)] <<< Đã hết khung giờ (22h00) -> Tắt livestream đi ngủ!"
            pkill -f "ffmpeg" || true
            pkill -f "chromium" || true
            pkill -f "Xvfb" || true
            pkill -f "node server.js" || true
        fi
        echo "[$(date)] Hiện tại là ${CURRENT_HOUR}:${CURRENT_MIN} (Chờ đến 18:00)..."
    fi

    sleep 60
done
