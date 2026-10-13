'use strict';

const http = require('http');
const { greet, add, isEven } = require('./utils');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', uptime: process.uptime() }));
    return;
  }

  if (req.method === 'GET' && req.url === '/') {
    const message = greet('Unifaat');
    const result = add(2, 3);
    const even = isEven(4);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ message, result, even }));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log('Server running on port ' + PORT);
});

module.exports = server;
