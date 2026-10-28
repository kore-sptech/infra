# ==========================================
# NETWORK ACL - SUBNET PUBLICA (PROXY)
# NACLs sao stateless: cada fluxo exige regra de ida e de volta.
# ==========================================
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id

  # ---------- INBOUND ----------
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidr_block = var.ssh_admin_cidr
  }

  # Portas efemeras: respostas da internet e do backend privado
  ingress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 140
    action     = "allow"
    protocol   = "icmp"
    from_port  = -1
    to_port    = -1
    icmp_type  = -1
    icmp_code  = -1
    cidr_block = var.vpc_cidr
  }

  # ---------- OUTBOUND ----------
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 8080
    to_port    = 8081
    cidr_block = var.private_subnet_cidr
  }

  egress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    from_port  = 15672
    to_port    = 15672
    cidr_block = var.private_subnet_cidr
  }

  egress {
    rule_no    = 140
    action     = "allow"
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidr_block = var.private_subnet_cidr
  }

  # Respostas aos clientes HTTP/HTTPS e conexoes de saida
  egress {
    rule_no    = 150
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 160
    action     = "allow"
    protocol   = "icmp"
    from_port  = -1
    to_port    = -1
    icmp_type  = -1
    icmp_code  = -1
    cidr_block = var.vpc_cidr
  }

  tags = {
    Name = "${var.project_name}-public-nacl"
  }
}

resource "aws_network_acl_association" "public" {
  network_acl_id = aws_network_acl.public.id
  subnet_id      = aws_subnet.public.id
}

# ==========================================
# NETWORK ACL - SUBNET PRIVADA (BACKEND / RABBITMQ)
# ==========================================
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id

  # ---------- INBOUND ----------
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 8080
    to_port    = 8081
    cidr_block = var.public_subnet_cidr
  }

  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 15672
    to_port    = 15672
    cidr_block = var.public_subnet_cidr
  }

  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidr_block = var.public_subnet_cidr
  }

  ingress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    from_port  = 5672
    to_port    = 5672
    cidr_block = var.vpc_cidr
  }

  ingress {
    rule_no    = 140
    action     = "allow"
    protocol   = "icmp"
    from_port  = -1
    to_port    = -1
    icmp_type  = -1
    icmp_code  = -1
    cidr_block = var.vpc_cidr
  }

  # Retorno do trafego de saida que passa pelo NAT Gateway (docker pull, yum)
  ingress {
    rule_no    = 150
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  # ---------- OUTBOUND ----------
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 5672
    to_port    = 5672
    cidr_block = var.vpc_cidr
  }

  egress {
    rule_no    = 130
    action     = "allow"
    protocol   = "icmp"
    from_port  = -1
    to_port    = -1
    icmp_type  = -1
    icmp_code  = -1
    cidr_block = var.vpc_cidr
  }

  # Respostas ao proxy e as conexoes iniciadas pela instancia
  egress {
    rule_no    = 140
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "${var.project_name}-private-nacl"
  }
}

resource "aws_network_acl_association" "private" {
  network_acl_id = aws_network_acl.private.id
  subnet_id      = aws_subnet.private.id
}
