FROM node:20-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    xvfb \
    chromium \
    pulseaudio \
    pulseaudio-utils \
    curl \
    git \
    tzdata \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Ho_Chi_Minh
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

# Tải toàn bộ mã nguồn game Câu Cá TikTok của khiem-tv
RUN git clone --depth=1 https://github.com/khiem-tv/tiktok-fishing.git .

RUN npm install --omit=dev

COPY start_schedule.sh ./start_schedule.sh
RUN chmod +x start_schedule.sh

EXPOSE 3000

CMD ["./start_schedule.sh"]
