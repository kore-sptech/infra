# 🚀 Projeto Kore - Automação de Infraestrutura AWS (Academy / Learner Lab)

Automação completa via **Terraform** e **Shell Script** para provisionar a arquitetura com **camada pública (Proxy Nginx + Front React)** e **camada privada (Backend Java Spring Boot + RabbitMQ)**, com saída para internet via **NAT Gateway**.

---

## 📐 Arquitetura

```
+-----------------------------------------------------------------------------------+
| AWS Cloud (us-east-1)                                                             |
| VPC (10.0.0.0/22)                                                                 |
|                                                                                   |
|  [ Internet Gateway ]                                                             |
|           ▲                                                                       |
|           │                                                                       |
|  +--------┴--------------------------------------------------------------------+  |
|  | Public Subnet (10.0.1.0/24)                                                 |  |
|  |                                                                             |  |
|  |  • NAT Gateway (com Elastic IP) ◄─────────────────────┐                     |  |
|  |  • proxy-server-01 (Ubuntu 22.04 LTS)                 │ (Saída p/ internet) |  |
|  |    - IP Público associado                             │                     |  |
|  |    - Nginx: Reverse Proxy & Load Balancer             │                     |  |
|  |    - Servindo o Frontend (React)                      │                     |  |
|  |    - Roteando /api/* para a Subnet Privada            │                     |  |
|  +-------------------------------------------------------│---------------------+  |
|                                                          │                        |
|  +-------------------------------------------------------│---------------------+  |
|  | Private Subnet (10.0.2.0/24)                          │                        |
|  |                                                       │                        |
|  |  • web-server-01 (Ubuntu 22.04 LTS)                   │                        |
|  |    - Sem IP público (isolamento total)                │                        |
|  |    - Java Spring Boot (Porta 8080)                    │                        |
|  |    - RabbitMQ (Portas 5672 e 15672)                   │                        |
|  |    - Comunica com a internet exclusivamente via NAT ──┘                        |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## ⚡ Guia Rápido de Uso

O script [`infra.sh`](file:///home/vitorrestini/Documentos/SpTech/projetoKore/infra/infra.sh) centraliza todo o gerenciamento da infraestrutura.

### 1. Inserir ou atualizar credenciais da AWS Academy

No painel do AWS Academy Learner Lab:
1. Clique em **AWS Details** > **AWS CLI** > clique em **Show**.
2. Copie o bloco de texto exibido.
3. No seu terminal, execute:

```bash
./infra.sh creds
```

Cole o texto e aperte `Enter` e depois `Ctrl+D`. O script configurará tudo automaticamente.

---

### 2. Subir toda a infraestrutura

```bash
./infra.sh up
```

O Terraform criará:
* VPC, Subnets (Pública e Privada), Internet Gateway e NAT Gateway.
* Security Groups restritivos (o Backend só aceita conexões do Proxy).
* As instâncias EC2, instalando Docker, Nginx e configurando o proxy reverso automaticamente.

No final, você receberá a saída com o **IP Público**, **URL do Frontend**, **URL da API** e os comandos SSH.

---

### 3. Verificar status e IPs

A qualquer momento, para rever os IPs da sua infra:

```bash
./infra.sh status
```

---

### 4. Acessar os servidores via SSH

Coloque sua chave privada `labsuser.pem` (ou `vockey.pem`) dentro desta pasta (`infra/`):

* **Acessar o Proxy público:**
  ```bash
  ./infra.sh ssh-proxy
  ```

* **Acessar o Backend privado:**
  Como a máquina do backend não tem IP público, o comando usa o Proxy automaticamente como **Bastion / Jump Host**:
  ```bash
  ./infra.sh ssh-backend
  ```

---

### 5. Destruir tudo (Economizar créditos!)

Quando terminar os testes ou estudos do dia, **destrua os recursos com 1 comando** para não queimar os créditos do laboratório (especialmente o NAT Gateway):

```bash
./infra.sh down
```

---

## 🔄 Mudou de conta de estudante? (Acabaram os créditos)

Quando os créditos de uma conta acabarem e você for para outra conta:

1. Limpe o estado anterior:
   ```bash
   ./infra.sh reset-state
   ```
2. Cole as credenciais da **nova conta**:
   ```bash
   ./infra.sh creds
   ```
3. Suba tudo novamente na nova conta:
   ```bash
   ./infra.sh up
   ```

O script criará tudo do zero na nova conta e imprimirá o novo IP público gerado!

---

## 📦 Como rodar suas aplicações (React, Spring Boot e RabbitMQ)

### Backend (Java Spring Boot + RabbitMQ)
Na máquina privada, o `docker-compose` já é pré-configurado pelo script em `/home/ubuntu/app/docker-compose.yml`.
1. Conecte no backend via: `./infra.sh ssh-backend`
2. Edite `/home/ubuntu/app/docker-compose.yml` para colocar a imagem Docker do seu Spring Boot.
3. Suba com: `docker compose up -d`.

### Frontend (React)
Na máquina pública do proxy:
1. O Nginx já está configurado para servir qualquer arquivo estático colocado em `/var/www/html`.
2. Se você rodar o build do React (`npm run build`), basta copiar os arquivos da pasta `dist`/`build` para `/var/www/html` do proxy.
3. As requisições que o React fizer para `/api/*` serão automaticamente encaminhadas pelo Nginx para o Spring Boot privado na porta 8080!
# infra
