FROM node:20-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    xvfb \
    chromium \
    curl \
    git \
    tzdata \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Ho_Chi_Minh
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

# Tải toàn bộ mã nguồn Chùa gốc có đầy đủ 100% hình ảnh và thư mục public
RUN git clone --depth=1 https://github.com/zane-tv/tiktok-live-temple-rpc.git .

RUN npm install --omit=dev

# Copy script chạy tự động của chúng ta vào
COPY start_schedule.sh ./start_schedule.sh
RUN chmod +x start_schedule.sh

EXPOSE 3000

CMD ["./start_schedule.sh"]
