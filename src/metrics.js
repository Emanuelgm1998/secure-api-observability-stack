import client from 'prom-client';

// Métricas por defecto de Node/Process
client.collectDefaultMetrics();

// Histograma para requests HTTP
export const httpRequestTimer = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});

// Registro para /metrics
export default client.register;
