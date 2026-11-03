const express = require('express');
const roomsRouter = require('./routes/rooms');
const reservationsRouter = require('./routes/reservations');

const app = express();

// Parseia body JSON
app.use(express.json());

// Rota de health check
app.get('/', (req, res) => {
  res.json({ service: 'TechNova Meeting Room API', status: 'running' });
});

// Rotas da aplicação
app.use('/rooms', roomsRouter);
app.use('/reservations', reservationsRouter);

// Handler de rota não encontrada
app.use((req, res) => {
  res.status(404).json({ error: `Rota "${req.method} ${req.originalUrl}" não encontrada.` });
});

// Handler global de erros
app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Erro interno do servidor.' });
});

module.exports = app;
