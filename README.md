# CI/CD Lab

Laboratório pessoal de CI/CD desenvolvido para estudar e implementar um fluxo automatizado de integração, publicação e deploy de aplicações utilizando GitHub Actions, Docker, Docker Compose e um self-hosted runner.

O projeto simula um ambiente de produção local, executando os serviços em uma máquina Debian e automatizando o processo de atualização da aplicação a partir de alterações enviadas ao GitHub.

Um dos principais objetivos é implementar um mecanismo de rollback automático: caso uma nova versão da aplicação não passe no health check após o deploy, a versão anterior é restaurada.

## Objetivos

- Implementar pipelines de CI/CD com GitHub Actions.
- Separar aplicação e infraestrutura em repositórios independentes.
- Automatizar a construção e publicação de imagens Docker no GitHub Container Registry (GHCR).
- Automatizar o deploy utilizando um self-hosted runner.
- Gerenciar serviços e dependências com Docker Compose.
- Configurar Nginx como reverse proxy.
- Implementar health checks para monitoramento da aplicação.
- Implementar rollback automático em caso de falha no deploy.
- Automatizar backups do PostgreSQL.
- Implementar limpeza automática de backups antigos.
- Registrar operações de deploy em arquivos de log.

## Arquitetura

O projeto está organizado em dois repositórios principais:

| Repositório | Responsabilidade |
|---|---|
| `lab-backend` | Código-fonte da API, testes, build e publicação da imagem Docker. |
| `lab-infra` | Orquestração dos containers, configuração do Nginx, deploy, rollback e backups. |

O frontend é uma aplicação HTML estática, mantida diretamente no repositório de infraestrutura e servida por um container Nginx.

### Fluxo de CI/CD

Quando um commit é enviado para a branch `master` do backend, o GitHub Actions inicia o pipeline.

```text
                  GITHUB
                     |
                     |
             Push na branch master
                     |
                     v
             +---------------+
             |  lab-backend  |
             +---------------+
                     |
                     v
             GitHub Actions
                     |
                     v
             Instala dependências
                     |
                     v
                Typecheck
                     |
                     v
                  Tests
                     |
                     v
                  Build
                     |
                     v
             Build Docker Image
                     |
                     v
              Push para GHCR
                     |
                     v
           repository_dispatch
                     |
                     v
             +---------------+
             |   lab-infra   |
             +---------------+
                     |
                     v
             GitHub Actions
                     |
                     v
           Self-hosted Runner
              (Debian local)
                     |
                     v
              deploy.sh
                     |
                     v
           Docker Compose Pull
                     |
                     v
           Docker Compose Up
                     |
                     v
               Health Check
                     |
             +-------+-------+
             |               |
           Healthy         Unhealthy
             |               |
             v               v
          Deploy OK        Rollback
                             |
                             v
                      Versão anterior
                             |
                             v
                        Health Check
```

### Componentes

| Tecnologia | Responsabilidade |
|---|---|
| Node.js | Runtime do backend. |
| Express | Framework HTTP da API. |
| TypeScript | Tipagem estática do backend. |
| PostgreSQL | Banco de dados relacional. |
| React | Não utilizado neste laboratório; o frontend é estático. |
| Nginx | Servidor do frontend e reverse proxy para a API. |
| Docker | Containerização dos serviços. |
| Docker Compose | Orquestração local dos containers. |
| GitHub Actions | Execução dos pipelines de CI/CD. |
| GHCR | Armazenamento das imagens Docker. |
| Self-hosted Runner | Execução dos jobs de deploy na máquina Debian. |
| Bash | Automação de deploy, rollback e backups. |

## Estrutura dos repositórios

### lab-backend

Responsável pelo código-fonte da API e pelo pipeline de integração contínua e publicação.

Estrutura simplificada:

```text
lab-backend/
├── .github/
│   └── workflows/
│       └── ...
├── src/
│   ├── app.ts
│   └── server.ts
├── Dockerfile
├── package.json
├── package-lock.json
└── tsconfig.json
```

A API possui endpoints básicos:

| Endpoint | Descrição |
|---|---|
| `GET /` | Retorna uma mensagem de identificação da API. |
| `GET /health` | Endpoint utilizado para verificar a saúde da aplicação. |

O endpoint `/health` retorna HTTP 200 quando a aplicação está saudável.

