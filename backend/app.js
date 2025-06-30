const express = require('express');
const cors = require('cors');
const assetRoutes = require('./scripts/assetRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware CORS
app.use(cors());

// Middleware log mỗi yêu cầu
app.use((req, res, next) => {
  console.log(`📥 ${req.method} ${req.url}`);
  console.log(`Headers: ${JSON.stringify(req.headers)}`);
  next();
});

// Middleware phân tích JSON
app.use(express.json());

// Kiểm tra body JSON sau khi parse
app.use((req, res, next) => {
  if (req.method === 'POST' && (!req.body || Object.keys(req.body).length === 0)) {
    console.warn('⚠️ POST request missing body');
    return res.status(400).json({ error: 'Body JSON không hợp lệ hoặc thiếu' });
  }
  console.log(`Parsed body: ${JSON.stringify(req.body)}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Default root endpoint
app.get('/', (req, res) => {
  res.send('🌐 Backend API for Hyperledger Fabric Test Network');
});

// Gắn routes xử lý tài sản
app.use('/api', assetRoutes);

// Xử lý lỗi server
app.use((err, req, res, next) => {
  console.error(`❌ Lỗi server: ${err.stack}`);
  res.status(500).json({ error: 'Lỗi server nội bộ' });
});

// Khởi động server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});