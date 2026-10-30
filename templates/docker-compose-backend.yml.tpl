# Renderizado pelo Terraform e enviado para /home/ubuntu/app/docker-compose.yml
# na instancia privada (web-server-01). As variaveis de ambiente vem do
# arquivo .env gerado a partir de var.backend_env.

services:
  kore-main:
    image: ${image_main}
    container_name: kore-main
    restart: unless-stopped
    env_file:
      - .env
      - aws.env
    ports:
      - "8080:8080"
    depends_on:
      database:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy

  kore-notification:
    image: ${image_notification}
    container_name: kore-notification
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "8081:8081"
    depends_on:
      database:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy

  database:
    image: mysql:9
    container_name: kore-database
    user: "0:0"
    restart: unless-stopped
    # Publicado apenas no loopback: acesso so via tunel SSH pelo bastion
    ports:
      - "127.0.0.1:3306:3306"
    command: --bind-address=0.0.0.0 --socket=/var/run/mysqld/mysqld.sock --default-time-zone=America/Sao_Paulo
    env_file:
      - .env
    tmpfs:
      - /var/run/mysqld
    volumes:
      - MYSQL_DATA:/var/lib/mysql:z
    healthcheck:
      test:
        [
          "CMD",
          "mysqladmin",
          "ping",
          "-h",
          "localhost",
          "-u",
          "root",
          "-p$$MYSQL_ROOT_PASSWORD",
        ]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  rabbitmq:
    image: rabbitmq:3-management
    container_name: kore-rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: ${rabbitmq_user}
      RABBITMQ_DEFAULT_PASS: ${rabbitmq_password}
    ports:
      - "5672:5672"
      - "15672:15672"
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "status"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  MYSQL_DATA:
