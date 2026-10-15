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

output "url_api_health" {
  description = "URL publica para testar a comunicacao com o Backend na subnet privada"
  value       = "http://${aws_instance.proxy.public_ip}/api/health"
}

output "url_rabbitmq_management" {
  description = "URL para acessar o painel do RabbitMQ via proxy"
  value       = "http://${aws_instance.proxy.public_ip}/rabbitmq/"
}

output "ssh_command_proxy" {
  description = "Comando para conectar via SSH no Proxy (coloque seu labsuser.pem ou vockey.pem)"
  value       = "ssh -i labsuser.pem ubuntu@${aws_instance.proxy.public_ip}"
}

output "ssh_command_backend_bastion" {
  description = "Comando para conectar via SSH direto no Backend privado usando o Proxy como Bastion"
  value       = "ssh -i labsuser.pem -J ubuntu@${aws_instance.proxy.public_ip} ubuntu@${aws_instance.backend.private_ip}"
}
