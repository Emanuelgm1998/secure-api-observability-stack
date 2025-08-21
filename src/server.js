import express from 'express';
import helmet from 'helmet';
import register, { httpRequestTimer } from './metrics.js';

const app = express();
const PORT = process.env.PORT || 3000;

// ===== Config admin para togglear readiness en runtime =====
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'changeme';
let readyDown = process.env.READY_FLAG === 'down'; // estado inicial

app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());

// Middleware global: métrica de duración por request
app.use((req, res, next) => {
  const end = httpRequestTimer.startTimer();
  res.on('finish', () => {
    end({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode
    });
  });
  next();
});

// Liveness
app.get('/live', (_req, res) => res.status(200).send('OK'));

// Readiness (usa flag + aquí podrías chequear DB/Redis, etc.)
async function checkDependencies() {
  if (readyDown) return false;
  // TODO: agrega pings reales si corresponde
  return true;
}
app.get('/ready', async (_req, res) => {
  const ok = await checkDependencies();
  return ok ? res.status(200).send('READY') : res.status(503).send('NOT_READY');
});

// Endpoints admin para cambiar readiness en caliente
app.post('/admin/ready', (req, res) => {
  const token = req.header('X-Admin-Token');
  if (token !== ADMIN_TOKEN) return res.status(401).json({ error: 'unauthorized' });
  const state = (req.query.state || '').toLowerCase();
  if (!['up','down'].includes(state)) return res.status(400).json({ error: 'state must be up|down' });
  readyDown = state === 'down';
  return res.json({ ready: !readyDown });
});

// Métricas Prometheus
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Ruta demo
app.get('/', (_req, res) => res.json({ status: 'up', service: 'secure-api-observability-stack' }));

app.listen(PORT, () => {
  console.log(`[secure-api-observability] Listening on :${PORT}`);
});
