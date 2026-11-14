FROM node:20-bullseye

# Cài đặt FFmpeg, Chromium, Xvfb và cấu hình múi giờ Việt Nam
RUN apt-get update && apt-get install -y \
    ffmpeg \
    xvfb \
    chromium \
    curl \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Ho_Chi_Minh
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY . .

RUN chmod +x start_schedule.sh

EXPOSE 3000

CMD ["./start_schedule.sh"]
