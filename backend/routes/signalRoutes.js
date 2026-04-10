const express = require('express');
const router = express.Router();
const { createSignal, getLatestSignal } = require('../controllers/signalController');

router.post('/', createSignal);
router.get('/latest', getLatestSignal);

module.exports = router;