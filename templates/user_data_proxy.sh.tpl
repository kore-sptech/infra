#!/bin/bash
set -e

# Atualizacao do sistema e instalacao do Nginx e utilitarios
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release nginx jq

# Instalacao do Docker e Docker Compose
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu

# Aplicar configuracao do Nginx
cat << 'EOF' > /etc/nginx/nginx.conf
${nginx_config}
EOF

# Criar pagina inicial do Frontend React / Status Dashboard
cat << 'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Projeto Kore - Infraestrutura AWS</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', sans-serif; }
    body { background: #0f172a; color: #f8fafc; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 20px; }
    .card { background: #1e293b; border: 1px solid #334155; border-radius: 16px; padding: 32px; max-width: 700px; width: 100%; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5); }
    h1 { font-size: 24px; color: #38bdf8; margin-bottom: 8px; display: flex; align-items: center; gap: 8px; }
    p.subtitle { color: #94a3b8; font-size: 14px; margin-bottom: 24px; }
    .status-badge { display: inline-flex; align-items: center; background: rgba(34, 197, 94, 0.15); color: #4ade80; border: 1px solid rgba(34, 197, 94, 0.3); padding: 4px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; margin-bottom: 20px; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 24px; }
    .box { background: #0f172a; border: 1px solid #334155; border-radius: 10px; padding: 16px; }
    .box-title { font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: #64748b; margin-bottom: 6px; font-weight: 600; }
    .box-value { font-size: 14px; color: #f1f5f9; font-weight: 500; font-family: monospace; }
    .actions { display: flex; flex-wrap: wrap; gap: 12px; }
    a.btn { background: #0284c7; color: #fff; text-decoration: none; padding: 10px 16px; border-radius: 8px; font-size: 13px; font-weight: 600; transition: background 0.2s; display: inline-flex; align-items: center; }
    a.btn:hover { background: #0369a1; }
    a.btn-secondary { background: #334155; color: #e2e8f0; }
    a.btn-secondary:hover { background: #475569; }
    .footer { margin-top: 24px; padding-top: 16px; border-top: 1px solid #334155; font-size: 12px; color: #64748b; text-align: center; }
  </style>
</head>
<body>
  <div class="card">
    <div class="status-badge">● Infraestrutura Operacional</div>
    <h1>Projeto Kore &bull; AWS Cloud</h1>
    <p class="subtitle">Proxy Reverso Nginx + Load Balancer + Camada Privada (Backend & RabbitMQ)</p>

    <div class="grid">
      <div class="box">
        <div class="box-title">Camada Pública (Proxy / Front)</div>
        <div class="box-value">Subnet: 10.0.1.0/24 (EC2 Pública)</div>
      </div>
      <div class="box">
        <div class="box-title">Camada Privada (Backend / Fila)</div>
        <div class="box-value">Subnet: 10.0.2.0/24 (EC2 Privada)</div>
      </div>
      <div class="box">
        <div class="box-title">IP Privado do Backend</div>
        <div class="box-value">${backend_private_ip}:8080</div>
      </div>
      <div class="box">
        <div class="box-title">RabbitMQ Interno</div>
        <div class="box-value">${backend_private_ip}:5672</div>
      </div>
    </div>

    <div class="actions">
      <a class="btn" href="/health" target="_blank">Testar /health (Proxy)</a>
      <a class="btn" href="/api/health" target="_blank">Testar /api/health (Backend)</a>
      <a class="btn btn-secondary" href="/rabbitmq/" target="_blank">RabbitMQ Web UI</a>
    </div>

    <div class="footer">
      Gerenciado com Terraform &bull; AWS Academy Learner Lab &bull; Pronto para seus containers React e Spring Boot
    </div>
  </div>
</body>
</html>
EOF

# Testar e reiniciar o Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "Proxy configurado com sucesso!" > /tmp/user_data_finished.log
