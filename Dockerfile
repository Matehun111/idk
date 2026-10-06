# License server (server.js) for Railway: the default Dockerfile of the repo
FROM node:20-slim
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY server.js ./
CMD ["node", "server.js"]
