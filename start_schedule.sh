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

// 4. Cấu hình game: đồng bộ cả server/config.js lẫn public/js/01-setup.js (tránh /config.js ghi đè!)
let cfgJs = fs.readFileSync('server/config.js', 'utf8');
cfgJs = cfgJs.replace("num('MAX_FISHERS', 36)", "num('MAX_FISHERS', 24)")
             .replace("num('SPOTLIGHT_ZOOM', 1.8)", "num('SPOTLIGHT_ZOOM', 1.42)")
             .replace("num('QTE_SECONDS', 12)", "num('QTE_SECONDS', 18)")
             .replace("num('QTE_START', 35)", "num('QTE_START', 45)")
             .replace("num('QTE_DECAY', 3.5)", "num('QTE_DECAY', 1.5)")
             .replace("num('QTE_PUSH', 7)", "num('QTE_PUSH', 8)")
             .replace("num('QTE_PUSH_OWNER', 12)", "num('QTE_PUSH_OWNER', 12)")
             .replace("num('QTE_LIKE', 1)", "num('QTE_LIKE', 1.5)")
             .replace("num('VIP_SECONDS', 180)", "num('VIP_SECONDS', 300)")
             .replace("num('SFX_VOLUME', .5)", "num('SFX_VOLUME', .75)")
             .replace("num('MUSIC_VOLUME', .35)", "num('MUSIC_VOLUME', .55)");
fs.writeFileSync('server/config.js', cfgJs);

let s01 = fs.readFileSync('public/js/01-setup.js', 'utf8');
s01 = s01.replace('maxFishers:36', 'maxFishers:24')
         .replace('WL=720', 'WL=920')
         .replace('spotZoom:1.8', 'spotZoom:1.42')
         .replace('sfxVolume:.5,musicVolume:.35', 'sfxVolume:.75,musicVolume:.55')
         .replace('qteSeconds:12,qteStart:35,qteDecay:3.5,qtePush:7,qtePushOwner:12,qteLike:1', 'qteSeconds:18,qteStart:45,qteDecay:1.5,qtePush:8,qtePushOwner:12,qteLike:1.5')
         .replace('vipSeconds:180', 'vipSeconds:300');
fs.writeFileSync('public/js/01-setup.js', s01);

// 5. Căn lại vị trí đứng câu cá (slotPos) vào giữa màn hình điện thoại (X=165..837, Y=675..909) trong public/js/03-state.js
let s03 = fs.readFileSync('public/js/03-state.js', 'utf8');
s03 = s03.replace(
  'const slotPos=i=>({x:45+(i%12)*90,y:480+((i/12)|0)*80});',
  'const slotPos=i=>({x:165+(i%8)*96,y:675+((i/8)|0)*78});'
);
fs.writeFileSync('public/js/03-state.js', s03);

