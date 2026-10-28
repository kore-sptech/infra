output "proxy_public_ip" {
  description = "IP Publico da instancia Proxy / Frontend"
  value       = aws_instance.proxy.public_ip
}

output "proxy_public_dns" {
  description = "DNS Publico da instancia Proxy"
  value       = aws_instance.proxy.public_dns
}

output "backend_private_ip" {
  description = "IP Privado da instancia Backend / RabbitMQ"
  value       = aws_instance.backend.private_ip
}

output "url_frontend" {
  description = "URL publica para acessar a aplicacao"
  value       = "http://${aws_instance.proxy.public_ip}"
}

output "url_api" {
  description = "Base da API principal (o prefixo /api e removido antes de chegar no kore-main:8080)"
  value       = "http://${aws_instance.proxy.public_ip}/api/"
}

output "url_notification" {
  description = "Base do microservico de notificacao (prefixo /notification -> kore-notification:8081)"
  value       = "http://${aws_instance.proxy.public_ip}/notification/"
}

output "url_rabbitmq_management" {
  description = "URL para acessar o painel do RabbitMQ via proxy"
  value       = "http://${aws_instance.proxy.public_ip}/rabbitmq/"
}

output "s3_bucket_name" {
  description = "Nome do bucket de fotos usado pelo backend"
  value       = local.s3_bucket_id
}

output "s3_public_base_url" {
  description = "URL base publica dos objetos do bucket (AWS_S3_PUBLIC_BASE_URL)"
  value       = "https://${local.s3_bucket_id}.s3.${var.aws_region}.amazonaws.com"
}

output "ssh_command_proxy" {
  description = "Comando para conectar via SSH no Proxy (coloque seu labsuser.pem ou vockey.pem)"
  value       = "ssh -i labsuser.pem ubuntu@${aws_instance.proxy.public_ip}"
}

output "ssh_command_backend_bastion" {
  description = "Comando para conectar via SSH direto no Backend privado usando o Proxy como Bastion"
  value       = "ssh -i labsuser.pem -J ubuntu@${aws_instance.proxy.public_ip} ubuntu@${aws_instance.backend.private_ip}"
}
