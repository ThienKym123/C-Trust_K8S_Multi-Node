const express = require('express');
const cors = require('cors');
const passport = require('passport');
const mongoose = require('mongoose');
const config = require('./services/utils/config');

const app = express();
const PORT = process.env.PORT || 3000;

const path = require('path');
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Enable if you're behind a reverse proxy (Heroku, Bluemix, AWS ELB, Nginx, etc)
// see https://expressjs.com/en/guide/behind-proxies.html
app.set('trust proxy', 1);

// Middleware CORS with options
app.use(cors({
  origin: '*', // Be more specific in production
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Middleware log mỗi yêu cầu
app.use((req, res, next) => {
  console.log(`📥 ${req.method} ${req.url}`);
  console.log(`Headers: ${JSON.stringify(req.headers)}`);
  next();
});

// Middleware phân tích JSON with error handling
app.use(express.json({
  limit: '10mb',
  verify: (req, res, buf) => {
    try {
      JSON.parse(buf);
    } catch(e) {
      res.status(400).json({ error: 'Invalid JSON' });
      throw new Error('Invalid JSON');
    }
  }
}));

// Middleware for URL-encoded bodies (needed for forms)
app.use(express.urlencoded({ extended: true }));

// Kiểm tra body JSON sau khi parse
app.use((req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  if (
    req.method === 'POST' &&
    !contentType.includes('multipart/form-data') &&
    (!req.body || Object.keys(req.body).length === 0)
  ) {
    console.warn('⚠️ POST request missing body');
    return res.status(400).json({ error: 'Body JSON không hợp lệ hoặc thiếu' });
  }
  console.log(`Parsed body: ${JSON.stringify(req.body)}`);
  next();
});


// Initialize Passport
app.use(passport.initialize());
require('./services/Passport')(passport);

// Health check endpoint with detailed status
app.get('/health', (req, res) => {
  try {
    // Add basic checks here
    const status = {
      server: 'running',
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    };
    res.status(200).json(status);
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(503).json({
      status: 'error',
      message: 'Service health check failed',
      error: error.message
    });
  }
});

// Default root endpoint
app.get('/', (req, res) => {
  res.json({
    message: '🌐 Backend API for Hyperledger Fabric Test Network',
    version: '1.0.0',
    status: 'running'
  });
});

// Load routes
console.log('Loading routes...');

// Load main application routes first
try {
  require('./routes/routes')(app, passport);
  console.log('✅ Main routes loaded successfully');
} catch (error) {
  console.error('❌ Failed to load main routes:', error);
  process.exit(1); // Exit if critical routes fail to load
}

// Load guest routes
try {
  const guestRoutes = require('./routes/guest');
  app.use('/guest', guestRoutes);
  console.log('✅ Guest routes loaded successfully');
} catch (error) {
  console.error('❌ Failed to load guest routes:', error);
  // Don't exit for guest routes failure
}

// 404 handler
app.use((req, res, next) => {
  console.log(`404 Not Found: ${req.method} ${req.url}`);
  res.status(404).json({ 
    error: 'Route không tồn tại',
    path: req.path,
    method: req.method
  });
});

// Xử lý lỗi server
app.use((err, req, res, next) => {
  console.error(`❌ Lỗi server: ${err.stack}`);
  res.status(500).json({ 
    error: 'Lỗi server nội bộ',
    message: err.message,
    path: req.path
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.info('SIGTERM signal received.');
  console.log('Closing HTTP server.');
  server.close(() => {
    console.log('HTTP server closed.');
    process.exit(0);
  });
});

// Start server with error handling
const server = app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📝 Routes loaded and ready`);
}).on('error', (error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});

mongoose.connect(config.mongo_address, {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => {
  console.log('✅ Connected to MongoDB');
}).catch((err) => {
  console.error('❌ MongoDB connection error:', err);
  process.exit(1);
});