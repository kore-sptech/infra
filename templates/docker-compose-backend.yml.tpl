version: '3.8'

services:
  # RabbitMQ com interface de gerenciamento ativada
  rabbitmq:
    image: rabbitmq:3-management
    container_name: kore-rabbitmq
    restart: always
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    ports:
      - "5672:5672"
      - "15672:15672"

  # Mock de inicializacao para responder /api/health na porta 8080
  # Substitua pela imagem do seu Spring Boot quando fizer o deploy
  api-service:
    image: hashicorp/http-echo:latest
    container_name: kore-backend-health
    restart: always
    command: ["-text", "{\"status\":\"UP\",\"service\":\"backend-web-server-01\",\"layer\":\"private-subnet-10.0.2.0/24\",\"message\":\"Backend Java Spring Boot pronto para ser implantado!\"}"]
    ports:
      - "8080:5678"
