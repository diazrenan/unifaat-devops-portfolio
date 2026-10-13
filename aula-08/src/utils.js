'use strict';

/**
 * Retorna uma saudação personalizada.
 * @param {string} name - Nome a ser saudado
 * @returns {string}
 */
const greet = (name) => {
  return 'Hello, ' + name + '!';
};

/**
 * Soma dois números.
 * @param {number} a
 * @param {number} b
 * @returns {number}
 */
const add = (a, b) => {
  return a + b;
};

/**
 * Verifica se um número é par.
 * @param {number} n
 * @returns {boolean}
 */
const isEven = (n) => {
  return n % 2 === 0;
};

module.exports = { greet, add, isEven };
