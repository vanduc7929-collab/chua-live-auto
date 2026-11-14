#!/bin/bash
export TZ="Asia/Ho_Chi_Minh"
APP_PORT="${PORT:-3000}"

export TIKTOK_USERNAME="${TIKTOK_USER:-$TIKTOK_USERNAME}"
export PORT="$APP_PORT"

echo "=== BOT LIVESTREAM TIKTOK 24/7 (CÂU CÁ TIKTOK LIVE - MOBILE PRO) ĐÃ KHỞI ĐỘNG ==="

# 0. Bật PulseAudio với Virtual Sink & Monitor chuẩn cho FFmpeg
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
pulseaudio -D --exit-idle-time=-1 || true
sleep 1
pactl load-module module-null-sink sink_name=vout sink_properties=device.description="Virtual_Speaker" || true
pactl set-default-sink vout || true
pactl set-default-source vout.monitor || true

# 0.5. Chạy bản vá tối ưu Giao diện Mobile Safe-Area, Thu ngắn biển & Giọng AI Tiếng Việt
cat << 'EOF' > patch_game.js
const fs = require('fs');

// 1. Thêm API Google TTS Tiếng Việt vào server/index.js
let srv = fs.readFileSync('server/index.js', 'utf8');
if (!srv.includes('/api/tts')) {
  const ttsRoute = `
const TTS_CACHE = new Map();
app.get('/api/tts', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim().slice(0, 200);
    if (!q) return res.sendStatus(400);
    let buf = TTS_CACHE.get(q);
    if (!buf) {
      const u = 'https://translate.google.com/translate_tts?ie=UTF-8&tl=vi&client=tw-ob&q=' + encodeURIComponent(q);
      const r = await fetch(u, { headers: { 'User-Agent': 'Mozilla/5.0' }, signal: AbortSignal.timeout(6000) });
      if (!r.ok) return res.sendStatus(502);
      buf = Buffer.from(await r.arrayBuffer());
      if (TTS_CACHE.size > 200) TTS_CACHE.delete(TTS_CACHE.keys().next().value);
      TTS_CACHE.set(q, buf);
    }
    res.set({ 'Content-Type': 'audio/mpeg', 'Cache-Control': 'public, max-age=3600' }).send(buf);
  } catch (e) { res.sendStatus(502); }
});
`;
  srv = srv.replace("app.get('/api/music'", ttsRoute + "\napp.get('/api/music'");
  fs.writeFileSync('server/index.js', srv);
}

// 2. Thêm sự kiện 'member' (người xem vào phòng) trong server/tiktok.js
let tt = fs.readFileSync('server/tiktok.js', 'utf8');
if (!tt.includes("out('member'")) {
  tt = tt.replace(
    "c.on(E.FOLLOW || 'follow'",
    "c.on(E.MEMBER || 'member', d => { const u = user(d); out('member', u); });\n    c.on(E.FOLLOW || 'follow'"
  );
  fs.writeFileSync('server/tiktok.js', tt);
}

// 3. Tăng âm lượng nhạc nền synth trong packages/music/tracks.js
let trk = fs.readFileSync('packages/music/tracks.js', 'utf8');
trk = trk.replace(/vol:\s*\.04/g, 'vol: .14');
fs.writeFileSync('packages/music/tracks.js', trk);

// 4. Thu ngắn biển (WL=920 thay vì 720), giảm spotZoom=1.42 để không mất chữ khi zoom trong public/js/01-setup.js
let s01 = fs.readFileSync('public/js/01-setup.js', 'utf8');
s01 = s01.replace('WL=720', 'WL=920').replace('spotZoom:1.8', 'spotZoom:1.42').replace('sfxVolume:.5,musicVolume:.35', 'sfxVolume:.75,musicVolume:.55').replace('qteSeconds:12,qteStart:35,qteDecay:3.5,qtePush:7,qtePushOwner:12,qteLike:1', 'qteSeconds:16,qteStart:50,qteDecay:2.0,qtePush:12,qtePushOwner:20,qteLike:2.5');
fs.writeFileSync('public/js/01-setup.js', s01);

