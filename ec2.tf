# ==========================================
# EC2: WEB-SERVER-01 (BACKEND / PRIVADO)
# ==========================================
locals {
  # Vai para um arquivo separado do .env, montado so no container kore-main
  backend_aws_env = merge(
    {
      AWS_S3_BUCKET_NAME     = local.s3_bucket_id
      AWS_S3_REGION          = var.aws_region
      AWS_S3_PUBLIC_BASE_URL = "https://${local.s3_bucket_id}.s3.${var.aws_region}.amazonaws.com"
    },
    # Chaves estaticas so entram se preenchidas; vazias = SDK usa o instance profile
    { for k, v in {
      AWS_ACCESS_KEY_ID     = var.backend_aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.backend_aws_secret_access_key
      AWS_SESSION_TOKEN     = var.backend_aws_session_token
      } : k => v if v != ""
    }
  )
}

resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_backend
  subnet_id     = aws_subnet.private.id
  key_name      = var.key_name

  iam_instance_profile = var.backend_instance_profile != "" ? var.backend_instance_profile : null

  # Hop limit 2: sem isso os containers Docker nao alcancam o IMDS e perdem a role
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

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
    backend_env_file     = join("\n", [for k, v in var.backend_env : "${k}=${v}"])
    backend_aws_env_file = join("\n", [for k, v in local.backend_aws_env : "${k}=${v}"])
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
      frontend_port_2    = var.frontend_port_2
    }),
    proxy_docker_compose = templatefile("${path.module}/templates/docker-compose-proxy.yml.tpl", {
      image_frontend   = var.image_frontend
      image_frontend_2 = var.image_frontend_2
      frontend_port    = var.frontend_port
      frontend_port_2  = var.frontend_port_2
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
