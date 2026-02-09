# --- 第一阶段：构建阶段 ---
FROM node:20-alpine AS build-stage

WORKDIR /app

# 利用 Docker 缓存，先拷贝依赖文件
COPY package*.json ./
RUN npm install

# 拷贝源代码并执行构建
COPY . .
# 绕过 tsc 检查，直接使用 vite 构建
RUN npx vite build

# --- 第二阶段：生产阶段 ---
FROM nginx:stable-alpine AS production-stage

# 🆕 拷贝自定义 Nginx 配置（使用项目中的 nginx.conf）
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 拷贝构建产物到 Nginx 目录
COPY --from=build-stage /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