### lab-infra

Responsável pela infraestrutura e automações de deploy.

```text
lab-infra/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── docker/
│   ├── nginx/
│   │   └── conf.d/
│   │       └── default.conf
│   └── frontend/
│       └── html/
│           └── index.html
├── scripts/
│   ├── backup.sh
│   ├── cleanup-backups.sh
│   └── deploy.sh
├── backups/
├── logs/
├── compose.yaml
├── .env
├── .env.example
├── .gitignore
└── README.md
```

O arquivo `.env` contém as configurações locais e credenciais necessárias para a execução dos serviços. Ele não é versionado.

As pastas `backups/` e `logs/` também são ignoradas pelo Git.

## Infraestrutura Docker

O Docker Compose gerencia os seguintes serviços:

| Serviço | Responsabilidade |
|---|---|
| `nginx` | Ponto de entrada HTTP da aplicação. |
| `frontend` | Servir o HTML estático. |
| `backend` | Executar a API Express. |
| `postgres` | Banco de dados PostgreSQL. |
| `backup` | Executar backups periódicos do banco. |
| `cleanup` | Remover backups antigos conforme a política de retenção. |

Os serviços se comunicam por meio da rede interna criada pelo Docker Compose.

O Nginx expõe a aplicação na porta configurada em `NGINX_PORT`, atualmente `8080`.

### Reverse Proxy

O Nginx direciona as requisições de acordo com o caminho solicitado.

- `/api/` é encaminhado para o backend.
- Os demais caminhos são encaminhados para o frontend.

## Pipeline do backend

O workflow do backend é responsável por executar as etapas de integração contínua e publicação.

Ele é acionado por:

- Push na branch `master`.
- Push de tags iniciadas por `v`.
- Pull requests direcionados à branch `master`.

### Etapas do pipeline

1. Checkout do código.
2. Configuração do Node.js 22.
3. Instalação das dependências.
4. Typecheck.
5. Execução dos testes.
6. Build do projeto.
7. Construção da imagem Docker.
8. Publicação da imagem no GHCR.
9. **Envio de um evento para o repositório de infraestrutura.**


### Versionamento das imagens

As imagens são versionadas utilizando o SHA do commit que originou o build. Dessa forma, cada imagem publicada possui uma identificação única vinculada a uma versão específica do código-fonte.

Exemplo:

```text
ghcr.io/elenndev/lab-backend:sha-9791f2a
```
Essa estratégia facilita o rastreamento das versões implantadas, permitindo identificar qual commit está sendo executado no ambiente, assim é possível consultar a imagem atualmente utilizada pelo container com:

```bash
docker inspect lab-backend \
  --format '{{.Config.Image}}'
```

O comando retorna o nome completo da imagem, incluindo a tag com o SHA do commit (Ex: `ghcr.io/elenndev/lab-backend:sha-8b1bd11`), permitindo verificar exatamente qual versão do backend está em execução.

Também facilita a implementação do rollback, pois o deploy pode restaurar uma imagem anterior sem precisar reconstruir o código.

### Comunicação entre repositórios

Após publicar a imagem, o workflow do backend envia um evento `repository_dispatch` para o repositório `lab-infra`.

O evento utiliza o tipo:

```yaml
repository_dispatch:
  types: [backend-image-published]
```

A imagem publicada é enviada no campo `client_payload.image`.

O workflow de infraestrutura recebe esse evento e utiliza o nome da imagem para iniciar o deploy.

## Self-hosted Runner

O deploy é executado por um GitHub Actions Runner instalado diretamente na máquina Debian.

O GitHub encaminha o job para uma máquina registrada como runner self-hosted, em vez de utilizar um runner hospedado pelo próprio GitHub.

O runner possui acesso ao Docker instalado na máquina e consegue executar os comandos de deploy diretamente no ambiente local.

O diretório do projeto de infraestrutura é configurado no GitHub por meio da variável `LAB_INFRA_DIR`.

O runner executa o script de deploy sobre o diretório local que contém o `.env`, os backups e os logs.

**Importante:** o runner precisa estar em execução e conectado ao GitHub para receber os jobs. Atualmente, ele é iniciado manualmente por meio de `./run.sh`.

## Deploy e rollback automático

O processo de deploy é implementado em:

