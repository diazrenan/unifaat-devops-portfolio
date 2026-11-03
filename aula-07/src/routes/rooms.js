const { Router } = require('express');
const { createRoom, listRooms } = require('../controllers/roomsController');

const router = Router();

router.post('/', createRoom);   // Cadastrar sala
router.get('/', listRooms);     // Ver salas disponíveis

module.exports = router;
