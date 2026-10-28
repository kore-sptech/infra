# ==========================================
# S3 - BUCKET DE FOTOS DO PROJETO
# Upload/delete: somente a instancia privada (via credenciais do backend)
# Leitura: publica, para o frontend exibir as imagens direto pela URL
# ==========================================
data "aws_caller_identity" "current" {}

locals {
  # Nome de bucket precisa ser unico globalmente; o account id garante isso
  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.project_name}-fotos-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "fotos" {
  bucket = local.s3_bucket_name

  tags = {
    Name = "${var.project_name}-fotos"
  }
}

# Equivale a desmarcar "Block all public access" no console
resource "aws_s3_bucket_public_access_block" "fotos" {
  bucket = aws_s3_bucket.fotos.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Sem ACLs por objeto: o acesso publico vem exclusivamente da bucket policy
resource "aws_s3_bucket_ownership_controls" "fotos" {
  bucket = aws_s3_bucket.fotos.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "fotos" {
  bucket = aws_s3_bucket.fotos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.fotos.arn}/*"
      }
    ]
  })

  # A policy publica so e aceita depois que o bloqueio de acesso publico cai
  depends_on = [aws_s3_bucket_public_access_block.fotos]
}

# Permite que o navegador carregue as imagens via fetch/XHR a partir do proxy
resource "aws_s3_bucket_cors_configuration" "fotos" {
  bucket = aws_s3_bucket.fotos.id

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}