// 5. Căn lại vị trí đứng câu cá (slotPos) vào giữa màn hình điện thoại (X=165..837, Y=675..909) trong public/js/03-state.js
let s03 = fs.readFileSync('public/js/03-state.js', 'utf8');
s03 = s03.replace(
  'const slotPos=i=>({x:45+(i%12)*90,y:480+((i/12)|0)*80});',
  'const slotPos=i=>({x:165+(i%8)*96,y:675+((i/8)|0)*78});'
);
fs.writeFileSync('public/js/03-state.js', s03);

// 6. Nâng cấp public/js/04-sfx-tts.js: Dùng WebAudio phát giọng AI Tiếng Việt (/api/tts) + MC tự động mời chào
let s04 = fs.readFileSync('public/js/04-sfx-tts.js', 'utf8');
const newTtsCode = `
const sayQ=[];let talking=false,lastSayAt=0;
function say(t,pri){if(!GC.tts||!t)return;if(sayQ.length>5){if(!pri)return;sayQ.shift()}pri?sayQ.unshift(t):sayQ.push(t);next()}
async function next(){
  if(talking||!sayQ.length)return;
  if(!AC){try{startAudio()}catch(e){}}
  if(!AC)return;
  if(AC.state==='suspended'){try{await AC.resume()}catch(e){}}
  talking=true;lastSayAt=Date.now();
  const text=sayQ.shift();
  const done=()=>{if(talking){talking=false;setTimeout(next,250)}};
  const timer=setTimeout(done,8000);
  try{
    const r=await fetch('/api/tts?q='+encodeURIComponent(text));
    if(!r.ok)throw new Error('tts '+r.status);
    const ab=await r.arrayBuffer();
    const buf=await AC.decodeAudioData(ab);
    const src=AC.createBufferSource(),gNode=AC.createGain();
    gNode.gain.value=1.5;
    src.buffer=buf;src.connect(gNode);gNode.connect(AC.destination);
    src.onended=()=>{clearTimeout(timer);done()};
    src.start(0);
  }catch(e){clearTimeout(timer);done()}
}
const MC_LINES=[
  'Chào mừng các bạn đến với Hồ Câu Tương Tác! Hãy bình luận chữ Câu để ra cầu thả cần nhé!',
  'Thả tim thật nhiều để cá nhanh cắn câu và tích đầy thanh năng lượng gọi Bão Cá Vàng nhân đôi điểm số!',
  'Khi có Cá Khổng Lồ cắn câu, mọi người hãy bình luận chữ KEO và thả tim phụ cần thủ kéo cá lên nhé!',
  'Tặng quà bất kỳ để kích hoạt Cần Thần Giật Điện và bước lên Du Thuyền V I P nhé!'
];
let mcIdx=0;
setInterval(()=>{
  if(!talking&&sayQ.length===0&&Date.now()-lastSayAt>28000){
    say(MC_LINES[mcIdx++%MC_LINES.length],false);
  }
},10000);
`;
s04 = s04.replace(/const sayQ=\[\];[\s\S]*$/, newTtsCode);
fs.writeFileSync('public/js/04-sfx-tts.js', s04);

