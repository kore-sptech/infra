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
        keepalive 32;
        # Para adicionar mais réplicas no futuro:
        # server 10.0.2.X:8080;
    }

    # Microservico de notificacao (Privado)
    upstream notification_pool {
        server ${backend_private_ip}:8081 max_fails=3 fail_timeout=10s;
        keepalive 32;
    }

    # Containers do frontend React (latest e v1) na propria instancia publica
    # Round-robin padrao: as requisicoes alternam entre frontend-1 e frontend-2
    upstream frontend_pool {
        server 127.0.0.1:${frontend_port} max_fails=3 fail_timeout=10s;
        server 127.0.0.1:${frontend_port_2} max_fails=3 fail_timeout=10s;
        keepalive 32;
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

        # API principal: /api/auth/login -> kore-main:8080/auth/login (sem CORS)
        location /api/ {
            proxy_pass http://backend_pool/;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 5s;

            # Necessario para o SSE (/sse/stream)
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 1h;
            client_max_body_size 20m;
        }

        # Microservico de notificacao: /notification/... -> kore-notification:8081/...
        location /notification/ {
            proxy_pass http://notification_pool/;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_buffering off;
            proxy_read_timeout 1h;
        }

        # Roteamento para o RabbitMQ Web UI (na Subnet Privada)
        location /rabbitmq/ {
            proxy_pass http://${backend_private_ip}:15672/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Frontend (React) rodando como container Docker nesta instancia
        location / {
            proxy_pass http://frontend_pool;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Fallback estatico enquanto o container sobe
            proxy_intercept_errors on;
            error_page 502 503 504 = @fallback;
        }

        location @fallback {
            root /var/www/html;
            try_files /index.html =503;
        }
    }
}
