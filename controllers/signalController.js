const { pool } = require('../db');

// Create signal
exports.createSignal = async (req, res) => {
  try {
    const {
      symbol,
      type,
      lot,
      sl,
      tp,
      action,
      position_id,
      deal_id
    } = req.body;

    // Basic validation
    if (!symbol || !type || !lot || !action || !position_id || !deal_id) {
      return res.status(400).json({
        error: 'symbol, type, lot, action, position_id, and deal_id are required'
      });
    }

    const query = `
      INSERT INTO signals (symbol, type, lot, sl, tp, action, position_id, deal_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const values = [
      symbol,
      type,
      lot,
      sl && sl > 0 ? sl : null,
      tp && tp > 0 ? tp : null,
      action,
      position_id,
      deal_id
    ];

    const [result] = await pool.execute(query, values);

    console.log('✅ Signal stored:', result.insertId);

    res.status(201).json({
      message: 'Signal created',
      id: result.insertId
    });

  } catch (error) {
    console.error('❌ Error creating signal:', error);
    res.status(500).json({
      error: 'Internal server error'
    });
  }
};

// Get latest signal
exports.getLatestSignal = async (req, res) => {
  try {
    const query = `
      SELECT * FROM signals
      ORDER BY created_at DESC
      LIMIT 1
    `;

    const [rows] = await pool.execute(query);

    if (rows.length === 0) {
      return res.status(404).json({
        error: 'No signals found'
      });
    }

    res.json(rows[0]);

  } catch (error) {
    console.error('❌ Error fetching signal:', error);
    res.status(500).json({
      error: 'Internal server error'
    });
  }
};