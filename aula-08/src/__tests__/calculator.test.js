'use strict';

const { subtract, multiply, divide } = require('../calculator');

// ─────────────────────────────────────────────
// Módulo: calculator.js
// ─────────────────────────────────────────────

describe('subtract()', () => {
  test('subtrai dois números positivos', () => {
    expect(subtract(10, 4)).toBe(6);
  });

  test('subtrai resultando em número negativo', () => {
    expect(subtract(3, 8)).toBe(-5);
  });

  test('subtrai zero do número', () => {
    expect(subtract(5, 0)).toBe(5);
  });
});

describe('multiply()', () => {
  test('multiplica dois números positivos', () => {
    expect(multiply(3, 4)).toBe(12);
  });

  test('multiplica por zero retorna zero', () => {
    expect(multiply(99, 0)).toBe(0);
  });

  test('multiplica números negativos', () => {
    expect(multiply(-2, -3)).toBe(6);
  });
});

describe('divide()', () => {
  test('divide dois números positivos', () => {
    expect(divide(10, 2)).toBe(5);
  });

  test('retorna decimal na divisão', () => {
    expect(divide(7, 2)).toBe(3.5);
  });

  test('lança erro ao dividir por zero', () => {
    expect(() => divide(10, 0)).toThrow('Divisão por zero não é permitida');
  });
});
