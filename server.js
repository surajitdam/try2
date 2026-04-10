require('dotenv').config();
const express = require('express');
const signalRoutes = require('./routes/signalRoutes');
const { initDatabase } = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.use('/signal', signalRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

const startServer = async () => {
  try {
    await initDatabase();
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();