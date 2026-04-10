const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'mt_signals',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

const initDatabase = async () => {
  const connection = await pool.getConnection();
  try {
    await connection.query(`
      CREATE TABLE IF NOT EXISTS signals (
        id INT AUTO_INCREMENT PRIMARY KEY,
        symbol VARCHAR(20) NOT NULL,
        type ENUM('BUY', 'SELL') NOT NULL,
        lot DECIMAL(10, 2) NOT NULL,
        sl DECIMAL(10, 5),
        tp DECIMAL(10, 5),
        action VARCHAR(10) NOT NULL,
        position_id BIGINT,
        deal_id BIGINT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Database initialized');
  } finally {
    connection.release();
  }
};

module.exports = { pool, initDatabase };