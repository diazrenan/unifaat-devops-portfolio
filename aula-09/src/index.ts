import express, { Request, Response } from 'express';

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(express.json());

// Health check — usado pelo HEALTHCHECK do Dockerfile
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version ?? '1.0.0',
  });
});

// Rota raiz
app.get('/', (_req: Request, res: Response) => {
  res.status(200).json({
    service: 'technova-api',
    message: 'TechNova API running',
  });
});

app.listen(PORT, () => {
  console.info(`[server] TechNova API listening on port ${PORT}`);
});

export default app;
