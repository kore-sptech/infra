# ==========================================
# EC2: WEB-SERVER-01 (BACKEND / PRIVADO)
# ==========================================
resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_backend
  subnet_id     = aws_subnet.private.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.backend.id]

  # AWS Academy so permite gp2 e volumes de ate 30 GB
  root_block_device {
    volume_size           = var.root_volume_size_backend
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data_backend.sh.tpl", {
    backend_docker_compose = templatefile("${path.module}/templates/docker-compose-backend.yml.tpl", {
      image_main         = var.image_main
      image_notification = var.image_notification
      rabbitmq_user      = var.rabbitmq_user
      rabbitmq_password  = var.rabbitmq_password
    }),
    backend_env_file = join("\n", [for k, v in var.backend_env : "${k}=${v}"])
  })

  # Garante que o NAT Gateway esteja pronto para a instancia conseguir acessar a internet
  depends_on = [
    aws_nat_gateway.nat,
    aws_route_table_association.private
  ]

  tags = {
    Name = "${var.project_name}-web-server-01"
    Role = "Backend-Private"
  }
}

# ==========================================
# EC2: PROXY-SERVER-01 (PROXY / PUBLICO)
# ==========================================
resource "aws_instance" "proxy" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_proxy
  subnet_id                   = aws_subnet.public.id
  key_name                    = var.key_name
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.proxy.id]

  root_block_device {
    volume_size           = var.root_volume_size_proxy
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data_proxy.sh.tpl", {
    nginx_config = templatefile("${path.module}/templates/nginx.conf.tpl", {
      backend_private_ip = aws_instance.backend.private_ip
      frontend_port      = var.frontend_port
    }),
    proxy_docker_compose = templatefile("${path.module}/templates/docker-compose-proxy.yml.tpl", {
      image_frontend = var.image_frontend
      frontend_port  = var.frontend_port
    }),
    backend_private_ip = aws_instance.backend.private_ip
  })

  depends_on = [
    aws_internet_gateway.igw,
    aws_route_table_association.public,
    aws_instance.backend
  ]

  tags = {
    Name = "${var.project_name}-proxy-server-01"
    Role = "Reverse-Proxy-Frontend"
  }
}
