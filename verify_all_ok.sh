#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; NC="\033[0m"
ok(){ echo -e "${GREEN}✅ $*${NC}"; }
warn(){ echo -e "${YELLOW}⚠️  $*${NC}"; }
fail(){ echo -e "${RED}❌ $*${NC}"; exit 1; }

# --- 0) Arrancar servicios si no están arriba
if ! docker ps >/dev/null 2>&1; then
  fail "Docker no está disponible. Abre Docker en Codespaces o usa Dev Containers."
fi

DC="docker compose"
if ! $DC version >/dev/null 2>&1; then
  DC="docker-compose"
  $DC ps >/dev/null 2>&1 || fail "docker compose no disponible."
fi

$DC up -d --build

# --- helper
wait_for_http() {
  local url="$1" name="$2" tries="${3:-40}" sleep_s="${4:-2}"
  for i in $(seq 1 "$tries"); do
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)
    if [[ "$code" =~ ^(2|3)[0-9]{2}$ ]]; then
      ok "$name está respondiendo ($url → $code)"
      return 0
    fi
    echo "Intento $i/$tries → $name aún no responde ($code). Reintentando..."
    sleep "$sleep_s"
  done
  fail "$name no respondió a tiempo ($url)"
}

echo "⏳ Esperando servicios..."
wait_for_http "http://localhost:3000/health"   "API"
wait_for_http "http://localhost:9090/-/ready"  "Prometheus"
wait_for_http "http://localhost:3001/api/health" "Grafana"

# --- 1) API básica
code_health=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
[[ "$code_health" == "200" ]] && ok "GET /health → 200" || fail "GET /health no es 200"

metrics_ct=$(curl -sI http://localhost:3000/metrics | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print tolower($2)}')
if echo "$metrics_ct" | grep -q "text/plain"; then
  ok "/metrics expone content-type text/plain"
else
  warn "Content-Type de /metrics inesperado: $metrics_ct"
fi
if curl -s http://localhost:3000/metrics | grep -q "http_request_duration_seconds"; then
  ok "Métrica http_request_duration_seconds presente"
else
  fail "No se encuentra la métrica http_request_duration_seconds"
fi

# --- 2) Prometheus targets
if curl -s "http://localhost:9090/api/v1/targets" | grep -q "api:3000"; then
  ok "Prometheus ve el target api:3000"
else
  warn "Prometheus aún no muestra api:3000 (puede tardar unos segundos)"
fi

# --- 3) Grafana health
gf_health=$(curl -s http://localhost:3001/api/health || true)
if echo "$gf_health" | grep -Eqi '"database"[[:space:]]*:[[:space:]]*"ok"'; then
  ok "Grafana /api/health → database OK"
else
  warn "Grafana /api/health respuesta inesperada: $gf_health"
fi

# --- 4) Smoke tests /users
code_users=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/users)
[[ "$code_users" == "200" ]] && ok "GET /users → 200" || warn "GET /users no devolvió 200"

code_create=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" \
  -d '{"email":"a@b.com","name":"Emanuel"}' http://localhost:3000/users)
[[ "$code_create" == "201" ]] && ok "POST /users (válido) → 201" || fail "POST /users (válido) no devolvió 201"

code_bad=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" \
  -d '{}' http://localhost:3000/users)
[[ "$code_bad" == "400" ]] && ok "POST /users (inválido) → 400" || fail "POST /users (inválido) no devolvió 400"

# --- 5) Tests y Lint
if npm test --silent; then
  ok "Tests (Jest) pasaron"
else
  fail "Tests fallaron"
fi

if npm run -s lint; then
  ok "Lint OK"
else
  warn "Lint con observaciones (revisa ESLint)"
fi

echo -e "\n${GREEN}🎉 Todo verificado. Abre:${NC}
- API       → http://localhost:3000/health
- Métricas  → http://localhost:3000/metrics
- Prometheus→ http://localhost:9090
- Grafana   → http://localhost:3001
"
