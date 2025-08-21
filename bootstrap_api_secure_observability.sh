set -euo pipefail

# 1) Estructura
mkdir -p src/middlewares src/routes tests prometheus grafana/provisioning/datasources grafana/provisioning/dashboards .github/workflows

# 2) Archivos base
cat > .gitignore <<'EOF'
node_modules
coverage
.env
.DS_Store
EOF

cat > .env.example <<'EOF'
PORT=3000
NODE_ENV=development
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=60
EOF

cat > .prettierrc <<'EOF'
{ "singleQuote": true, "semi": true }
EOF

cat > .eslintrc.json <<'EOF'
{
  "env": {"es2022": true, "node": true, "jest": true},
  "extends": ["eslint:recommended", "plugin:import/recommended", "prettier"],
  "parserOptions": {"ecmaVersion": 2022, "sourceType": "module"},
  "rules": {
    "import/no-unresolved": 0,
    "no-unused-vars": ["warn", {"argsIgnorePattern": "^_"}]
  }
}
EOF

cat > jest.config.js <<'EOF'
export default {
  testEnvironment: 'node',
  verbose: true
};
EOF

cat > Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY src ./src
COPY ./.env.example ./.env
EXPOSE 3000
CMD ["node", "src/index.js"]
EOF

cat > docker-compose.yml <<'EOF'
version: "3.9"
services:
  api:
    build: .
    container_name: api-secure-observability
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    depends_on:
      - prometheus
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 10s
      timeout: 3s
      retries: 3

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - --config.file=/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    depends_on:
      - prometheus
EOF

cat > prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: 'api'
    metrics_path: /metrics
    static_configs:
      - targets: ['api:3000']
EOF

cat > grafana/provisioning/datasources/datasource.yml <<'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

cat > grafana/provisioning/dashboards/dashboard.yml <<'EOF'
apiVersion: 1
providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

cat > grafana/provisioning/dashboards/api-overview.json <<'EOF'
{
  "annotations": {"list": []},
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "panels": [
    {
      "type": "timeseries",
      "title": "HTTP Request Duration (p95)",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))"
        }
      ],
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0}
    },
    {
      "type": "timeseries",
      "title": "Requests per Second",
      "targets": [
        {"expr": "sum(rate(http_request_duration_seconds_count[1m]))"}
      ],
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
    },
    {
      "type": "timeseries",
      "title": "HTTP Codes",
      "targets": [
        {"expr": "sum by (code) (rate(http_request_duration_seconds_count[1m]))"}
      ],
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
    },
    {
      "type": "timeseries",
      "title": "Memory (RSS)",
      "targets": [
        {"expr": "process_resident_memory_bytes"}
      ],
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16}
    },
    {
      "type": "timeseries",
      "title": "CPU Time",
      "targets": [
        {"expr": "process_cpu_seconds_total"}
      ],
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16}
    }
  ],
  "schemaVersion": 39,
  "version": 1,
  "refresh": "10s",
  "title": "API Overview"
}
EOF

cat > .github/workflows/ci.yml <<'EOF'
name: CI
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run lint
      - run: npm test
EOF

# 3) Código de la API
cat > src/index.js <<'EOF'
import app from './server.js';
const port = process.env.PORT || 3000;
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`API listening on port ${port}`);
});
EOF

cat > src/logger.js <<'EOF'
import winston from 'winston';
const logger = winston.createLogger({
  level: 'http',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()]
});
export default logger;
EOF

cat > src/metrics.js <<'EOF'
import client from 'prom-client';
client.collectDefaultMetrics();
export const httpRequestTimer = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.005, 0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5]
});
export default { register: client.register };
EOF

cat > src/errors.js <<'EOF'
export function notFound(req, res, _next) {
  res.status(404).json({ error: 'Not Found', path: req.originalUrl });
}
export function errorHandler(err, _req, res, _next) {
  const status = err.status || 500;
  res.status(status).json({ error: err.message || 'Internal Server Error' });
}
EOF

cat > src/middlewares/requestId.js <<'EOF'
import { v4 as uuid } from 'uuid';
export default function requestId(req, _res, next) {
  req.id = req.headers['x-request-id'] || uuid();
  next();
}
EOF

cat > src/middlewares/security.js <<'EOF'
export default function security(_req, res, next) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '0');
  next();
}
EOF

cat > src/middlewares/validate.js <<'EOF'
import { validationResult } from 'express-validator';
export default function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
}
EOF

cat > src/routes/health.js <<'EOF'
import { Router } from 'express';
const router = Router();
router.get('/', (_req, res) => {
  res.json({ status: 'ok', uptime: process.uptime(), timestamp: Date.now() });
});
export default router;
EOF

cat > src/routes/users.js <<'EOF'
import { Router } from 'express';
import { body } from 'express-validator';
import validate from '../middlewares/validate.js';
const router = Router();
const users = [];
router.get('/', (_req, res) => {
  res.json({ users });
});
router.post(
  '/',
  body('email').isEmail(),
  body('name').isString().isLength({ min: 2 }),
  validate,
  (req, res) => {
    const user = { id: users.length + 1, ...req.body };
    users.push(user);
    res.status(201).json(user);
  }
);
export default router;
EOF

cat > src/server.js <<'EOF'
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
EOF

# 4) Tests
cat > tests/api.test.js <<'EOF'
import request from 'supertest';
import app from '../src/server.js';

describe('API', () => {
  it('GET /health -> 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('POST /users -> 201 with valid payload', async () => {
    const res = await request(app)
      .post('/users')
      .send({ email: 'a@b.com', name: 'Emanuel' });
    expect(res.status).toBe(201);
    expect(res.body.email).toBe('a@b.com');
  });

  it('POST /users -> 400 with invalid payload', async () => {
    const res = await request(app).post('/users').send({});
    expect(res.status).toBe(400);
  });
});
EOF

# 5) package.json (con scripts y deps)
cat > package.json <<'EOF'
{
  "name": "api-secure-observability",
  "version": "1.0.0",
  "main": "src/index.js",
  "type": "module",
  "scripts": {
    "dev": "NODE_ENV=development node src/index.js",
    "start": "node src/index.js",
    "test": "jest --runInBand",
    "lint": "eslint .",
    "format": "prettier --write ."
  },
  "dependencies": {
    "cookie-parser": "^1.4.6",
    "cors": "^2.8.5",
    "express": "^4.19.2",
    "express-rate-limit": "^7.4.0",
    "express-validator": "^7.0.1",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "prom-client": "^15.1.2",
    "winston": "^3.13.0",
    "uuid": "^9.0.1"
  },
  "devDependencies": {
    "eslint": "^9.9.0",
    "eslint-config-prettier": "^9.1.0",
    "eslint-plugin-import": "^2.29.1",
    "jest": "^29.7.0",
    "prettier": "^3.3.3",
    "supertest": "^7.0.0"
  }
}
EOF

# 6) Instalar deps para correr tests/lint localmente
npm install

echo
echo "✅ Proyecto generado. Siguientes pasos:"
echo "1) docker-compose up --build"
echo "2) API:        http://localhost:3000/health"
echo "   METRICAS:   http://localhost:3000/metrics"
echo "   Prometheus: http://localhost:9090"
echo "   Grafana:    http://localhost:3001 (admin/admin)"
echo "3) npm test   # ejecutar tests"
echo "4) npm run lint"
