import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import dotenv from 'dotenv';

import { errorHandler, notFound } from './middleware/errorMiddleware';
import { logger } from './utils/logger';
import { initializeFirebase } from './config/firebase';
import { initializeRedis } from './config/redis';
import authRoutes from './routes/authRoutes';
import challengeRoutes from './routes/challengeRoutes';
import sessionRoutes from './routes/sessionRoutes';
import attendanceRoutes from './routes/attendanceRoutes';
import analyticsRoutes from './routes/analyticsRoutes';
import { setupWebSocket } from './websocket/socketHandler';

// Load environment variables
dotenv.config();

const app = express();
const server = createServer(app);
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env.CLIENT_URL || "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 5000;

async function startServer() {
  try {
    // Initialize Firebase Admin
    await initializeFirebase();
    logger.info('Firebase Admin initialized');

    // Initialize Redis
    await initializeRedis();
    logger.info('Redis initialized');

    // Middleware
    app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
        },
      },
    }));

    app.use(cors({
      origin: process.env.CLIENT_URL || "http://localhost:3000",
      credentials: true
    }));

    app.use(compression());
    app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
    app.use(express.json({ limit: '10mb' }));
    app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // Rate limiting
    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 100, // Limit each IP to 100 requests per windowMs
      message: 'Too many requests from this IP, please try again later.',
      standardHeaders: true,
      legacyHeaders: false,
    });
    app.use(limiter);

    // Challenge endpoint with stricter rate limiting
    const challengeLimiter = rateLimit({
      windowMs: 1 * 60 * 1000, // 1 minute
      max: 10, // 10 challenge requests per minute
      message: 'Too many challenge requests, please try again later.',
    });

    // Health check
    app.get('/health', (req, res) => {
      res.status(200).json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version || '1.0.0'
      });
    });

    // API Routes
    app.use('/api/auth', authRoutes);
    app.use('/api/challenges', challengeLimiter, challengeRoutes);
    app.use('/api/sessions', sessionRoutes);
    app.use('/api/attendance', attendanceRoutes);
    app.use('/api/analytics', analyticsRoutes);

    // WebSocket setup
    setupWebSocket(io);

    // Error handling middleware (must be last)
    app.use(notFound);
    app.use(errorHandler);

    // Start server
    server.listen(PORT, () => {
      logger.info(`🚀 Server running on port ${PORT}`);
      logger.info(`📱 Environment: ${process.env.NODE_ENV || 'development'}`);
      logger.info(`🔒 Security features enabled`);
      logger.info(`📊 Analytics tracking enabled`);
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      logger.info('SIGTERM received, shutting down gracefully');
      server.close(() => {
        logger.info('Server closed');
        process.exit(0);
      });
    });

    process.on('SIGINT', () => {
      logger.info('SIGINT received, shutting down gracefully');
      server.close(() => {
        logger.info('Server closed');
        process.exit(0);
      });
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Handle uncaught exceptions and unhandled rejections
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

startServer();