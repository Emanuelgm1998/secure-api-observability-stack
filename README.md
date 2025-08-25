cat > README.md <<'EOF'
# 🔒 Secure API Observability Stack

Una API segura y observable construida con **Node.js + Express**, que implementa **cabeceras de seguridad, health checks y métricas Prometheus** listas para integrarse en **Docker, Docker Compose o Kubernetes**.

---

## ✨ Características

- **Express + Helmet** → cabeceras seguras por defecto.
- **Health checks**:
  - `/live` → indica si el proceso está corriendo.
  - `/ready` → indica si el servicio está listo (puede simular dependencias).
  - `/admin/ready?state=up|down` (requiere `X-Admin-Token`) → permite togglear readiness en runtime.
- **Métricas Prometheus** en `/metrics`:
  - Métricas de sistema (`process_*`).
  - Histograma de requests HTTP con labels `method`, `route`, `status_code`.
- **Dockerfile + docker-compose** → listos con `HEALTHCHECK`.
- **Soporte para Codespaces y Kubernetes**.

---

## 🚀 Uso local (Node.js)

```bash
npm install
npm run dev
Endpoints disponibles:

bash
Copiar
Editar
curl http://localhost:3000/live       # 200 OK
curl http://localhost:3000/ready      # 200 READY
curl http://localhost:3000/metrics    # text/plain con métricas
🐳 Uso con Docker
Construir la imagen:

bash
Copiar
Editar
docker build -t secure-api-observability .
Ejecutar con Docker Compose:

bash
Copiar
Editar
docker compose up --build -d
El servicio quedará en http://localhost:3000.

⚙️ Variables de entorno
Variable	Descripción	Valor por defecto
PORT	Puerto de la API	3000
READY_FLAG	Estado inicial de readiness	up
ADMIN_TOKEN	Token para /admin/ready	changeme

🔧 Ejemplos
Forzar readiness en caliente
bash
Copiar
Editar
curl -X POST "http://localhost:3000/admin/ready?state=down" \
  -H "X-Admin-Token: supersecret"
bash
Copiar
Editar
curl http://localhost:3000/ready   # 503 NOT_READY
📈 Integración con Prometheus
Agrega este scrape job en tu prometheus.yml:

yaml
Copiar
Editar
scrape_configs:
  - job_name: 'secure-api'
    static_configs:
      - targets: ['host.docker.internal:3000']
🛡️ Seguridad
Helmet configurado para evitar ataques comunes.

Endpoints /admin/* requieren X-Admin-Token.

Listo para integrarse en un despliegue Zero-Trust / DevSecOps.

📦 Deploy en Kubernetes (ejemplo)
yaml
Copiar
Editar
livenessProbe:
  httpGet:
    path: /live
    port: 3000
readinessProbe:
  httpGet:
    path: /ready
    port: 3000


👨‍💻 Autor
© 2025 Emanuel — Licencia MIT

🌐 LinkedIn
https://www.linkedin.com/in/emanuel-gonzalez-michea/


