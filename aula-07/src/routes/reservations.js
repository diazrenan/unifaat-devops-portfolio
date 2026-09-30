const { Router } = require('express');
const {
  createReservation,
  cancelReservation,
  listByEmployee,
} = require('../controllers/reservationsController');

const router = Router();

router.post('/', createReservation);                          // Fazer reserva
router.delete('/:id', cancelReservation);                     // Cancelar reserva
router.get('/employee/:employeeId', listByEmployee);          // Listar reservas de um funcionário

module.exports = router;
