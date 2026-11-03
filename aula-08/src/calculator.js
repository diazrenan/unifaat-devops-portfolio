'use strict';

/**
 * Subtrai b de a.
 * @param {number} a
 * @param {number} b
 * @returns {number}
 */
const subtract = (a, b) => {
  return a - b;
};

/**
 * Multiplica dois números.
 * @param {number} a
 * @param {number} b
 * @returns {number}
 */
const multiply = (a, b) => {
  return a * b;
};

/**
 * Divide a por b.
 * @param {number} a
 * @param {number} b
 * @returns {number}
 * @throws {Error} Se b for zero
 */
const divide = (a, b) => {
  if (b === 0) {
    throw new Error('Divisão por zero não é permitida');
  }
  return a / b;
};

module.exports = { subtract, multiply, divide };