```text
scripts/deploy.sh
```
O script recebe como argumento a imagem Docker que deverá ser implantada.
Exemplo:
```bash
./scripts/deploy.sh ghcr.io/elenndev/lab-backend:sha-9791f2a
```

### Etapas do deploy

1. Identifica a imagem atualmente utilizada pelo container `lab-backend`.
2. Armazena essa imagem como referência para um possível rollback.
3. Define a nova imagem por meio da variável `BACKEND_IMAGE`.
4. Executa `docker compose pull backend`.
5. Recria o container do backend utilizando a nova imagem.
6. Aguarda o resultado do health check.
7. Se o container estiver saudável, registra o sucesso.
8. Se o health check falhar, inicia o rollback.

### Health check
O script monitora o estado de saúde do container por meio do Docker. Se o container apresentar estado `unhealthy`, `exited` ou `dead`, o deploy é considerado malsucedido.

O health check é importante porque o simples fato de um container iniciar não significa que a aplicação esteja funcionando corretamente. Uma aplicação pode iniciar o processo Node.js, mas apresentar erros ao atender requisições HTTP.

### Rollback
Quando uma nova versão falha, o script:

1. Recupera a imagem utilizada anteriormente.
2. Executa o pull dessa imagem.
3. Recria o container utilizando a versão anterior.
4. Aguarda novamente o health check.
5. Registra o resultado do rollback.

Caso a restauração seja bem-sucedida, a aplicação volta a executar a versão anterior.

O rollback não apaga a imagem defeituosa do GHCR. Ele apenas restaura a versão anterior no ambiente de execução.

### Exemplo de falha recuperada
O mecanismo foi testado intencionalmente com uma versão do backend que faz o endpoint `/health` retornar HTTP 500.

O container consegue iniciar, mas falha no health check.
Durante esse teste, o log apresentou:

```text
ERROR: New deployment failed.

2026-11-01 11:56:45 | FAILED |
NEW=ghcr.io/elenndev/lab-backend:sha-9791f2a
REASON=health_check_failed

Initiating rollback

Restoring image:
ghcr.io/elenndev/lab-backend:sha-8b1bd11

Image ghcr.io/elenndev/lab-backend:sha-8b1bd11 Pulled

Container lab-backend Recreate
Container lab-backend Recreated
Container lab-backend Starting
Container lab-backend Started

Waiting for health check... (1/30)
Waiting for health check... (2/30)
Waiting for health check... (3/30)

2026-11-01 11:57:02 | ROLLBACK |
RESTORED=ghcr.io/elenndev/lab-backend:sha-8b1bd11
STATUS=SUCCESS

Rollback completed successfully!

Deployment failed, but previous version was restored.
```

O resultado confirma que:

- A nova imagem foi publicada.
- O deploy foi iniciado automaticamente.
- O health check identificou a falha.
- O script executou o rollback.
- A imagem anterior foi restaurada.
- O health check da versão anterior passou.

**Estado final esperado do laboratório:**

O projeto é mantido intencionalmente nesse estado para demonstrar o funcionamento do mecanismo de recuperação.

## Backups do PostgreSQL

O projeto possui um serviço dedicado à execução periódica de backups do banco de dados.

O script responsável é:
```text
scripts/backup.sh
```

Os arquivos são armazenados no diretório local:
```text
backups/
```

O script utiliza um arquivo temporário durante a geração do backup e valida se ele não está vazio antes de movê-lo para o nome definitivo.
Essa abordagem evita que um backup incompleto seja confundido com um arquivo válido.
O serviço executa o backup periodicamente, utilizando `BACKUP_INTERVAL_SECONDS` para definir o intervalo. O valor padrão é de 86400 segundos (24 horas).

### Limpeza automática
O script:
```text
scripts/cleanup-backups.sh
```

é responsável por remover backups antigos.
A política de retenção utiliza `RETENTION_DAYS` para definir a quantidade de dias que os arquivos devem ser mantidos.

A limpeza considera arquivos com o padrão:

```text
lab_db-*.sql
```

### Restauração
Para restaurar um backup manualmente, é possível utilizar o `psql` dentro do container PostgreSQL:

```bash
docker compose exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  < backups/NOME_DO_BACKUP.sql
```

## Como executar o projeto
### Pré-requisitos

