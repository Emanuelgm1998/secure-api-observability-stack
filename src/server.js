import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';

import logger from './logger.js';
import metrics, { httpRequestTimer } from './metrics.js';
import { errorHandler, notFound } from './errors.js';
import requestId from './middlewares/requestId.js';
import security from './middlewares/security.js';

import healthRouter from './routes/health.js';
import usersRouter from './routes/users.js';

const app = express();
app.use(express.json());
app.use(cookieParser());
app.use(cors());
app.use(helmet());
app.use(security);
app.use(requestId);
app.use(
  morgan('combined', {
    stream: { write: (msg) => logger.http(msg.trim()) }
  })
);
const limiter = rateLimit({
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 60_000,
  max: Number(process.env.RATE_LIMIT_MAX) || 60
});
app.use(limiter);
app.use((req, res, next) => {
  const end = httpRequestTimer.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.route?.path || req.path, code: res.statusCode });
  });
  next();
});
app.use('/health', healthRouter);
app.use('/users', usersRouter);
app.get('/metrics', async (_req, res) => {
  try {
    res.set('Content-Type', metrics.register.contentType);
    res.end(await metrics.register.metrics());
  } catch (err) {
    res.status(500).send(err.message);
  }
});
app.use(notFound);
app.use(errorHandler);
export default app;
