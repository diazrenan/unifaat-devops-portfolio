'use strict';

const { greet, add, isEven } = require('../utils');

// ─────────────────────────────────────────────
// Módulo: utils.js
// ─────────────────────────────────────────────

describe('greet()', () => {
  test('retorna saudação com o nome informado', () => {
    expect(greet('Unifaat')).toBe('Hello, Unifaat!');
  });

  test('retorna saudação com nome vazio', () => {
    expect(greet('')).toBe('Hello, !');
  });
});

describe('add()', () => {
  test('soma dois números positivos', () => {
    expect(add(2, 3)).toBe(5);
  });

  test('soma número positivo com negativo', () => {
    expect(add(10, -4)).toBe(6);
  });

  test('soma dois zeros', () => {
    expect(add(0, 0)).toBe(0);
  });
});

describe('isEven()', () => {
  test('retorna true para número par', () => {
    expect(isEven(4)).toBe(true);
  });

  test('retorna false para número ímpar', () => {
    expect(isEven(7)).toBe(false);
  });

  test('retorna true para zero', () => {
    expect(isEven(0)).toBe(true);
  });
});