- Debian ou outra distribuição Linux.
- Git.
- Docker Engine.
- Docker Compose Plugin.
- Acesso ao GitHub.
- Acesso ao GHCR.

### Configuração
Clone o repositório:

```bash
git clone https://github.com/elenndev/lab-infra.git
cd lab-infra
```

Crie o arquivo de ambiente e atualize os valores:
```bash
cp .env.example .env
```

Depois, inicie os containers:

```bash
docker compose up -d
```

Para acompanhar a inicialização:

```bash
docker compose ps
```

Caso o GHCR exija autenticação para baixar a imagem:

```bash
docker login ghcr.io
```
Utilize um token com permissão de leitura dos pacotes.

## Comandos úteis para inspeção
Os comandos abaixo permitem verificar o estado atual do laboratório sem precisar acessar o GitHub Actions a cada consulta.

### Estado dos containers
Listar os serviços:
```bash
docker compose ps
```

Listar todos os containers, inclusive os parados:
```bash
docker ps -a
```

Verificar especificamente o estado de saúde do backend:
```bash
docker inspect lab-backend \
  --format '{{.State.Status}} | {{.State.Health.Status}}'
```

### Verificar a imagem em execução
```bash
docker inspect lab-backend \
  --format '{{.Config.Image}}'
```

Esse comando permite verificar se o rollback restaurou a imagem anterior.

### Testar a API
Testar o endpoint de health check através do Nginx:

```bash
curl http://localhost:8080/api/health
```

Resposta esperada:
```json
{"status":"ok"}
```

Testar o endpoint principal:

```bash
curl http://localhost:8080/api/
```

Testar o frontend:

```bash
curl http://localhost:8080/
```

### Logs
Acompanhar os logs do backend:
```bash
docker compose logs -f backend
```

Acompanhar os logs do Nginx:
```bash
docker compose logs -f nginx
```

Acompanhar os logs do PostgreSQL:
```bash
docker compose logs -f postgres
```

Acompanhar os logs do serviço de backup:
```bash
docker compose logs -f backup
```

Acompanhar os logs do serviço de limpeza:
```bash
docker compose logs -f cleanup
```

### Logs de deploy
O script de deploy mantém um registro das operações em:
```text
logs/deploy.log
```

Visualizar o arquivo:
```bash
cat logs/deploy.log
```

Acompanhar novas entradas:
```bash
tail -f logs/deploy.log
```

### Backups
Listar os backups existentes:
```bash
ls -lh backups/
```

### Reiniciar os serviços

Reiniciar todos os serviços:
```bash
docker compose restart
```

Recriar os serviços:
```bash
docker compose up -d
```

Parar os serviços:
```bash
docker compose down
```

## Como testar o rollback
O projeto possui uma versão intencionalmente defeituosa do backend para permitir a demonstração do rollback.

O teste pode ser acompanhado por meio dos seguintes comandos:

### 1. Verificar a versão atual

```bash
docker inspect lab-backend \
  --format '{{.Config.Image}}'
```

A versão saudável esperada atualmente é:

```text
ghcr.io/elenndev/lab-backend:sha-8b1bd11
```

### 2. Verificar a saúde da API

```bash
curl http://localhost:8080/api/health
```

Resultado esperado:

```json
{"status":"ok"}
```

### 3. Acompanhar os logs de deploy

```bash
tail -f logs/deploy.log
```

### 4. Enviar um novo commit para o backend

O pipeline será executado novamente quando houver um push na branch `master`.
Para executar um teste sem alterar os arquivos:

```bash
git commit --allow-empty -m "test: trigger deployment pipeline"
git push origin master
```

O workflow executará novamente o processo de CI, publicará uma imagem e enviará o evento para o repositório de infraestrutura.

Como o código atual contém a falha intencional no health check, o deploy deverá falhar e o script deverá restaurar a versão anterior.

### 6. Confirmar o rollback

Verificar a imagem em execução:

```bash
docker inspect lab-backend \
  --format '{{.Config.Image}}'
```

Verificar a saúde do container:

```bash
docker inspect lab-backend \
  --format '{{.State.Health.Status}}'
```

Testar novamente a API:

```bash
curl http://localhost:8080/api/health
```

O resultado esperado é que a imagem anterior esteja em execução, o container esteja saudável e a API retorne HTTP 200.

