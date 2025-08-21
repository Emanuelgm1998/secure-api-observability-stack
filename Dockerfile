FROM node:20-alpine

WORKDIR /app

# Instala dependencias solo con package.json (mejor caché)
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm i --omit=dev

# Copia el código fuente
COPY src ./src

EXPOSE 3000

# Healthcheck contra /live
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/live || exit 1

CMD ["npm", "start"]
