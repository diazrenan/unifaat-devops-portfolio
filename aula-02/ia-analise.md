# Análise do Uso de IA — Aula 02 TF

## Prompt Utilizado

Crie um docker-compose.yml para uma aplicação Node.js 20 com Express que usa PostgreSQL 15 como banco de dados e Redis 7 como cache. A API roda na porta 3000. O PostgreSQL precisa de volume nomeado para persistência. Todos os serviços devem estar na mesma rede bridge customizada. Use variáveis de ambiente com interpolação de arquivo .env. Adicione healthchecks, depends_on com condition, e restart policy unless-stopped.

## Output Original do Kiro

services:

# ─────────────────────────────────────────────

# API Node.js 20 + Express

# ─────────────────────────────────────────────

api:
build:
context: .
dockerfile: Dockerfile

    restart: unless-stopped

    env_file:
      - .env

    environment:
      PORT: ${PORT}
      NODE_ENV: ${NODE_ENV}
      DB_HOST: ${DB_HOST}
      DB_PORT: ${DB_PORT}
      DB_NAME: ${DB_NAME}
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: ${REDIS_HOST}
      REDIS_PORT: ${REDIS_PORT}

    ports:
      - "${PORT}:${PORT}"

    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"
        ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

    networks:
      - app-network

# ─────────────────────────────────────────────

# PostgreSQL 15

# ─────────────────────────────────────────────

postgres:
image: postgres:15-alpine

    restart: unless-stopped

    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

    volumes:
      - postgres_data:/var/lib/postgresql/data

    healthcheck:
      test:
        [
          "CMD-SHELL",
          "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
        ]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

    networks:
      - app-network

# ─────────────────────────────────────────────

# Redis 7

# ─────────────────────────────────────────────

redis:
image: redis:7-alpine

    restart: unless-stopped

    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

    networks:
      - app-network

# ─────────────────────────────────────────────

# Volume nomeado do PostgreSQL

# ─────────────────────────────────────────────

volumes:
postgres_data:
driver: local

# ─────────────────────────────────────────────

# Rede bridge customizada

# ─────────────────────────────────────────────

networks:
app-network:
driver: bridge

## Alterações que Fiz Manualmente

## Alterações que Fiz Manualmente

| O que mudei                                                                    | Por quê                                                                                                                                                                    |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ajustei o `docker-compose.yml` para utilizar o `Dockerfile` local da aplicação | O professor exigiu que o serviço `api` fosse construído a partir do Dockerfile local.                                                                                      |
| Configurei o PostgreSQL com a imagem `postgres:15-alpine`                      | O enunciado determina especificamente essa imagem e versão.                                                                                                                |
| Configurei o Redis com a imagem `redis:7-alpine`                               | O enunciado determina especificamente essa imagem e versão.                                                                                                                |
| Configurei uma rede bridge customizada chamada `app-network`                   | O professor exigiu que API, PostgreSQL e Redis estivessem conectados pela mesma rede customizada.                                                                          |
| Configurei o volume nomeado `postgres_data` para o PostgreSQL                  | O volume é necessário para garantir a persistência dos dados do banco.                                                                                                     |
| Adicionei healthcheck no PostgreSQL usando `pg_isready`                        | Permite verificar automaticamente quando o banco está pronto para receber conexões.                                                                                        |
| Adicionei healthcheck no Redis usando `redis-cli ping`                         | Permite verificar automaticamente se o Redis está funcionando.                                                                                                             |
| Configurei `depends_on` com `condition: service_healthy`                       | A API deve aguardar PostgreSQL e Redis estarem saudáveis antes de iniciar.                                                                                                 |
| Configurei `restart: unless-stopped` nos três serviços                         | Permite que os containers sejam reiniciados automaticamente, exceto quando forem parados manualmente.                                                                      |
| Configurei as variáveis de ambiente usando o arquivo `.env`                    | Evita deixar configurações diretamente no `docker-compose.yml` e segue o requisito do professor.                                                                           |
| Criei o `.env.example`                                                         | Permite versionar um modelo das variáveis necessárias sem expor a senha real utilizada no `.env`.                                                                          |
| Criei o `.gitignore` dentro da pasta `aula-02`                                 | Garante que o `.env`, `node_modules` e arquivos de log não sejam enviados ao Git.                                                                                          |
| Substituí o `app.js` pelo código fornecido pelo professor                      | O código precisava seguir o modelo definido na atividade e utilizar as variáveis de ambiente esperadas.                                                                    |
| Substituí o `package.json` pelo modelo fornecido pelo professor                | Mantém a aplicação de acordo com a estrutura e dependência solicitadas na atividade.                                                                                       |
| Substituí o `Dockerfile` pelo modelo fornecido pelo professor                  | Garante que a imagem da API seja construída conforme as instruções da atividade.                                                                                           |
| Substituí o `.dockerignore` pelo modelo fornecido pelo professor               | Evita enviar arquivos desnecessários e o `.env` para o contexto de build do Docker.                                                                                        |
| Removi o `server.js` criado na geração inicial                                 | O arquivo não fazia parte dos entregáveis solicitados e utilizava dependências adicionais de PostgreSQL e Redis que não eram necessárias para o código final da atividade. |
| Mantive o `.env` somente localmente e não o versionei                          | O arquivo contém a senha utilizada pelo PostgreSQL e não deve ser enviado ao GitHub.                                                                                       |

## O que o Kiro Acertou

- Criou uma estrutura inicial para um ambiente com múltiplos containers.
- Identificou corretamente a necessidade de utilizar Node.js com Express para a API.
- Utilizou PostgreSQL como banco de dados.
- Utilizou Redis como serviço de cache.
- Utilizou Docker Compose para orquestrar os serviços.
- Criou configurações iniciais de comunicação entre os serviços.
- Ajudou a acelerar a criação da estrutura inicial do ambiente.
- Serviu como ponto de partida para a configuração final do Docker Compose.

## O que o Kiro Errou ou Omitiu

- A configuração inicial precisou ser revisada para ficar exatamente de acordo com os requisitos definidos pelo professor.
- Alguns arquivos gerados inicialmente pelo Kiro não correspondiam diretamente aos arquivos solicitados nos entregáveis da atividade.
- O `server.js` gerado inicialmente possuía uma implementação mais completa, utilizando as bibliotecas `pg` e `redis`, mas essa implementação não era necessária para o código final solicitado pelo professor.
- Foi necessário substituir arquivos como `app.js`, `package.json`, `Dockerfile` e `.dockerignore` pelos modelos definidos na atividade.
- Foi necessário revisar a configuração do Docker Compose para garantir todos os requisitos obrigatórios, principalmente healthchecks, `depends_on` com condições de saúde, variáveis de ambiente, volume nomeado, rede customizada e política de restart.
- Foi necessário organizar os arquivos na estrutura correta dentro da pasta `aula-02`.
- A configuração final precisou ser validada manualmente utilizando o Docker Compose e testes dos serviços.

## Minha Avaliação

- **Tempo economizado usando IA:** aproximadamente 30 minutos
- **Tempo gasto validando/corrigindo:** aproximadamente 60 minutos
- **Nota para o output da IA (1-10):** 7
- **Usaria novamente para este tipo de tarefa?** Sim. A IA foi útil para gerar uma estrutura inicial rapidamente, mas foi necessário entender, revisar e testar as configurações antes de considerar o ambiente concluído.
