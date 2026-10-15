user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    # Balanceamento de carga para o Backend Spring Boot (Privado)
    upstream backend_pool {
        server ${backend_private_ip}:8080 max_fails=3 fail_timeout=10s;
        # Para adicionar mais réplicas no futuro:
        # server 10.0.2.X:8080;
    }

    server {
        listen 80 default_server;
        listen [::]:80 default_server;

        server_name _;

        # Healthcheck do proprio Proxy
        location /health {
            default_type application/json;
            return 200 '{"status": "UP", "service": "proxy-server-01", "role": "Reverse Proxy & Load Balancer"}\n';
        }

        # Roteamento para a API Backend (Spring Boot na Subnet Privada)
        location /api/ {
            proxy_pass http://backend_pool;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 5s;
            proxy_read_timeout 60s;
        }

        # Roteamento para o RabbitMQ Web UI (na Subnet Privada)
        location /rabbitmq/ {
            proxy_pass http://${backend_private_ip}:15672/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Frontend (React)
        # Servindo arquivos estaticos do build do React em /var/www/html
        # Ou se preferir rodar container Docker do React na porta 3000:
        # proxy_pass http://127.0.0.1:3000;
        location / {
            root /var/www/html;
            index index.html index.htm;
            try_files $uri $uri/ /index.html;
        }
    }
}
