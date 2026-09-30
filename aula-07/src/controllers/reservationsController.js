const { rooms, reservations } = require('../data/store');
const { v4: uuidv4 } = require('uuid');

// ---------- helpers ----------

/**
 * Verifica se dois intervalos de tempo se sobrepõem.
 * Usa lógica de intervalo semi-aberto: [start, end)
 * Uma reserva que termina exatamente quando outra começa NÃO é conflito.
 */
function hasOverlap(startA, endA, startB, endB) {
  return startA < endB && endA > startB;
}

function parseDate(value, fieldName) {
  if (!value || typeof value !== 'string' || value.trim() === '') {
    return { error: `O campo "${fieldName}" é obrigatório.` };
  }
  const date = new Date(value);
  if (isNaN(date.getTime())) {
    return { error: `O campo "${fieldName}" deve ser uma data/hora válida no formato ISO 8601 (ex: "2026-10-01T14:00:00").` };
  }
  return { date };
}

// ---------- controllers ----------

/**
 * POST /reservations
 * Cria uma nova reserva para uma sala em um horário específico.
 */
function createReservation(req, res) {
  const { roomId, employeeId, startTime, endTime } = req.body;

  // Validações de entrada
  if (!roomId || typeof roomId !== 'string' || roomId.trim() === '') {
    return res.status(400).json({ error: 'O campo "roomId" é obrigatório.' });
  }
  if (!employeeId || typeof employeeId !== 'string' || employeeId.trim() === '') {
    return res.status(400).json({ error: 'O campo "employeeId" é obrigatório.' });
  }

  const parsedStart = parseDate(startTime, 'startTime');
  if (parsedStart.error) return res.status(400).json({ error: parsedStart.error });

  const parsedEnd = parseDate(endTime, 'endTime');
  if (parsedEnd.error) return res.status(400).json({ error: parsedEnd.error });

  const start = parsedStart.date;
  const end = parsedEnd.date;

  if (end <= start) {
    return res.status(400).json({ error: '"endTime" deve ser posterior a "startTime".' });
  }

  if (start < new Date()) {
    return res.status(400).json({ error: 'Não é possível criar reservas para horários no passado.' });
  }

  // Verifica se a sala existe
  const room = rooms.find(r => r.id === roomId.trim());
  if (!room) {
    return res.status(404).json({ error: `Sala com id "${roomId.trim()}" não encontrada.` });
  }

  // Bloqueio de concorrência (Double Booking)
  const conflict = reservations.find(rv => {
    if (rv.roomId !== room.id) return false;
    return hasOverlap(start, end, new Date(rv.startTime), new Date(rv.endTime));
  });

  if (conflict) {
    return res.status(409).json({
      error: 'Conflito de horário: a sala já está reservada nesse período.',
      conflict: {
        reservationId: conflict.id,
        employeeId: conflict.employeeId,
        startTime: conflict.startTime,
        endTime: conflict.endTime,
      },
    });
  }

  const reservation = {
    id: uuidv4(),
    roomId: room.id,
    roomName: room.name,
    employeeId: employeeId.trim(),
    startTime: start.toISOString(),
    endTime: end.toISOString(),
    createdAt: new Date().toISOString(),
  };

  reservations.push(reservation);
  return res.status(201).json(reservation);
}

/**
 * DELETE /reservations/:id
 * Cancela uma reserva existente.
 */
function cancelReservation(req, res) {
  const { id } = req.params;

  const index = reservations.findIndex(rv => rv.id === id);
  if (index === -1) {
    return res.status(404).json({ error: `Reserva com id "${id}" não encontrada.` });
  }

  const [removed] = reservations.splice(index, 1);
  return res.status(200).json({ message: 'Reserva cancelada com sucesso.', reservation: removed });
}

/**
 * GET /reservations/employee/:employeeId
 * Lista todas as reservas (passadas e futuras) de um funcionário específico.
 */
function listByEmployee(req, res) {
  const { employeeId } = req.params;

  if (!employeeId || employeeId.trim() === '') {
    return res.status(400).json({ error: 'O parâmetro "employeeId" é obrigatório.' });
  }

  const employeeReservations = reservations
    .filter(rv => rv.employeeId === employeeId.trim())
    .sort((a, b) => new Date(a.startTime) - new Date(b.startTime));

  return res.status(200).json({
    employeeId: employeeId.trim(),
    total: employeeReservations.length,
    reservations: employeeReservations,
  });
}

module.exports = { createReservation, cancelReservation, listByEmployee };
