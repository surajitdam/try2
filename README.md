# MetaTrader Signal API

Node.js Express backend for MetaTrader signal system.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure database in `.env`:
```
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=mt_signals
PORT=3000
```

3. Create the database (if not exists):
```sql
CREATE DATABASE mt_signals;
```

## Run

```bash
npm start
```

## API Endpoints

### POST /signal
Create a new signal.

**Request:**
```json
{
  "symbol": "EURUSD",
  "type": "BUY",
  "lot": 0.1,
  "sl": 1.0900,
  "tp": 1.1000
}
```

### GET /signal/latest
Returns the latest signal.

### GET /health
Returns `{ "status": "OK" }`