import express from 'express';

const app = express();

app.use(express.json());

// -----------------------------------------------------------------------
// Health check — usado pelo pipeline para validar o deploy
// -----------------------------------------------------------------------
app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'technova-api',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || 'local',
  });
});

// -----------------------------------------------------------------------
// Rotas da API
// -----------------------------------------------------------------------
app.get('/', (_req, res) => {
  res.json({ message: 'TechNova API online' });
});

app.get('/api/products', (_req, res) => {
  const products = [
    { id: 1, name: 'Produto Alpha', price: 99.90 },
    { id: 2, name: 'Produto Beta', price: 149.90 },
    { id: 3, name: 'Produto Gamma', price: 199.90 },
  ];
  res.json({ products, total: products.length });
});

app.get('/api/products/:id', (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id) || id < 1) {
    return res.status(400).json({ error: 'ID inválido' });
  }

  const products = [
    { id: 1, name: 'Produto Alpha', price: 99.90 },
    { id: 2, name: 'Produto Beta', price: 149.90 },
    { id: 3, name: 'Produto Gamma', price: 199.90 },
  ];

  const product = products.find(p => p.id === id);
  if (!product) {
    return res.status(404).json({ error: 'Produto não encontrado' });
  }

  return res.json(product);
});

// -----------------------------------------------------------------------
// 404 handler
// -----------------------------------------------------------------------
app.use((_req, res) => {
  res.status(404).json({ error: 'Rota não encontrada' });
});

export default app;
