/**
 * Armazenamento em memória — substitui o banco de dados.
 * Todos os dados são perdidos ao reiniciar o servidor (comportamento esperado).
 */

const rooms = [];
const reservations = [];

module.exports = { rooms, reservations };
