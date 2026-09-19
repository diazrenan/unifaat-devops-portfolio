#!/bin/bash

LOG="/var/log/technova-setup.log"

echo "=== Iniciando configuração da TechNova ===" >> "$LOG"

yum update -y >> "$LOG" 2>&1

echo "=== Instalando Node.js 18 ===" >> "$LOG"

curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - >> "$LOG" 2>&1
yum install -y nodejs >> "$LOG" 2>&1

node --version >> "$LOG" 2>&1
npm --version >> "$LOG" 2>&1

echo "=== Criando API TechNova ===" >> "$LOG"

mkdir -p /opt/technova-api
cd /opt/technova-api

cat > package.json <<'EOF'
{
  "name": "technova-api",
  "version": "1.0.0",
  "description": "API simplificada da TechNova",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.21.2"
  }
}
EOF

npm install >> "$LOG" 2>&1

echo "=== Criando endpoints da API ===" >> "$LOG"

cat > server.js <<'EOF'
const express = require("express");

const app = express();
const PORT = 3000;

app.get("/", (req, res) => {
  res.json({
    status: "ok",
    app: "technova-api",
    message: "API no ar!"
  });
});

app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    service: "technova-api"
  });
});

app.get("/orders", (req, res) => {
  res.json([
    {
      id: 1,
      customer: "Cliente 1",
      total: 150.00
    },
    {
      id: 2,
      customer: "Cliente 2",
      total: 250.00
    }
  ]);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`TechNova API rodando na porta ${PORT}`);
});
EOF

echo "=== Iniciando TechNova API ===" >> "$LOG"

nohup npm start >> "$LOG" 2>&1 &

echo "=== Configuração concluída ===" >> "$LOG"