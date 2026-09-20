#!/bin/bash
set -e

# Atualiza os pacotes do sistema
dnf update -y

# Instala o cliente PostgreSQL (psql)
dnf install -y postgresql15

echo "Cliente PostgreSQL instalado com sucesso."
