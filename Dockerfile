FROM nginx:alpine

# 复制 Godot Web 导出产物（HTML + JS + WASM + PCK）
COPY build/web/ /usr/share/nginx/html/

# 复制 nginx 配置（含 COOP/COEP 跨域隔离头，Godot 4 多线程必需）
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
