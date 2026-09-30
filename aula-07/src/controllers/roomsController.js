const { rooms, reservations } = require('../data/store');
const { v4: uuidv4 } = require('uuid');

/**
 * POST /rooms
 * Cadastra uma nova sala de reunião.
 */
function createRoom(req, res) {
  const { name, capacity } = req.body;

  // Validações de entrada
  if (!name || typeof name !== 'string' || name.trim() === '') {
    return res.status(400).json({ error: 'O campo "name" é obrigatório e deve ser uma string não vazia.' });
  }
  if (capacity === undefined || capacity === null) {
    return res.status(400).json({ error: 'O campo "capacity" é obrigatório.' });
  }
  if (typeof capacity !== 'number' || !Number.isInteger(capacity) || capacity <= 0) {
    return res.status(400).json({ error: 'O campo "capacity" deve ser um número inteiro positivo.' });
  }

  // Evita nomes duplicados
  const duplicate = rooms.find(r => r.name.toLowerCase() === name.trim().toLowerCase());
  if (duplicate) {
    return res.status(409).json({ error: `Já existe uma sala com o nome "${name.trim()}".` });
  }

  const room = {
    id: uuidv4(),
    name: name.trim(),
    capacity,
    createdAt: new Date().toISOString(),
  };

  rooms.push(room);
  return res.status(201).json(room);
}

/**
 * GET /rooms
 * Lista todas as salas com seu status de disponibilidade no momento atual.
 */
function listRooms(req, res) {
  const now = new Date();

  const roomsWithStatus = rooms.map(room => {
    // Verifica se existe alguma reserva ativa agora para esta sala
    const activeReservation = reservations.find(rv => {
      if (rv.roomId !== room.id) return false;
      const start = new Date(rv.startTime);
      const end = new Date(rv.endTime);
      return now >= start && now < end;
    });

    return {
      ...room,
      available: !activeReservation,
      currentReservation: activeReservation
        ? { reservationId: activeReservation.id, employeeId: activeReservation.employeeId, until: activeReservation.endTime }
        : null,
    };
  });

  return res.status(200).json(roomsWithStatus);
}

module.exports = { createRoom, listRooms };
