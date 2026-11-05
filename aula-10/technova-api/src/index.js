import app from './app.js';

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`[technova-api] Servidor rodando na porta ${PORT}`);
  console.log(`[technova-api] Health check: http://localhost:${PORT}/health`);
});