// 6. Nâng cấp public/js/04-sfx-tts.js: Dùng WebAudio phát giọng AI Tiếng Việt (/api/tts), rút gọn tên người đọc <= 7 ký tự + MC tự động mời chào
let s04 = fs.readFileSync('public/js/04-sfx-tts.js', 'utf8');
const newTtsCode = `
const sayQ=[];let talking=false,lastSayAt=0;
function cleanTts(t){
  if(!t)return '';
  return String(t)
    .replace(/([A-Za-z0-9_.\\s]{8,})/g, m => m.trim().slice(0, 7))
    .slice(0, 75);
}
function say(t,pri){
  if(!GC.tts||!t)return;
  const ct=cleanTts(t);
  if(!ct)return;
  if(sayQ.length>5){if(!pri)return;sayQ.shift()}
  pri?sayQ.unshift(ct):sayQ.push(ct);
  next();
}
async function next(){
  if(talking||!sayQ.length)return;
  if(!AC){try{startAudio()}catch(e){}}
  if(!AC)return;
  if(AC.state==='suspended'){try{await AC.resume()}catch(e){}}
  talking=true;lastSayAt=Date.now();
  const text=sayQ.shift();
  const done=()=>{if(talking){talking=false;setTimeout(next,250)}};
  const timer=setTimeout(done,6000);
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
  'Chào mừng các bạn đến với Hồ Câu! Hãy gõ chữ Câu để thả cần nhé!',
  'Thả tim thật nhiều để cá nhanh cắn câu và gọi Bão Cá Vàng nhân đôi điểm số!',
  'Khi có Thủy Quái, mọi người hãy gõ KEO và thả tim phụ kéo lên nhé!',
  'Tặng quà bất kỳ để kích hoạt Cần Thần Giật Điện và lên Du Thuyền V I P nhé!'
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

// 6.5. Tối ưu logic tham gia câu cá và CHỈ TẶNG QUÀ MỚI ĐƯỢC LÊN DU THUYỀN VIP trong public/js/05-logic.js
let s05 = fs.readFileSync('public/js/05-logic.js', 'utf8');
const targetJoin = "function join(u){u.id=u.id||u.name;if(!u.id){LOG('Bỏ qua sự kiện không có id/tên','warn');return null}if(players.has(u.id))return null;\n if(players.size>=MAX){if(queue.length<50&&!queue.find(q=>q.id===u.id))queue.push(u);return null}\n const f=[...Array(MAX).keys()].find(i=>!used().has(i)),p={...u,slot:f,st:'cast',t:0,wait:R(2,5),boost:0,keep:0,loot:null};";
const newJoin = `function join(u){u.id=u.id||u.name;if(!u.id){LOG('Bỏ qua sự kiện không có id/tên','warn');return null}
  if(players.has(u.id)){
    const ex=players.get(u.id);ex.la=T;ex.idleAt=T;
    if(ex.st==='idle'||((ex.st==='show'||ex.st==='fall')&&!ex.sp&&(SP.p!==ex||SP.out))){
      ex.again=0;ex.loot=null;ex.st='cast';ex.t=0;ex.wait=R(2,5);SFX.cast();LOG('🎣 '+ex.name+' thả cần lại');
    } else {ex.again=1;LOG('🎣 '+ex.name+' xếp lượt câu tiếp ('+ex.st+')');}
    return ex;
  }
  const dockCnt=[...players.values()].filter(q=>!q.vip).length;
  if(dockCnt>=MAX){if(queue.length<50&&!queue.find(q=>q.id===u.id))queue.push(u);return null}
  const f=[...Array(MAX).keys()].find(i=>!used().has(i));if(f===undefined)return null;
  const p={...u,slot:f,st:'cast',t:0,wait:R(2,5),boost:0,keep:0,loot:null,la:T,idleAt:T};`;
s05 = s05.replace(targetJoin, newJoin);

const targetGift = "function gift(u,coins,comment){LOG(`quà ${u.name}: ${coins} xu`);\n const q=inQte(),own=q&&u.id===q.id;if(q){if(own)zapWin(q);else tugPush(35)}                       // đang giằng co: quà chủ cần = Giật Điện, người khác = +35 lực\n if(coins===1&&!own){throwSlip(u);return}                                                          // quà 1 xu = ném dép Top 1\n const p=join(u)||players.get(u.id);if(!p)return;p.keep=T+GC.giftKeepSeconds;\n if(coins>GC.bigGiftCoins){bomb(p,coins);spotGift(p,coins);say(`${u.name} thả lưới lớn, cá khổng lồ nổi lên khắp biển!`+(comment?' '+comment:''),true)}";
const newGift = `function gift(u,coins,comment){u.id=u.id||u.name;LOG(\`quà \${u.name}: \${coins} xu\`);
 const q=inQte();if(q)zapWin(q);
 if(comment&&norm(comment).includes('nemdep'))throwSlip(u);
 let p=players.get(u.id)||join(u);
 if(!p){p={...u,slot:-1,st:'cast',t:0,wait:1.5,boost:0,keep:0,loot:null,la:T};const vp=vipPos(0);Object.assign(p,{cx:vp.x,cy:vp.y,x:vp.x,x0:vp.x+55,y:vp.y});players.set(u.id,p);}
 p.la=T;makeVip(p);p.keep=T+GC.vipSeconds;
 if(coins>GC.bigGiftCoins){bomb(p,coins);spotGift(p,coins);say(\`\${(u.name||'').slice(0,8)} thả lưới lớn!\`+(comment?' '+comment:''),true)}
 else{banner={t:3,s:\`👑 \${(u.name||'').slice(0,12)} lên Du Thuyền VIP 5 phút!\`};`;
s05 = s05.replace(targetGift, newGift);
s05 = s05.replace("else{p.boost=3;if(p.st!=='epic'&&p.st!=='fall'&&!p.sp){p.st='cast';p.t=0;p.wait=1.5}burst(p.x0,p.y-60,30,'#ff7a18',250);say(`Cảm ơn ${u.name} đã tặng quà.`+(comment?' '+comment:''),true)}}", "p.boost=3;if(p.st!=='epic'&&p.st!=='fall'&&!p.sp){p.st='cast';p.t=0;p.wait=1.5}burst(p.x0,p.y-60,30,'#ff7a18',250);say(`Cảm ơn ${(u.name||'').slice(0,8)} đã tặng quà!`,true)}}");

// Rút gọn câu đọc vinh danh / kỷ lục trong 05-logic.js
s05 = s05.replace(/say\(`\$\{p\.name\} đã phá kỷ lục, vươn lên top một!`/, "say(`Cần thủ ${(p.name||'').slice(0,8)} đã lên top một!`");
s05 = s05.replace(/say\(`Chúc mừng \$\{p\.name\} câu được \$\{L\.n\} nặng \$\{Math\.round\(L\.kg\)\} ký!`,true\)/, "say(`Chúc mừng ${(p.name||'').slice(0,8)} bắt được ${L.n}!`,true)");
s05 = s05.replace(/say\(`Cảm ơn \$\{u\.name\} đã tặng quà\.\`\+\(comment\?' '\+comment:''\),true\)/, "say(`Cảm ơn ${(u.name||'').slice(0,8)} đã tặng quà!`,true)");
fs.writeFileSync('public/js/05-logic.js', s05);

// 7. Tinh chỉnh Spotlight, Du thuyền VIP 5 phút (300s) CHỈ DÀNH CHO NGƯỜI TẶNG QUÀ trong public/js/05a-spotlight.js
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

// Thuyền VIP: bắt được cá to KHÔNG tự lên du thuyền (chỉ tặng quà mới được lên)
s05a = s05a.replace('if(SP.after&&players.has(SP.after.id))makeVip(SP.after);', '');

const targetMakeVip = `function makeVip(p){const o=[...players.values()].filter(q=>q!==p&&q.vip&&T<q.vip);let vi=[0,1,2].find(i=>!o.some(q=>q.vi===i));
 if(vi===undefined){o.sort((a,b)=>a.vip-b.vip);vi=o[0].vi;leave(o[0])}
 p.vip=T+GC.vipSeconds;p.vi=vi;p.slot=-1;p.keep=Math.max(p.keep,p.vip);LOG(\`👑 \${p.name} lên du thuyền VIP \${GC.vipSeconds}s\`)}`;
const newMakeVip = `function makeVip(p){if(!p)return;const o=[...players.values()].filter(q=>q!==p&&q.vip&&T<q.vip);let vi=[0,1,2].find(i=>!o.some(q=>q.vi===i));
 if(vi===undefined){o.sort((a,b)=>a.vip-b.vip);vi=o[0].vi;const ex=o[0];ex.vip=0;ex.la=T;const fs=[...Array(MAX).keys()].find(i=>!used().has(i));if(fs!==undefined){ex.slot=fs;ex.st='idle';}else{leave(ex);}}
 p.vip=T+GC.vipSeconds;p.vi=vi;p.slot=-1;p.keep=Math.max(p.keep,p.vip);LOG(\`👑 \${p.name} lên du thuyền VIP \${GC.vipSeconds}s\`)}`;
s05a = s05a.replace(targetMakeVip, newMakeVip);

s05a = s05a.replace(/sayNow\(`Cá lớn cắn câu! Mọi người spam KEO và thả tim giúp \$\{p\.name\} kéo lên!\`\)/, "sayNow(`Thủy Quái cắn câu! Spam KEO kéo lên nào!`)");
s05a = s05a.replace(/sayNow\(`Chúc mừng \$\{p\.name\} câu được \$\{L\.n\} nặng \$\{Math\.round\(L\.kg\)\} ký\$\{p\.rec\?'\. Kỷ lục mới của phòng!':'!'\}\`\)/, "sayNow(`Chúc mừng ${(p.name||'').slice(0,8)} bắt được ${L.n}!`)");

// Bảng Vinh danh TOP cần thủ mỗi 15 phút (vinh danh ca)
const shiftBannerCode = `
let shiftRank = null;
function drawCard(){
  if(shiftRank && shiftRank.t > 0){
    const left = shiftRank.t, a = Math.min(1, left / 0.5);
    g.save(); g.globalAlpha = a;
    let gr = g.createLinearGradient(165, 340, 915, 960);
    gr.addColorStop(0, '#1e113a'); gr.addColorStop(1, '#0b0416');
    g.fillStyle = gr; g.strokeStyle = '#ffd700'; g.lineWidth = 6; g.shadowColor = '#ffd700'; g.shadowBlur = 30;
    g.beginPath(); g.roundRect(165, 340, 750, 620, 32); g.fill(); g.stroke(); g.shadowBlur = 0;
    txt('👑 TỔNG KẾT CA CÂU (15 PHÚT) 👑', 540, 410, 32, '#ffd700');
    txt('🏆 BẢNG VÀNG CẦN THỦ XUẤT SẮC 🏆', 540, 460, 24, '#7dffb0');
    if(!shiftRank.top || !shiftRank.top.length){
      txt('Chưa có cần thủ nào lên điểm!', 540, 630, 26, '#cbd5e1');
    } else {
      shiftRank.top.forEach((s, i) => {
        const y = 535 + i * 85;
        g.fillStyle = 'rgba(255,255,255,0.08)'; g.beginPath(); g.roundRect(195, y - 40, 690, 70, 16); g.fill();
        txt(['🥇','🥈','🥉'][i] || ('#' + (i+1)), 235, y + 8, 32);
        txt(s.name.slice(0, 10), 285, y + 8, 26, '#fff', 'left');
        txt(Math.round(s.kg) + ' kg', 855, y + 8, 28, '#ffd700', 'right');
      });
    }
    txt('⏱ Bắt đầu ca câu mới sau ' + Math.ceil(left) + 's...', 540, 920, 22, '#38bdf8');
    g.restore();
    return;
  }
`;
s05a = s05a.replace('function drawCard(){', shiftBannerCode);
fs.writeFileSync('public/js/05a-spotlight.js', s05a);

// 8. Tinh chỉnh thanh Giằng Co QTE trong public/js/05b-comedy.js (Đưa lên Y=1060, gọn trong X=170..910)
let s05b = fs.readFileSync('public/js/05b-comedy.js', 'utf8');
const newDrawQTE = `function drawQTE(){const p=inQte();if(!p)return;const left=Math.max(0,GC.qteSeconds-p.t),tn=p.tn||0,y=1065,w=700,x=(W-w)/2;
 g.fillStyle='rgba(0,0,0,0.78)';g.strokeStyle='#ffd700';g.lineWidth=3;g.beginPath();g.roundRect(165,985,750,210,24);g.fill();g.stroke();
 txt('⏱ GIẰNG CO: '+Math.ceil(left)+'s',W/2,1040,42,left<4?'#ff5252':'#fff');
 g.fillStyle='#222';g.beginPath();g.roundRect(x,y,w,48,24);g.fill();
 g.fillStyle=tn>66?'#7dff6b':tn>33?'#ffd54a':'#ff5252';g.beginPath();g.roundRect(x+5,y+5,Math.max(20,(w-10)*tn/100),38,19);g.fill();
 txt('LỰC KÉO '+Math.floor(tn)+'%',W/2,y+33,26);
 txt('💬 Gõ "KEO" + ❤️ Thả Tim giúp '+(p.name||'').slice(0,8)+'!',W/2,y+82,22,'#ffd700');
 txt('🎁 Tặng Quà bất kỳ = GIẬT ĐIỆN kéo lên ngay!',W/2,y+112,20,'#7dffb0')}`;
s05b = s05b.replace(/function drawQTE\(\)\{[\s\S]*?GIẬT ĐIỆN`,W\/2,y\+120,28,'#ffd700'\)\}/, newDrawQTE);
s05b = s05b.replace('H-110,36', '1240,26');
s05b = s05b.replace(/sayNow\(pick\(\[\`Ôi không! Đứt dây rồi![\s\S]*?khóc thét!\`\]\)\)/, "sayNow('Tiếc quá, đứt dây mất rồi!')");
s05b = s05b.replace(/sayNow\(\`Cần thần giật điện! \$\{p\.name\} kéo thẳng cá lên luôn!\`\)/, "sayNow(`Cần thần giật điện! ${(p.name||'').slice(0,8)} kéo cá lên bờ!`)");
fs.writeFileSync('public/js/05b-comedy.js', s05b);

// 9. Giới hạn vùng cá bơi từ Y=960..1460 (trên khung bình luận TikTok) trong public/js/06-fish.js
let s06 = fs.readFileSync('public/js/06-fish.js', 'utf8');
s06 = s06.replace('R(WL+120,H-120)', 'R(WL+50,1420)').replace('R(WL+200,H-150)', 'R(WL+80,1440)').replace('H-R(40,120)', '1460-R(10,50)');
fs.writeFileSync('public/js/06-fish.js', s06);

// 9.5. Tối ưu vòng lặp: CÂU XONG NGHỈ (st='idle'), RESET CA 15 PHÚT trong public/js/07-update.js
let s07 = fs.readFileSync('public/js/07-update.js', 'utf8');
const shiftUpdateCode = `
let shiftTimer = 900;
function resetShift(){
  const topList = Object.values(scores).sort((a,b)=>b.kg-a.kg).slice(0,3);
  shiftRank = { t: 15, top: topList };
  if(SP.p){SP.out=true;SP.after=null;}
  for(const p of players.values()){
    p.vip = 0; p.sp = 0; p.again = 0; p.st = 'idle'; p.t = 0; p.loot = null; p.la = T;
  }
  for(const k in scores) delete scores[k];
  leader = null; roomBest = 0;
  sayNow('Hết ca câu 15 phút! Vinh danh các quán quân và mở ca câu mới!');
}
function update(dt,rdt=dt){
  if(shiftRank && shiftRank.t > 0) shiftRank.t -= dt;
  shiftTimer -= dt;
  if(shiftTimer <= 0){ shiftTimer = 900; resetShift(); }
`;
s07 = s07.replace('function update(dt,rdt=dt){', shiftUpdateCode);

const targetVipLoop = "for(const p of players.values()){const s=p.vip?vipPos(p.vi):slotPos(p.slot);";
const newVipLoop = "for(const p of players.values()){\n if(p.vip&&T>=p.vip){p.vip=0;const fs=[...Array(MAX).keys()].find(i=>!used().has(i));p.slot=fs!==undefined?fs:0;p.st='idle';}\n const s=p.vip?vipPos(p.vi):slotPos(p.slot);";
s07 = s07.replace(targetVipLoop, newVipLoop);

const targetLim = "const lim={cast:.8,wait:p.wait,bite:.9,reel:.8,show:p.sp?4.2:2.6,epic:GC.qteSeconds,fall:2.6}[p.st];\n  if(p.t>=lim){p.t=0;";
const newLim = "const lim={idle:999999,cast:.8,wait:p.wait,bite:.9,reel:.8,show:p.sp?4.2:2.6,epic:GC.qteSeconds,fall:2.6}[p.st]||999999;\n  if(p.st==='idle')continue;\n  if(p.t>=lim){p.t=0;";
s07 = s07.replace(targetLim, newLim);

const targetLoopEnd = "else{p.loot=null;if(p.sp){p.sp=0;spotEnd(p)}if(p.boost>0||T<p.keep){p.st='cast';p.wait=R(2,4);SFX.cast()}else{leave(p);break}}";
const newLoopEnd = "else{p.loot=null;if(p.sp){p.sp=0;spotEnd(p)}p.st='idle';p.t=0;}";
s07 = s07.replace(targetLoopEnd, newLoopEnd);
fs.writeFileSync('public/js/07-update.js', s07);

// 10. Thiết kế lại Bầu trời, Cầu cảng và Bảng HUD Safe-Area + Đồng hồ đếm ngược 15 phút trong public/js/08-render.js
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

const targetLineDraw = "if(p.st==='reel'||p.st==='show'){const k=p.st==='show'?1:p.t/.8;bx=bx+(tipX-bx)*k;by=by+(tipY-80-by)*k}\n g.strokeStyle='#5b3a1a';g.lineWidth=5;g.beginPath();g.moveTo(x+10,y-30);g.quadraticCurveTo(x+32+bend*.3,y-54+bend*.9,tx,ty);g.stroke();\n if(p.st==='fall'){bx=tx;by=ty+30}   // dây đứt: chỉ còn đoạn lủng lẳng\n g.strokeStyle='#fffc';g.lineWidth=1.5;g.beginPath();g.moveTo(tx,ty);g.quadraticCurveTo((tx+bx)/2,Math.min(by,ty)+30,bx,by);g.stroke();\n if(p.st!=='show'){g.fillStyle=p.boost>0?'#ff7a18':'#f33';g.beginPath();g.arc(bx,by,7,0,7);g.fill()}";
const newLineDraw = "if(p.st==='reel'||p.st==='show'){const k=p.st==='show'?1:p.t/.8;bx=bx+(tipX-bx)*k;by=by+(tipY-80-by)*k}\n g.strokeStyle='#5b3a1a';g.lineWidth=5;g.beginPath();g.moveTo(x+10,y-30);g.quadraticCurveTo(x+32+bend*.3,y-54+bend*.9,tx,ty);g.stroke();\n if(p.st==='idle'){bx=tx;by=ty+15}else if(p.st==='fall'){bx=tx;by=ty+30}\n g.strokeStyle='#fffc';g.lineWidth=1.5;g.beginPath();g.moveTo(tx,ty);g.quadraticCurveTo((tx+bx)/2,p.st==='idle'?ty+20:Math.min(by,ty)+30,bx,by);g.stroke();\n if(p.st!=='show'&&p.st!=='idle'){g.fillStyle=p.boost>0?'#ff7a18':'#f33';g.beginPath();g.arc(bx,by,7,0,7);g.fill()}";
s08 = s08.replace(targetLineDraw, newLineDraw);

const newHud = `function hud(){
 const top=Object.values(scores).sort((a,b)=>b.kg-a.kg).slice(0,3);
 const mLeft = Math.floor(shiftTimer / 60), sLeft = Math.floor(shiftTimer % 60);
 const shiftStr = 'Ca ' + (mLeft<10?'0':'') + mLeft + ':' + (sLeft<10?'0':'') + sLeft;

 // Bảng Trái: TOP CẦN THỦ (X=135..530, Y=295..455)
 g.fillStyle='rgba(0,0,0,0.78)';g.strokeStyle='#ffd700';g.lineWidth=2.5;
 g.beginPath();g.roundRect(135,295,395,160,18);g.fill();g.stroke();
 txt('🏆 TOP CẦN THỦ (' + shiftStr + ')',332,328,19,'#ffd700','center');
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
 txt('🎁 Tặng Quà → Lên VIP 5 phút',568,442,17,'#ffd700','left');

 // Thanh Năng Lượng Bão Cá Vàng (đặt trên 2 bảng: X=135..945, Y=248..284)
 g.fillStyle='rgba(0,0,0,0.72)';g.beginPath();g.roundRect(135,248,810,36,18);g.fill();
 g.fillStyle=frenzy>0?'#ffd700':'#ff4d8d';
 g.beginPath();g.roundRect(139,252,Math.max(12,802*(frenzy>0?frenzy/GC.frenzySeconds:energy/100)),28,14);g.fill();
 txt(frenzy>0?'🌟 BÃO CÁ VÀNG '+Math.ceil(frenzy)+'s (x2 ĐIỂM)':'⚡ Năng lượng Bão Cá: '+Math.floor(energy)+'% (Thả tim + Bình luận)',540,272,18);

 if(banner.t>0){
   g.fillStyle='rgba(0,0,0,0.8)';g.beginPath();g.roundRect(160,520,760,54,16);g.fill();
   txt(banner.s,540,556,28,'#ffd700');
 }
 if(queue.length)txt('⏳ '+queue.length+' người đang chờ',935,535,18,'#fff','right');
}`;
s08 = s08.replace(/function hud\(\)\{[\s\S]*?function draw\(\)/, newHud + '\nfunction draw()');
fs.writeFileSync('public/js/08-render.js', s08);

// 11. XỬ LÝ CHAT CHUẨN XÁC: Gõ 'Câu' thả cần ngay lập tức và dọn dẹp người xem thoát live sau 10s không tương tác trong public/js/09-events.js
let s09 = fs.readFileSync('public/js/09-events.js', 'utf8');
const memberPatch = `
let lastJoinWelcome=0;
function touch(u){const id=u&&(u.id||u.name);if(!id)return;const gp=players.get(id);if(gp){gp.la=T;gp.idleAt=T;}}

const H_={
 member:u=>{
   const name = (u.name||'').slice(0, 7);
   if(Date.now()-lastJoinWelcome>12000&&!talking){
     lastJoinWelcome=Date.now();
     say('Chào ' + name + '! Gõ Câu để thả cần nhé!', false);
   }
 },
 chat:u=>{
   energyAdd(GC.chatEnergy);
   touch(u);
   const raw = String(u.comment || '').toLowerCase().trim();
   const isNew = !players.has(u.id||u.name);
   let p = null;
   const nn = norm(u.comment);
   if(nn.includes('cau') || nn.includes('tha') || raw.includes('câu') || raw.includes('🎣') || isNew){
     p = join(u);
     if(p){p.la = T;p.idleAt = T;LOG('💬 ' + (u.name||'?') + ' [' + raw.slice(0,20) + '] → ' + p.st + (p.again?' (xếp lượt)':''));}
   }
   if(isNew && p && Date.now()-lastJoinWelcome>8000){
     lastJoinWelcome=Date.now();
     say('Cần thủ ' + (u.name||'').slice(0, 7) + ' đã ra hồ!', false);
   }
   tugComment(u);
   if(raw.includes('nemdep') || raw.includes('ném dép')) throwSlip(u);
 },`;
s09 = s09.replace(/const H_=\{chat:u=>\{[^}]+\},/, memberPatch);
s09 = s09.replace('like:u=>{energyAdd', 'like:u=>{touch(u);energyAdd');
s09 = s09.replace('follow:u=>{join(u);', 'follow:u=>{join(u);touch(u);');
s09 = s09.replace('gift:u=>gift(u,u.coins,u.comment)', 'gift:u=>{touch(u);gift(u,u.coins,u.comment);touch(u)}');
fs.writeFileSync('public/js/09-events.js', s09);

// 12. Ẩn triệt để thanh Google Translate trong public/index.html
let idx = fs.readFileSync('public/index.html', 'utf8');
if (!idx.includes('notranslate')) {
  idx = idx.replace('<head>', '<head><meta name="google" content="notranslate">');
  fs.writeFileSync('public/index.html', idx);
}
// 13. HOTFIX: sửa triệt để SP.out kẹt giằng co, camera luôn zoom về, gõ "Câu" luôn câu tiếp, 10s không tương tác rời cầu
const must = (file, from, to) => { let s = fs.readFileSync(file, 'utf8'); if (!s.includes(from)) { console.error('❌ PATCH MISS ' + file + ': ' + from.slice(0, 60)); process.exitCode = 1; return; } s = s.split(from).join(to); fs.writeFileSync(file, s); };
must('public/js/07-update.js', "if(SP.p!==p){p.t=0;continue}", "if(SP.p!==p){p.st='reel';p.t=0;continue}");
must('public/js/07-update.js', "p.st=(GC.spotlight&&q.focus&&(q.tier==='legend'||(!SP.p&&T>=spotCool)))?'epic':'reel'", "p.st=(GC.spotlight&&q.focus&&!SP.p&&!SP.out&&(q.tier==='legend'||T>=spotCool))?'epic':'reel';if(p.st==='epic'&&!spotReq(p,'catch',q.tier==='legend')){p.st='reel'}");
must('public/js/07-update.js', "if(p.vip&&T>=p.vip){p.vip=0;const fs=[...Array(MAX).keys()].find(i=>!used().has(i));p.slot=fs!==undefined?fs:0;p.st='idle';}", "if(p.vip&&T>=p.vip&&SP.p!==p){p.vip=0;p.la=T;p.idleAt=T;const fs=[...Array(MAX).keys()].find(i=>!used().has(i));if(fs!==undefined){p.slot=fs;if(!['cast','wait','bite','reel','show'].includes(p.st))p.st='idle';}else{drop.push(p);continue;}}");
must('public/js/07-update.js', "fish.forEach(f=>{f.x+=f.v*dt;if(f.x>W+80)f.x=-80;if(f.x<-80)f.x=W+80});\n for(const p of players.values()){", "fish.forEach(f=>{f.x+=f.v*dt;if(f.x>W+80)f.x=-80;if(f.x<-80)f.x=W+80});\n const drop=[];\n for(const p of players.values()){\n if(!p.vip&&p.st==='idle'&&T-Math.max(p.la||0,p.idleAt||0)>=10){drop.push(p);continue}");
must('public/js/07-update.js', "else{p.loot=null;if(p.sp){p.sp=0;spotEnd(p)}p.st='idle';p.t=0;}}}", "else{p.loot=null;if(p.sp){p.sp=0;spotEnd(p)}if(p.again){p.again=0;p.st='cast';p.wait=R(1.5,3);SFX.cast()}else{p.st='idle';p.idleAt=T}p.t=0;}}}\n drop.forEach(leave);");
must('public/js/05b-comedy.js', "function tugFail(p){", "function tugFail(p){SP.out=true;SP.after=null;");
must('public/js/05a-spotlight.js', "if(SP.p&&!players.has(SP.p.id))SP.p=null;", "if(SP.p&&!players.has(SP.p.id)){SP.p=null;SP.out=false;}\n if(!SP.p)SP.out=false;");
must('public/js/05a-spotlight.js', "if(!SP.out&&(SP.t>30||", "if(!SP.out&&(SP.t>30||(SP.k==='catch'&&p.st!=='epic'&&p.st!=='show'&&p.st!=='fall')||");
must('public/js/05a-spotlight.js', "if(p&&SP.out&&cam.z<1.05){SP.p=null;spotCool=T+GC.spotCooldown;SP.after=null}", "if(p&&SP.out&&cam.z<1.05){SP.p=null;SP.out=false;spotCool=T+GC.spotCooldown;SP.after=null}");
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