// 7. Tinh chỉnh Spotlight, Du thuyền VIP, và Card vinh danh vừa khít khung điện thoại trong public/js/05a-spotlight.js
let s05a = fs.readFileSync('public/js/05a-spotlight.js', 'utf8');
s05a = s05a.replace(
  'const vipPos=i=>({x:[510,410,610][i]||510,y:676});',
  'const vipPos=i=>({x:[540,450,630][i]||540,y:876});'
);
s05a = s05a.replace(
  'function sayNow(t){if(!GC.tts)return;sayQ.length=0;try{speechSynthesis.cancel()}catch(e){}talking=false;say(t,true)}',
  'function sayNow(t){if(!GC.tts)return;sayQ.length=0;say(t,true)}'
);
s05a = s05a.replace(
  'if(p&&isFinite(p.x0+p.y)){tx=Math.min(W-W/2/tz,Math.max(W/2/tz,p.x0-25));ty=Math.min(H-H/2/tz,Math.max(H/2/tz,p.y-60))}',
  'if(p&&isFinite(p.x0+p.y)){tx=Math.min(680,Math.max(400,p.x0-25));ty=Math.min(980,Math.max(620,p.y-40))}'
);
s05a = s05a.replace(
  'const age=(c.t0||(c.t0=c.t))-c.t,s0=Math.min(1,age/.3),s=1-Math.pow(1-s0,3),a=Math.min(1,c.t/.4),cx=W/2,cy=H/2+60;',
  'const age=(c.t0||(c.t0=c.t))-c.t,s0=Math.min(1,age/.3),s=(1-Math.pow(1-s0,3))*0.78,a=Math.min(1,c.t/.4),cx=W/2,cy=820;'
);
s05a = s05a.replace('676', '876').replace('676', '876').replace('772', '972').replace('772', '972').replace('724', '924').replace('672', '872').replace('560,6', '760,6').replace('560);g.lineTo(436,578);g.lineTo(386,596)', '760);g.lineTo(436,778);g.lineTo(386,796)').replace('764', '964');
fs.writeFileSync('public/js/05a-spotlight.js', s05a);

// 8. Tinh chỉnh thanh Giằng Co QTE trong public/js/05b-comedy.js (Đưa lên Y=1060, gọn trong X=170..910, không bao giờ mất chữ)
let s05b = fs.readFileSync('public/js/05b-comedy.js', 'utf8');
const newDrawQTE = `function drawQTE(){const p=inQte();if(!p)return;const left=Math.max(0,GC.qteSeconds-p.t),tn=p.tn||0,y=1065,w=700,x=(W-w)/2;
 g.fillStyle='rgba(0,0,0,0.78)';g.strokeStyle='#ffd700';g.lineWidth=3;g.beginPath();g.roundRect(165,985,750,210,24);g.fill();g.stroke();
 txt('⏱ GIẰNG CO: '+Math.ceil(left)+'s',W/2,1040,42,left<4?'#ff5252':'#fff');
 g.fillStyle='#222';g.beginPath();g.roundRect(x,y,w,48,24);g.fill();
 g.fillStyle=tn>66?'#7dff6b':tn>33?'#ffd54a':'#ff5252';g.beginPath();g.roundRect(x+5,y+5,Math.max(20,(w-10)*tn/100),38,19);g.fill();
 txt('LỰC KÉO '+Math.floor(tn)+'%',W/2,y+33,26);
 txt('💬 Gõ "KEO" + ❤️ Thả Tim giúp '+(p.name||'').slice(0,12)+'!',W/2,y+82,22,'#ffd700');
 txt('🎁 Tặng Quà bất kỳ = GIẬT ĐIỆN kéo lên ngay!',W/2,y+112,20,'#7dffb0')}`;
s05b = s05b.replace(/function drawQTE\(\)\{[\s\S]*?GIẬT ĐIỆN`,W\/2,y\+120,28,'#ffd700'\)\}/, newDrawQTE);
s05b = s05b.replace('H-110,36', '1240,26');
fs.writeFileSync('public/js/05b-comedy.js', s05b);

// 9. Giới hạn vùng cá bơi từ Y=960..1460 (trên khung bình luận TikTok) trong public/js/06-fish.js
let s06 = fs.readFileSync('public/js/06-fish.js', 'utf8');
s06 = s06.replace('R(WL+120,H-120)', 'R(WL+50,1420)').replace('R(WL+200,H-150)', 'R(WL+80,1440)').replace('H-R(40,120)', '1460-R(10,50)');
fs.writeFileSync('public/js/06-fish.js', s06);

// 10. Thiết kế lại Bầu trời, Cầu cảng (Y=620..882) và Bảng HUD + Hướng dẫn trong Vùng An Toàn (X=135..945, Y=295..510) trong public/js/08-render.js
let s08 = fs.readFileSync('public/js/08-render.js', 'utf8');
s08 = s08.replace("g.ellipse(120,445,220,60,0,0,7);g.fill();emo('🌴',70,400,110);emo('🏝️',200,430,60);", "g.ellipse(210,625,180,45,0,0,7);g.fill();emo('🌴',180,585,85);emo('🏝️',270,610,50);");
s08 = s08.replace(
  "function dock(){g.fillStyle='#8a5a2b';g.fillRect(0,440,W,262);g.fillStyle='#a8743c';for(let y=440;y<700;y+=26)g.fillRect(0,y,W,3);\n g.fillStyle='#5b3a1a';g.fillRect(0,698,W,12);for(let x=30;x<W;x+=180)g.fillRect(x,700,16,90)}",
  "function dock(){g.fillStyle='#8a5a2b';g.fillRect(0,620,W,262);g.fillStyle='#a8743c';for(let y=620;y<880;y+=26)g.fillRect(0,y,W,3);\n g.fillStyle='#5b3a1a';g.fillRect(0,878,W,12);for(let x=140;x<950;x+=160)g.fillRect(x,880,16,80)}"
);
s08 = s08.replace(
  "if(p.st==='epic'&&SP.p===p)txt('‼️ CÁ KHỔNG LỒ ‼️',Math.max(150,Math.min(W-150,x)),y-140,24,'#ff5252');",
  "if(p.st==='epic'&&SP.p===p)txt('‼️ CÁ KHỔNG LỒ ‼️',Math.max(300,Math.min(W-300,x)),y-135,22,'#ff5252');"
);
s08 = s08.replace(
  "txt(L.tier==='junk'?L.n:`${L.n} ${Math.round(L.kg)}kg`,x,y-205,18,L.tier==='legend'?'#ffd700':'#fff')",
  "txt(L.tier==='junk'?L.n:`${L.n} ${Math.round(L.kg)}kg`,Math.max(260,Math.min(W-260,x)),y-195,18,L.tier==='legend'?'#ffd700':'#fff')"
);

const newHud = `function hud(){
 const top=Object.values(scores).sort((a,b)=>b.kg-a.kg).slice(0,3);
 // Bảng Trái: TOP CẦN THỦ (X=135..530, Y=295..455)
 g.fillStyle='rgba(0,0,0,0.78)';g.strokeStyle='#ffd700';g.lineWidth=2.5;
 g.beginPath();g.roundRect(135,295,395,160,18);g.fill();g.stroke();
 txt('🏆 TOP CẦN THỦ',332,328,21,'#ffd700','center');
 if(!top.length)txt('Chưa có ai — Gõ "Câu" ngay!',332,385,17,'#cbd5e1','center');
 top.forEach((s,i)=>{
   txt(['🥇','🥈','🥉'][i]+' '+s.name.slice(0,11),152,364+i*32,19,'#fff','left');
   txt(Math.round(s.kg)+' kg',514,364+i*32,19,'#7dffb0','right');
 });

 // Bảng Phải: HƯỚNG DẪN CÁCH CHƠI (X=550..945, Y=295..455)
 g.fillStyle='rgba(0,0,0,0.78)';g.strokeStyle='#38bdf8';g.lineWidth=2.5;
 g.beginPath();g.roundRect(550,295,395,160,18);g.fill();g.stroke();
 txt('📜 HƯỚNG DẪN CÁCH CHƠI',747,326,20,'#38bdf8','center');
 txt('💬 Gõ "Câu" → Ra cầu thả cần',568,358,17,'#fff','left');
 txt('❤️ Thả tim → Cá nhanh cắn câu',568,386,17,'#ff8fa3','left');
 txt('💪 Gõ "KEO" → Phụ kéo Thủy Quái',568,414,17,'#7dffb0','left');
 txt('🎁 Tặng Quà → Giật điện & Lên VIP',568,442,17,'#ffd700','left');

 // Thanh Năng Lượng Bão Cá Vàng (X=135..945, Y=466..504)
 g.fillStyle='rgba(0,0,0,0.72)';g.beginPath();g.roundRect(135,466,810,38,19);g.fill();
 g.fillStyle=frenzy>0?'#ffd700':'#ff4d8d';
 g.beginPath();g.roundRect(139,470,Math.max(12,802*(frenzy>0?frenzy/GC.frenzySeconds:energy/100)),30,15);g.fill();
 txt(frenzy>0?'🌟 BÃO CÁ VÀNG '+Math.ceil(frenzy)+'s (x2 ĐIỂM)':'⚡ Năng lượng Bão Cá: '+Math.floor(energy)+'% (Thả tim + Bình luận)',540,492,18);

 if(banner.t>0){
   g.fillStyle='rgba(0,0,0,0.8)';g.beginPath();g.roundRect(160,520,760,54,16);g.fill();
   txt(banner.s,540,556,28,'#ffd700');
 }
 if(queue.length)txt('⏳ '+queue.length+' người đang chờ',935,535,18,'#fff','right');
}`;
s08 = s08.replace(/function hud\(\)\{[\s\S]*?function draw\(\)/, newHud + '\nfunction draw()');
fs.writeFileSync('public/js/08-render.js', s08);

// 11. Thêm AI chào mừng người xem mới vào phòng (member) & khi gõ Câu lần đầu trong public/js/09-events.js
let s09 = fs.readFileSync('public/js/09-events.js', 'utf8');
const memberPatch = `
let lastJoinWelcome=0;
const H_={
 member:u=>{
   if(Date.now()-lastJoinWelcome>10000&&!talking){
     lastJoinWelcome=Date.now();
     say('Chào mừng '+u.name+' đã ghé hồ câu! Gõ chữ Câu vào bình luận để thả cần nhé!',false);
   }
 },
 chat:u=>{
   energyAdd(GC.chatEnergy);
   const isNew=!players.has(u.id);
   const p=join(u);
   if(isNew&&p&&Date.now()-lastJoinWelcome>6000){
     lastJoinWelcome=Date.now();
     say('Cần thủ '+u.name+' đã ra cầu thả cần!',false);
   }
   tugComment(u);
   if(norm(u.comment).includes('nemdep'))throwSlip(u);
 },`;
s09 = s09.replace(/const H_=\{chat:u=>\{[^}]+\},/, memberPatch);
fs.writeFileSync('public/js/09-events.js', s09);

// 12. Ẩn triệt để thanh Google Translate trong public/index.html
let idx = fs.readFileSync('public/index.html', 'utf8');
if (!idx.includes('notranslate')) {
  idx = idx.replace('<head>', '<head><meta name="google" content="notranslate">');
  fs.writeFileSync('public/index.html', idx);
}
console.log('✅ Đã áp dụng toàn bộ bản vá Giao diện Mobile Safe-Area & Giọng AI Tiếng Việt!');
EOF
node patch_game.js

# 1. Khởi động Server Game Câu Cá
echo "[1/4] Khởi động Server Game trên cổng $APP_PORT với kênh @$TIKTOK_USERNAME..."
node server/index.js &
sleep 6

# 2. Tạo màn hình ảo 720x1280
echo "[2/4] Khởi tạo màn hình ảo Xvfb 720x1280..."
Xvfb :99 -screen 0 720x1280x24 &
export DISPLAY=:99
sleep 2

# 3. Mở giao diện Hồ Câu
echo "[3/4] Mở giao diện Hồ Câu Cá..."
chromium --no-sandbox \
         --kiosk \
         --window-size=720,1280 \
         --disable-dev-shm-usage \
         --disable-gpu \
         --js-flags="--max-old-space-size=256" \
         --disable-infobars \
         --lang=vi \
         --disable-translate \
         --disable-features=Translate,TranslateUI,OptimizationHints,MediaRouter \
         --no-default-browser-check \
         --autoplay-policy=no-user-gesture-required \
         "http://localhost:${APP_PORT}/?mock=0" &
sleep 7

# VÒNG LẶP TREO LIVE 24/7
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
