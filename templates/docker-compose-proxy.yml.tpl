# Renderizado pelo Terraform e enviado para /home/ubuntu/app/docker-compose.yml
# na instancia publica (proxy-server-01). O Nginx roda no host e faz o
# roteamento para este container e para a instancia privada.

services:
  frontend-1:
    image: ${image_frontend}
    container_name: frontend-1
    restart: always
    ports:
      - "127.0.0.1:${frontend_port}:80"
