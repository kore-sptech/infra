# ==========================================
# SECURITY GROUP - PROXY (PUBLIC SUBNET)
# ==========================================
resource "aws_security_group" "proxy" {
  name        = "${var.project_name}-proxy-sg"
  description = "Permite trafego publico HTTP/HTTPS e SSH para o proxy"
  vpc_id      = aws_vpc.main.id

  # Porta 80 - HTTP (Acesso Web publico)
  ingress {
    description = "HTTP Publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta 443 - HTTPS
  ingress {
    description = "HTTPS Publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta 22 - SSH para administracao
  ingress {
    description = "SSH de qualquer lugar"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Saida liberada para toda internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-proxy-sg"
  }
}

# ==========================================
# SECURITY GROUP - BACKEND (PRIVATE SUBNET)
# ==========================================
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Permite comunicacao apenas a partir do Proxy e rede interna"
  vpc_id      = aws_vpc.main.id

  # Spring Boot (Porta 8080) vindo do Proxy
  ingress {
    description     = "Spring Boot API vindo do Proxy"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
  }

  # Microservico de notificacao (Porta 8081) vindo do Proxy
  ingress {
    description     = "Microservico de notificacao vindo do Proxy"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
  }

  # RabbitMQ Management Dashboard (Porta 15672) vindo do Proxy
  ingress {
    description     = "RabbitMQ Web UI vindo do Proxy"
    from_port       = 15672
    to_port         = 15672
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
  }

  # RabbitMQ AMQP (Porta 5672) vindo da VPC interna
  ingress {
    description = "RabbitMQ AMQP interno"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH (Porta 22) apenas a partir do Proxy (Bastion Jump Host)
  ingress {
    description     = "SSH apenas a partir da instancia Proxy"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
  }

  # Ping / ICMP interno para testes de rede
  ingress {
    description = "ICMP Ping interno"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Saida liberada (via NAT Gateway) para baixar imagens Docker e pacotes
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}
