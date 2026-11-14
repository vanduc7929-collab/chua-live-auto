#!/bin/bash
export TZ="Asia/Ho_Chi_Minh"
APP_PORT="${PORT:-3000}"

export TIKTOK_USERNAME="${TIKTOK_USER:-$TIKTOK_USERNAME}"
export PORT="$APP_PORT"

echo "=== BOT LIVESTREAM TIKTOK 24/7 (CÂU CÁ TIKTOK LIVE) ĐÃ KHỞI ĐỘNG ==="

# 0. Bật PulseAudio
pulseaudio -D --exit-idle-time=-1 || true

# Patch giao diện Game Câu Cá: TikTok Safe Area & Game Guide & Chặn Google Translate
echo "=== ĐANG ÁP DỤNG TINH CHỈNH GIAO DIỆN GAME (TIKTOK SAFE AREA & HƯỚNG DẪN) ==="
if [ -f public/js/08-render.js ]; then
  # 1. Dời HUD Top cần thủ và Thanh năng lượng bão cá vàng xuống vùng an toàn (Y=310..525)
  sed -i "s/roundRect(30,30,520,185,24)/roundRect(30,310,500,160,20)/g" public/js/08-render.js
  sed -i "s/68,26,'#ffd700','left'/345,22,'#ffd700','left'/g" public/js/08-render.js
  sed -i "s/112+i\*40/385+i*32/g" public/js/08-render.js
  sed -i "s/txt(Math.round(s.kg)+' kg',530,/txt(Math.round(s.kg)+' kg',515,/g" public/js/08-render.js
  sed -i "s/roundRect(30,235,1020,40,20)/roundRect(30,485,1020,40,20)/g" public/js/08-render.js
  sed -i "s/roundRect(34,239,/roundRect(34,489,/g" public/js/08-render.js
  sed -i "s/540,264,22/540,514,22/g" public/js/08-render.js

  # 2. Thêm Bảng Hướng Dẫn Cách Chơi (Game Guide) vào hàm hud()
  node << 'EOF'
const fs = require('fs');
const file = 'public/js/08-render.js';
if (fs.existsSync(file)) {
  let code = fs.readFileSync(file, 'utf8');
  const guide = "g.fillStyle='#000c';g.beginPath();g.roundRect(550,310,500,160,20);g.fill();"
    + "txt('📜 CÁCH THAM GIA',575,345,22,'#38bdf8','left');"
    + "txt('💬 Chat \"Câu\" để lấy cần câu',575,380,18,'#fff','left');"
    + "txt('❤️ Thả tim để tăng tốc cắn câu',575,410,18,'#f43f5e','left');"
    + "txt('🎁 Tặng Quà săn BOSS Thủy Quái',575,440,18,'#eab308','left');";

  if (!code.includes('CÁCH THAM GIA')) {
    code = code.replace("g.fillStyle='#0008';g.beginPath();g.roundRect(30,485,", guide + "g.fillStyle='#0008';g.beginPath();g.roundRect(30,485,");
    fs.writeFileSync(file, code);
    console.log("✅ Đã chèn bảng hướng dẫn cách chơi vào 08-render.js");
  }
}
EOF
fi

# Chặn triệt để Google Translate thanh dịch đè UI
if [ -f public/css/style.css ]; then
  echo "body { top: 0 !important; position: static !important; } .skiptranslate, iframe.skiptranslate, #goog-gt-tt { display: none !important; }" >> public/css/style.css
fi
if [ -f public/index.html ]; then
  sed -i 's/<head>/<head><meta name="google" content="notranslate">/' public/index.html || true
fi

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
         --disable-translate \
         --disable-features=Translate,OptimizationHints,MediaRouter \
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
