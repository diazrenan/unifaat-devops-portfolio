# Aula 01 — Fundamentos de Git e Docker

## O que aprendi

Git

Aprendi que o Git é usado para controlar versões de um projeto.
Aprendi a criar um repositório com git init.
Aprendi a adicionar arquivos para um commit usando git add.
Aprendi a salvar alterações no histórico usando git commit.
Aprendi que o git status mostra o estado atual dos arquivos do projeto.

Docker

Aprendi que o Docker permite executar aplicações dentro de containers.
Aprendi que uma imagem Docker contém tudo o que é necessário para executar uma aplicação.
Aprendi que um container é uma instância em execução de uma imagem.
Aprendi a criar imagens usando um Dockerfile.
Aprendi que o Docker ajuda a manter o mesmo ambiente de desenvolvimento em diferentes computadores.

## Comandos Git praticados

mkdir, git init, git add, git =

## Comandos Docker praticados

docker build -t, docker run -d --name

## Como executar este container

```bash
cd aula-01/app
docker build -t portfolio-aula01:1.0 .
docker run -d -p 3000:3000 portfolio-aula01:1.0
curl http://localhost:3000