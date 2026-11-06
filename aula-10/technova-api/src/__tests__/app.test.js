import request from 'supertest';
import app from '../app.js';

describe('GET /health', () => {
  it('deve retornar status 200 com body ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.service).toBe('technova-api');
    expect(res.body.timestamp).toBeDefined();
  });
});

describe('GET /', () => {
  it('deve retornar mensagem de boas vindas', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.body.message).toBe('TechNova API online');
  });
});

describe('GET /api/products', () => {
  it('deve retornar lista de produtos', async () => {
    const res = await request(app).get('/api/products');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.products)).toBe(true);
    expect(res.body.products.length).toBeGreaterThan(0);
    expect(res.body.total).toBe(res.body.products.length);
  });

  it('cada produto deve ter id, name e price', async () => {
    const res = await request(app).get('/api/products');
    res.body.products.forEach(p => {
      expect(p).toHaveProperty('id');
      expect(p).toHaveProperty('name');
      expect(p).toHaveProperty('price');
    });
  });
});

describe('GET /api/products/:id', () => {
  it('deve retornar produto existente', async () => {
    const res = await request(app).get('/api/products/1');
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(1);
  });

  it('deve retornar 404 para produto inexistente', async () => {
    const res = await request(app).get('/api/products/999');
    expect(res.status).toBe(404);
    expect(res.body.error).toBeDefined();
  });

  it('deve retornar 400 para ID inválido', async () => {
    const res = await request(app).get('/api/products/abc');
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });
});

describe('Rota inexistente', () => {
  it('deve retornar 404 para rota desconhecida', async () => {
    const res = await request(app).get('/rota-que-nao-existe');
    expect(res.status).toBe(404);
  });
});
